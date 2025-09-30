// dashboard_screen.dart
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../services/api_services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Upload state (supports web bytes + desktop File)
  File? _selectedFile; // desktop
  Uint8List? _selectedBytes; // web
  String? _selectedFilename;
  String _uploadResult = '';

  // Key JSON state
  final TextEditingController _keyJsonController = TextEditingController(
      text: '{"ephemeralPub":"...","nonce":"...","cipher":"...","mac":"..."}');
  String _uploadKeyResult = '';

  // Grant / revoke / emergency state
  final _granteeController = TextEditingController();
  final _fileCidController = TextEditingController();
  final _encKeyCidController = TextEditingController();
  String _grantResult = '';
  String _revokeResult = '';
  String _emergencyResult = '';

  // Lists
  List<dynamic> _grants = [];
  List<dynamic> _audit = [];

  @override
  void initState() {
    super.initState();
    _refreshLists();
  }

  Future<void> _refreshLists() async {
    try {
      final grants = await ApiService.getGrants();
      final auditMap = await ApiService.getAudit(); // returns Map { audit: [...], grants: [...] }
      setState(() {
        _grants = grants;
        // auditMap['audit'] is the list of audit events
        _audit = (auditMap['audit'] is List) ? List<dynamic>.from(auditMap['audit']) : [];
      });
    } catch (e) {
      // show a simple message in uploadResult area or console
      setState(() => _uploadResult = 'Refresh failed: $e');
    }
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;

    final f = res.files.single;
    setState(() {
      _selectedFilename = f.name;
      // on web bytes are available; on desktop path will be available
      if (kIsWeb) {
        _selectedBytes = f.bytes;
        _selectedFile = null;
      } else {
        // desktop / mobile: prefer File path
        if (f.path != null) {
          _selectedFile = File(f.path!);
          _selectedBytes = null;
        } else {
          // Fallback to bytes
          _selectedBytes = f.bytes;
          _selectedFile = null;
        }
      }
    });
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null && _selectedBytes == null) {
      setState(() => _uploadResult = 'No file selected');
      return;
    }
    setState(() => _uploadResult = 'Uploading...');
    try {
      Map<String, dynamic> resp;
      if (_selectedBytes != null && _selectedFilename != null) {
        // web path: upload from bytes
        resp = await ApiService.uploadFileFromBytes(_selectedBytes!, filename: _selectedFilename!);
      } else if (_selectedFile != null) {
        // desktop: upload File
        resp = await ApiService.uploadFile(_selectedFile!);
      } else {
        throw 'No valid file data';
      }

      setState(() => _uploadResult = 'OK: ${resp.toString()}');
      await _refreshLists();
    } catch (e) {
      setState(() => _uploadResult = 'Error: $e');
    }
  }

  Future<void> _uploadKey() async {
    setState(() => _uploadKeyResult = 'Uploading key...');
    try {
      final parsed = jsonTryParse(_keyJsonController.text);
      final r = await ApiService.uploadKey(parsed);
      setState(() => _uploadKeyResult = 'OK: ${r.toString()}');
      await _refreshLists();
    } catch (e) {
      setState(() => _uploadKeyResult = 'Error: $e');
    }
  }

  Map<String, dynamic> jsonTryParse(String s) {
    try {
      return (s.trim().isEmpty) ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(s));
    } catch (e) {
      throw 'Invalid JSON: $e';
    }
  }

  Future<void> _grantAccess() async {
    final grantee = _granteeController.text.trim();
    final fileCid = _fileCidController.text.trim();
    final encKey = _encKeyCidController.text.trim();
    if (grantee.isEmpty || fileCid.isEmpty || encKey.isEmpty) {
      setState(() => _grantResult = 'fill grantee/fileCid/encKeyCid');
      return;
    }
    setState(() => _grantResult = 'Sending...');
    try {
      final r = await ApiService.grantAccess(
        grantee: grantee,
        fileCid: fileCid,
        encKeyCid: encKey,
      );
      setState(() => _grantResult = 'OK: ${r.toString()}');
      await _refreshLists();
    } catch (e) {
      setState(() => _grantResult = 'Error: $e');
    }
  }

  Future<void> _revokeAccess() async {
    final grantee = _granteeController.text.trim();
    final fileCid = _fileCidController.text.trim();
    if (grantee.isEmpty || fileCid.isEmpty) {
      setState(() => _revokeResult = 'fill grantee & fileCid');
      return;
    }
    setState(() => _revokeResult = 'Sending...');
    try {
      final r = await ApiService.revokeAccess(grantee: grantee, fileCid: fileCid);
      setState(() => _revokeResult = 'OK: ${r.toString()}');
      await _refreshLists();
    } catch (e) {
      setState(() => _revokeResult = 'Error: $e');
    }
  }

  Future<void> _emergencyAccess() async {
    final fileCid = _fileCidController.text.trim();
    if (fileCid.isEmpty) {
      setState(() => _emergencyResult = 'fill fileCid');
      return;
    }
    setState(() => _emergencyResult = 'Sending emergency request...');
    try {
      final r = await ApiService.emergencyAccess(fileCid: fileCid);
      setState(() => _emergencyResult = 'OK: ${r.toString()}');
      await _refreshLists();
    } catch (e) {
      setState(() => _emergencyResult = 'Error: $e');
    }
  }

  @override
  void dispose() {
    _granteeController.dispose();
    _fileCidController.dispose();
    _encKeyCidController.dispose();
    _keyJsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Dashboard — MedVault')),
      body: RefreshIndicator(
        onRefresh: () async => await _refreshLists(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionTitle('1) Upload File'),
              Row(children: [
                ElevatedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.attach_file), label: const Text('Pick')),
                const SizedBox(width: 12),
                ElevatedButton.icon(onPressed: _uploadFile, icon: const Icon(Icons.cloud_upload), label: const Text('Upload')),
                const SizedBox(width: 12),
                if (_selectedFilename != null) Expanded(child: Text(_selectedFilename!))
              ]),
              const SizedBox(height: 8),
              Text(_uploadResult),

              const Divider(),

              sectionTitle('2) Upload Encrypted Key (JSON)'),
              TextField(
                maxLines: 4,
                controller: _keyJsonController,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '{"ephemeralPub": "..."}'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                ElevatedButton(onPressed: _uploadKey, child: const Text('Upload Key JSON')),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: () { setState(() { _keyJsonController.text = '{"ephemeralPub":"abcd","nonce":"xyz","cipher":"deadbeef","mac":"1234"}'; }); }, child: const Text('Fill demo')),
              ]),
              const SizedBox(height: 6),
              Text(_uploadKeyResult),

              const Divider(),

              sectionTitle('3) Grant / Revoke / Emergency'),
              TextField(controller: _granteeController, decoration: const InputDecoration(labelText: 'Grantee address (0x...)')),
              TextField(controller: _fileCidController, decoration: const InputDecoration(labelText: 'File CID (bafy...)')),
              TextField(controller: _encKeyCidController, decoration: const InputDecoration(labelText: 'Encrypted Key CID (bafy...)')),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ElevatedButton(onPressed: _grantAccess, child: const Text('Grant Access')),
                ElevatedButton(onPressed: _revokeAccess, child: const Text('Revoke Access')),
                ElevatedButton(onPressed: _emergencyAccess, child: const Text('Emergency Access')),
                ElevatedButton(onPressed: _refreshLists, child: const Text('Refresh Lists')),
              ]),
              const SizedBox(height: 8),
              Text('Grant result: $_grantResult'),
              Text('Revoke result: $_revokeResult'),
              Text('Emergency result: $_emergencyResult'),

              const Divider(),

              sectionTitle('4) Grants (local DB)'),
              if (_grants.isEmpty) const Text('No grants yet') else Column(
                children: _grants.map((g) {
                  final patient = (g is Map) ? g['patient'] ?? '' : '';
                  final grantee = (g is Map) ? g['grantee'] ?? '' : '';
                  final fileCid = (g is Map) ? (g['fileCid'] ?? g['fileCID'] ?? '') : '';
                  final enc = (g is Map) ? (g['encKeyCid'] ?? g['encKey'] ?? '') : '';
                  return Card(
                    child: ListTile(
                      title: Text('file: ${fileCid.toString()}'),
                      subtitle: Text('grantee: $grantee\nencKey: $enc'),
                    ),
                  );
                }).toList(),
              ),

              const Divider(),

              sectionTitle('5) Audit (on-chain + local)'),
              if (_audit.isEmpty) const Text('No audit events yet') else Column(
                children: _audit.map((e) {
                  final ev = (e is Map) ? e : <String,dynamic>{};
                  final contract = ev['contract'] ?? ev['action'] ?? '';
                  final txt = (ev['event'] != null) ? '${ev['event']}' : '${ev['action'] ?? ''}';
                  final meta = ev['args'] ?? ev['fileCid'] ?? '';
                  return Card(
                    child: ListTile(
                      title: Text('$txt'),
                      subtitle: Text('$meta\n${ev['txHash'] ?? ''}'),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
