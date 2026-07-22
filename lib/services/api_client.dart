import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/common.dart';

class ApiClient {
  String? _token;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await http
        .get(_uri(path), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await http
        .get(_uri(path), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await http
        .delete(_uri(path), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.body.isEmpty) {
      throw ApiException(response.statusCode, 'Empty response from server');
    }
    final decoded = _decodeJson(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException(response.statusCode, 'Unexpected response format');
    }

    final error = decoded is Map ? decoded['error'] as String? : null;
    throw ApiException(response.statusCode, error ?? 'Unknown error');
  }

  List<dynamic> _handleListResponse(http.Response response) {
    if (response.body.isEmpty) {
      throw ApiException(response.statusCode, 'Empty response from server');
    }
    final decoded = _decodeJson(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List<dynamic>) return decoded;
      throw ApiException(response.statusCode, 'Unexpected response format');
    }
    final error =
        decoded is Map ? decoded['error'] as String? : 'Unknown error';
    throw ApiException(response.statusCode, error ?? 'Unknown error');
  }

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      // Body is not JSON — use the raw text if non-empty
      if (response.body.trim().isNotEmpty) {
        throw ApiException(response.statusCode, response.body.trim());
      }
      throw ApiException(
          response.statusCode,
          'Server returned invalid response'
          ' (status ${response.statusCode})');
    }
  }
}
