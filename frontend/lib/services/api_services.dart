// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Base URL of your backend (adjust if different)
const String _baseUrl = 'http://localhost:3001';

class ApiService {
  /// Upload a dart:io File (desktop). Returns decoded JSON map from backend.
  static Future<Map<String, dynamic>> uploadFile(File file) async {
    final uri = Uri.parse('$_baseUrl/api/upload');
    final request = http.MultipartRequest('POST', uri);

    final multipartFile = await http.MultipartFile.fromPath('file', file.path);
    request.files.add(multipartFile);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('uploadFile failed: ${resp.statusCode} ${resp.body}');
  }

  /// Upload file from bytes (web): provide bytes and filename.
  static Future<Map<String, dynamic>> uploadFileFromBytes(Uint8List bytes, { required String filename }) async {
    final uri = Uri.parse('$_baseUrl/api/upload');
    final request = http.MultipartRequest('POST', uri);

    final multipartFile = http.MultipartFile.fromBytes('file', bytes, filename: filename);
    request.files.add(multipartFile);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('uploadFileFromBytes failed: ${resp.statusCode} ${resp.body}');
  }

  /// Upload the symmetric key JSON (body is a Map)
  static Future<Map<String, dynamic>> uploadKey(Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl/api/upload-key');
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('uploadKey failed: ${resp.statusCode} ${resp.body}');
  }

  /// Grant access on-chain (backend will call contract)
  static Future<Map<String, dynamic>> grantAccess({
    required String grantee,
    required String fileCid,
    required String encKeyCid,
    int expirySecs = 600,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/grant-access');
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'grantee': grantee,
          'fileCid': fileCid,
          'encKeyCid': encKeyCid,
          'expirySecs': expirySecs,
        }));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('grantAccess failed: ${resp.statusCode} ${resp.body}');
  }

  /// Revoke access
  static Future<Map<String, dynamic>> revokeAccess({
    required String grantee,
    required String fileCid,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/revoke-access');
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'grantee': grantee, 'fileCid': fileCid}));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('revokeAccess failed: ${resp.statusCode} ${resp.body}');
  }

  /// Emergency access
  static Future<Map<String, dynamic>> emergencyAccess({
    required String fileCid,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/emergency-access');
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fileCid': fileCid}));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('emergencyAccess failed: ${resp.statusCode} ${resp.body}');
  }

  /// Get local + onchain audit (indexer writes audit_db.json)
  static Future<List<dynamic>> getOnchainAudit({String? filterType}) async {
    final uri = Uri.parse('$_baseUrl/api/onchain-audit' + (filterType != null ? '?type=$filterType' : ''));
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw HttpException('getOnchainAudit failed: ${resp.statusCode} ${resp.body}');
  }

  /// Get local audit.json (uploaded files etc)
  static Future<Map<String, dynamic>> getAudit() async {
    final uri = Uri.parse('$_baseUrl/api/audit');
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('getAudit failed: ${resp.statusCode} ${resp.body}');
  }

  /// Get grants list from backend
  static Future<List<dynamic>> getGrants() async {
    final uri = Uri.parse('$_baseUrl/api/grants');
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw HttpException('getGrants failed: ${resp.statusCode} ${resp.body}');
  }
}
