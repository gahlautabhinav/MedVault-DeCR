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

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  // Upload state
  File? _selectedFile;
  Uint8List? _selectedBytes;
  String? _selectedFilename;
  String _uploadResult = '';
  bool _isUploading = false;

  // Key JSON state
  final TextEditingController _keyJsonController = TextEditingController(
      text: '{"ephemeralPub":"...","nonce":"...","cipher":"...","mac":"..."}');
  String _uploadKeyResult = '';
  bool _isUploadingKey = false;

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
  bool _isRefreshing = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _refreshLists();
  }

  @override
  void dispose() {
    _granteeController.dispose();
    _fileCidController.dispose();
    _encKeyCidController.dispose();
    _keyJsonController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _refreshLists() async {
    setState(() => _isRefreshing = true);
    try {
      final grants = await ApiService.getGrants();
      final auditMap = await ApiService.getAudit();
      setState(() {
        _grants = grants;
        _audit = (auditMap['audit'] is List) ? List<dynamic>.from(auditMap['audit']) : [];
      });
    } catch (e) {
      _showSnackBar('Refresh failed: $e', isError: true);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;

    final f = res.files.single;
    setState(() {
      _selectedFilename = f.name;
      if (kIsWeb) {
        _selectedBytes = f.bytes;
        _selectedFile = null;
      } else {
        if (f.path != null) {
          _selectedFile = File(f.path!);
          _selectedBytes = null;
        } else {
          _selectedBytes = f.bytes;
          _selectedFile = null;
        }
      }
    });
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null && _selectedBytes == null) {
      _showSnackBar('No file selected', isError: true);
      return;
    }
    setState(() {
      _isUploading = true;
      _uploadResult = '';
    });
    try {
      Map<String, dynamic> resp;
      if (_selectedBytes != null && _selectedFilename != null) {
        resp = await ApiService.uploadFileFromBytes(_selectedBytes!, filename: _selectedFilename!);
      } else if (_selectedFile != null) {
        resp = await ApiService.uploadFile(_selectedFile!);
      } else {
        throw 'No valid file data';
      }

      setState(() => _uploadResult = 'Success: ${resp.toString()}');
      _showSnackBar('File uploaded successfully!');
      await _refreshLists();
    } catch (e) {
      setState(() => _uploadResult = 'Error: $e');
      _showSnackBar('Upload failed: $e', isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadKey() async {
    setState(() {
      _isUploadingKey = true;
      _uploadKeyResult = '';
    });
    try {
      final parsed = jsonTryParse(_keyJsonController.text);
      final r = await ApiService.uploadKey(parsed);
      setState(() => _uploadKeyResult = 'Success: ${r.toString()}');
      _showSnackBar('Key uploaded successfully!');
      await _refreshLists();
    } catch (e) {
      setState(() => _uploadKeyResult = 'Error: $e');
      _showSnackBar('Key upload failed: $e', isError: true);
    } finally {
      setState(() => _isUploadingKey = false);
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
      _showSnackBar('Please fill all fields', isError: true);
      return;
    }
    setState(() => _grantResult = 'Processing...');
    try {
      final r = await ApiService.grantAccess(grantee: grantee, fileCid: fileCid, encKeyCid: encKey);
      setState(() => _grantResult = 'Success: ${r.toString()}');
      _showSnackBar('Access granted successfully!');
      await _refreshLists();
    } catch (e) {
      setState(() => _grantResult = 'Error: $e');
      _showSnackBar('Grant failed: $e', isError: true);
    }
  }

  Future<void> _revokeAccess() async {
    final grantee = _granteeController.text.trim();
    final fileCid = _fileCidController.text.trim();
    if (grantee.isEmpty || fileCid.isEmpty) {
      _showSnackBar('Please fill grantee and file CID', isError: true);
      return;
    }
    setState(() => _revokeResult = 'Processing...');
    try {
      final r = await ApiService.revokeAccess(grantee: grantee, fileCid: fileCid);
      setState(() => _revokeResult = 'Success: ${r.toString()}');
      _showSnackBar('Access revoked successfully!');
      await _refreshLists();
    } catch (e) {
      setState(() => _revokeResult = 'Error: $e');
      _showSnackBar('Revoke failed: $e', isError: true);
    }
  }

  Future<void> _emergencyAccess() async {
    final fileCid = _fileCidController.text.trim();
    if (fileCid.isEmpty) {
      _showSnackBar('Please fill file CID', isError: true);
      return;
    }
    setState(() => _emergencyResult = 'Processing...');
    try {
      final r = await ApiService.emergencyAccess(fileCid: fileCid);
      setState(() => _emergencyResult = 'Success: ${r.toString()}');
      _showSnackBar('Emergency access granted!');
      await _refreshLists();
    } catch (e) {
      setState(() => _emergencyResult = 'Error: $e');
      _showSnackBar('Emergency request failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade700,
        title: Row(
          children: [
            Icon(Icons.medical_services_rounded, color: Colors.white),
            const SizedBox(width: 12),
            const Text('MedVault Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isRefreshing ? null : _refreshLists,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _refreshLists,
          color: Colors.teal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFileUploadSection(),
                const SizedBox(height: 20),
                _buildKeyUploadSection(),
                const SizedBox(height: 20),
                _buildAccessControlSection(),
                const SizedBox(height: 20),
                _buildGrantsSection(),
                const SizedBox(height: 20),
                _buildAuditSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.cloud_upload_rounded, 'Upload Medical File', Colors.blue),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 2, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                if (_selectedFilename != null) ...[
                  Row(
                    children: [
                      Icon(Icons.insert_drive_file, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedFilename!,
                          style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                          _selectedFilename = null;
                          _selectedFile = null;
                          _selectedBytes = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Select File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadFile,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.upload_rounded),
                        label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_uploadResult.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildResultBox(_uploadResult, _uploadResult.startsWith('Success')),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyUploadSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.vpn_key_rounded, 'Upload Encrypted Key', Colors.purple),
          const SizedBox(height: 16),
          TextField(
            controller: _keyJsonController,
            maxLines: 4,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '{"ephemeralPub": "...", "nonce": "...", "cipher": "...", "mac": "..."}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.purple.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.purple.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.purple.shade500, width: 2),
              ),
              filled: true,
              fillColor: Colors.purple.shade50,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploadingKey ? null : _uploadKey,
                  icon: _isUploadingKey
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_rounded),
                  label: Text(_isUploadingKey ? 'Uploading...' : 'Upload Key'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _keyJsonController.text = '{"ephemeralPub":"abcd","nonce":"xyz","cipher":"deadbeef","mac":"1234"}';
                  });
                },
                icon: const Icon(Icons.code),
                label: const Text('Demo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple.shade700,
                  side: BorderSide(color: Colors.purple.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          if (_uploadKeyResult.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildResultBox(_uploadKeyResult, _uploadKeyResult.startsWith('Success')),
          ],
        ],
      ),
    );
  }

  Widget _buildAccessControlSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.admin_panel_settings_rounded, 'Access Control', Colors.orange),
          const SizedBox(height: 16),
          _buildTextField(_granteeController, 'Grantee Address', Icons.person, '0x...'),
          const SizedBox(height: 12),
          _buildTextField(_fileCidController, 'File CID', Icons.fingerprint, 'bafy...'),
          const SizedBox(height: 12),
          _buildTextField(_encKeyCidController, 'Encrypted Key CID', Icons.key, 'bafy...'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton('Grant', Icons.check_circle, Colors.green, _grantAccess),
              _buildActionButton('Revoke', Icons.cancel, Colors.red, _revokeAccess),
              _buildActionButton('Emergency', Icons.warning_rounded, Colors.amber.shade700, _emergencyAccess),
            ],
          ),
          if (_grantResult.isNotEmpty || _revokeResult.isNotEmpty || _emergencyResult.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (_grantResult.isNotEmpty) _buildResultBox(_grantResult, _grantResult.startsWith('Success')),
            if (_revokeResult.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildResultBox(_revokeResult, _revokeResult.startsWith('Success')),
            ],
            if (_emergencyResult.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildResultBox(_emergencyResult, _emergencyResult.startsWith('Success')),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGrantsSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.list_alt_rounded, 'Active Grants', Colors.teal),
          const SizedBox(height: 16),
          if (_grants.isEmpty)
            _buildEmptyState(Icons.folder_open, 'No grants yet')
          else
            ..._grants.map((g) {
              final grantee = (g is Map) ? g['grantee'] ?? '' : '';
              final fileCid = (g is Map) ? (g['fileCid'] ?? g['fileCID'] ?? '') : '';
              final enc = (g is Map) ? (g['encKeyCid'] ?? g['encKey'] ?? '') : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade50, Colors.teal.shade100.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade600,
                      child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      _truncate(fileCid.toString(), 30),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.person, 'Grantee', _truncate(grantee, 25)),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.key, 'Enc Key', _truncate(enc, 25)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildAuditSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.history_rounded, 'Audit Trail', Colors.indigo),
          const SizedBox(height: 16),
          if (_audit.isEmpty)
            _buildEmptyState(Icons.receipt_long, 'No audit events yet')
          else
            ..._audit.map((e) {
              final ev = (e is Map) ? e : <String, dynamic>{};
              final txt = (ev['event'] != null) ? '${ev['event']}' : '${ev['action'] ?? 'Event'}';
              final meta = ev['args'] ?? ev['fileCid'] ?? '';
              final txHash = ev['txHash'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade50, Colors.indigo.shade100.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade600,
                      child: const Icon(Icons.receipt, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      txt,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        if (meta.toString().isNotEmpty)
                          Text(
                            _truncate(meta.toString(), 40),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        if (txHash.toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _buildInfoRow(Icons.tag, 'TX', _truncate(txHash.toString(), 25)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade500, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
    );
  }

  Widget _buildResultBox(String text, bool isSuccess) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}