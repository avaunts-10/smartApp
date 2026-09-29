/*import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    TokenStorage? tokenStorage,
  }) : _tokenStorage = tokenStorage ?? TokenStorage();

  final String baseUrl; // e.g. http://localhost:4000
  final TokenStorage _tokenStorage;

  // ----------------- helpers -----------------

  Map<String, dynamic> _decodeBody(http.Response res) {
    final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  void _ensureOk(http.Response res, Map<String, dynamic> data) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Request failed (${res.statusCode})');
    }
  }

  Future<String> _requireToken() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      throw Exception('No token. Please login again.');
    }
    return token;
  }

  // ---------- PUBLIC REQUESTS (no token) ----------

  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.get(
      uri,
      headers: const {'Content-Type': 'application/json'},
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  /// ✅ Public PATCH (no token)
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  // ---------- AUTHED REQUESTS (token required) ----------

  Future<Map<String, dynamic>> getAuthed(String path) async {
    final token = await _requireToken();
    final uri = Uri.parse('$baseUrl$path');

    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  Future<Map<String, dynamic>> postAuthed(String path, Map<String, dynamic> body) async {
    final token = await _requireToken();
    final uri = Uri.parse('$baseUrl$path');

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  Future<Map<String, dynamic>> patchAuthed(String path, Map<String, dynamic> body) async {
    final token = await _requireToken();
    final uri = Uri.parse('$baseUrl$path');

    final res = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  // ---------- TOKEN HELPERS ----------

  Future<void> saveToken(String token) => _tokenStorage.save(token);
  Future<void> logout() => _tokenStorage.clear();
}
*/
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    TokenStorage? tokenStorage,
  }) : _tokenStorage = tokenStorage ?? TokenStorage();

  final String baseUrl;
  final TokenStorage _tokenStorage;

  Map<String, dynamic> _decodeBody(http.Response res) {
    final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  void _ensureOk(http.Response res, Map<String, dynamic> data) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Request failed (${res.statusCode})');
    }
  }

  Future<String> _requireToken() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      throw Exception('No token. Please login again.');
    }
    return token;
  }

  // ---------------- PUBLIC ----------------

  Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  // ---------------- AUTHED ----------------

  Future<Map<String, dynamic>> getAuthed(String path) async {
    final token = await _requireToken();
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  Future<Map<String, dynamic>> postAuthed(String path, Map<String, dynamic> body) async {
    final token = await _requireToken();
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  Future<Map<String, dynamic>> patchAuthed(String path, Map<String, dynamic> body) async {
    final token = await _requireToken();
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  /// Like [postAuthed], but for endpoints that expect a raw JSON array (or
  /// any non-object payload) instead of a JSON object body.
  Future<Map<String, dynamic>> postAuthedJson(String path, dynamic body) async {
    final token = await _requireToken();
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  /// Multipart POST with an optional file field, for endpoints backed by
  /// multer on the backend (notice attachments, learning materials).
  Future<Map<String, dynamic>> postMultipartAuthed(
    String path,
    Map<String, String> fields, {
    String? fileFieldName,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final token = await _requireToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll(fields);

    if (fileFieldName != null && fileBytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileFieldName,
        fileBytes,
        filename: fileName,
      ));
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  Future<Map<String, dynamic>> deleteAuthed(String path) async {
    final token = await _requireToken();
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final data = _decodeBody(res);
    _ensureOk(res, data);
    return data;
  }

  // ---------------- TOKEN HELPERS ----------------

  Future<void> saveToken(String token) => _tokenStorage.save(token);
  Future<void> logout() => _tokenStorage.clear();

  /// The raw stored JWT (for passing to the embedded face-capture iframe).
  Future<String?> currentToken() => _tokenStorage.read();
}
