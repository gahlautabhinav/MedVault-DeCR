// dashboard_screen.dart
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
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
    _pulseController.dispose();
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied to clipboard!', icon: Icons.check_circle);
  }

  void _showSnackBar(String message, {bool isError = false, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon ?? (isError ? Icons.error_outline : Icons.check_circle_outline), 
                 color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.teal.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
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

      setState(() => _uploadResult = resp.toString());
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
      setState(() => _uploadKeyResult = r.toString());
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
      setState(() => _grantResult = r.toString());
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
      setState(() => _revokeResult = r.toString());
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
      setState(() => _emergencyResult = r.toString());
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal.shade700,
              Colors.teal.shade500,
              Colors.cyan.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _refreshLists,
                    color: Colors.teal,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsCards(),
                          const SizedBox(height: 24),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MedVault',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Secure Medical Records',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _isRefreshing ? null : _refreshLists,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Files',
            '${_grants.length}',
            Icons.folder_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Audit Events',
            '${_audit.length}',
            Icons.history_rounded,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.cloud_upload_rounded, 'Upload Medical File', Colors.blue),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: Column(
              children: [
                if (_selectedFilename != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.insert_drive_file, color: Colors.blue.shade700, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFilename!,
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ready to upload',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade600),
                          onPressed: () => setState(() {
                            _selectedFilename = null;
                            _selectedFile = null;
                            _selectedBytes = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _buildGradientButton(
                        label: 'Select File',
                        icon: Icons.attach_file,
                        colors: [Colors.white, Colors.white],
                        textColor: Colors.blue.shade700,
                        onPressed: _pickFile,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGradientButton(
                        label: _isUploading ? 'Uploading...' : 'Upload',
                        icon: Icons.upload_rounded,
                        colors: [Colors.blue.shade600, Colors.blue.shade700],
                        textColor: Colors.white,
                        onPressed: _isUploading ? null : _uploadFile,
                        isLoading: _isUploading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_uploadResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCopyableResultBox(_uploadResult, !_uploadResult.contains('Error')),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyUploadSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.vpn_key_rounded, 'Encrypted Key', Colors.purple),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade200, width: 2),
            ),
            child: TextField(
              controller: _keyJsonController,
              maxLines: 4,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '{"ephemeralPub": "...", "nonce": "...", "cipher": "...", "mac": "..."}',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                hintStyle: TextStyle(color: Colors.purple.shade300),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildGradientButton(
                  label: _isUploadingKey ? 'Uploading...' : 'Upload Key',
                  icon: Icons.upload_rounded,
                  colors: [Colors.purple.shade600, Colors.purple.shade700],
                  textColor: Colors.white,
                  onPressed: _isUploadingKey ? null : _uploadKey,
                  isLoading: _isUploadingKey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGradientButton(
                  label: 'Demo',
                  icon: Icons.code,
                  colors: [Colors.white, Colors.white],
                  textColor: Colors.purple.shade700,
                  onPressed: () {
                    setState(() {
                      _keyJsonController.text = '{"ephemeralPub":"abcd","nonce":"xyz","cipher":"deadbeef","mac":"1234"}';
                    });
                  },
                ),
              ),
            ],
          ),
          if (_uploadKeyResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCopyableResultBox(_uploadKeyResult, !_uploadKeyResult.contains('Error')),
          ],
        ],
      ),
    );
  }

  Widget _buildAccessControlSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.admin_panel_settings_rounded, 'Access Control', Colors.orange),
          const SizedBox(height: 20),
          _buildModernTextField(_granteeController, 'Grantee Address', Icons.person, '0x...'),
          const SizedBox(height: 14),
          _buildModernTextField(_fileCidController, 'File CID', Icons.fingerprint, 'bafy...'),
          const SizedBox(height: 14),
          _buildModernTextField(_encKeyCidController, 'Encrypted Key CID', Icons.key, 'bafy...'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildGradientButton(
                label: 'Grant',
                icon: Icons.check_circle,
                colors: [Colors.green.shade500, Colors.green.shade600],
                textColor: Colors.white,
                onPressed: _grantAccess,
              ),
              _buildGradientButton(
                label: 'Revoke',
                icon: Icons.cancel,
                colors: [Colors.red.shade500, Colors.red.shade600],
                textColor: Colors.white,
                onPressed: _revokeAccess,
              ),
              _buildGradientButton(
                label: 'Emergency',
                icon: Icons.warning_rounded,
                colors: [Colors.amber.shade600, Colors.amber.shade700],
                textColor: Colors.white,
                onPressed: _emergencyAccess,
              ),
            ],
          ),
          if (_grantResult.isNotEmpty || _revokeResult.isNotEmpty || _emergencyResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (_grantResult.isNotEmpty) _buildCopyableResultBox(_grantResult, !_grantResult.contains('Error')),
            if (_revokeResult.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildCopyableResultBox(_revokeResult, !_revokeResult.contains('Error')),
            ],
            if (_emergencyResult.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildCopyableResultBox(_emergencyResult, !_emergencyResult.contains('Error')),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGrantsSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.list_alt_rounded, 'Active Grants', Colors.teal),
          const SizedBox(height: 20),
          if (_grants.isEmpty)
            _buildEmptyState(Icons.folder_open, 'No grants yet')
          else
            ..._grants.asMap().entries.map((entry) {
              final index = entry.key;
              final g = entry.value;
              final grantee = (g is Map) ? g['grantee'] ?? '' : '';
              final fileCid = (g is Map) ? (g['fileCid'] ?? g['fileCID'] ?? '') : '';
              final enc = (g is Map) ? (g['encKeyCid'] ?? g['encKey'] ?? '') : '';
              
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 400 + (index * 100)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade50, Colors.cyan.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.teal.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.teal.shade400, Colors.teal.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.teal.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Grant #${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCopyableInfoRow('File CID', fileCid.toString(), Icons.fingerprint),
                          const SizedBox(height: 10),
                          _buildCopyableInfoRow('Grantee', grantee.toString(), Icons.person),
                          const SizedBox(height: 10),
                          _buildCopyableInfoRow('Enc Key', enc.toString(), Icons.key),
                        ],
                      ),
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
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.history_rounded, 'Audit Trail', Colors.indigo),
          const SizedBox(height: 20),
          if (_audit.isEmpty)
            _buildEmptyState(Icons.receipt_long, 'No audit events yet')
          else
            ..._audit.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;
              final ev = (e is Map) ? e : <String, dynamic>{};
              final txt = (ev['event'] != null) ? '${ev['event']}' : '${ev['action'] ?? 'Event'}';
              final meta = ev['args'] ?? ev['fileCid'] ?? '';
              final txHash = ev['txHash'] ?? '';
              
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 400 + (index * 100)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade50, Colors.purple.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.indigo.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.indigo.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.receipt, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  txt,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (meta.toString().isNotEmpty || txHash.toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            if (meta.toString().isNotEmpty)
                              _buildCopyableInfoRow('Data', meta.toString(), Icons.data_object),
                            if (txHash.toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildCopyableInfoRow('TX Hash', txHash.toString(), Icons.tag),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    String hint,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 22, color: Colors.grey.shade600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required Color textColor,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400])
            : LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: colors.first.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildCopyableResultBox(String text, bool isSuccess) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSuccess
              ? [Colors.green.shade50, Colors.green.shade100.withOpacity(0.5)]
              : [Colors.red.shade50, Colors.red.shade100.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSuccess ? Colors.green.shade300 : Colors.red.shade300,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copyToClipboard(text, 'Result'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.copy,
                  size: 18,
                  color: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyableInfoRow(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copyToClipboard(value, label),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 56, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}