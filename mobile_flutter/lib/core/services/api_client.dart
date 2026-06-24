import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/app_constants.dart';
import 'local_storage_service.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiRawResponse {
  const ApiRawResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, dynamic> body;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();
  final LocalStorageService _storage = LocalStorageService.instance;

  String get _baseUrl => AppConstants.apiBaseUrl;

  Future<ApiRawResponse> getRaw(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _client.get(
      Uri.parse(_resolveUrl(path)),
      headers: _headers(authenticated: authenticated),
    );
    return ApiRawResponse(
      statusCode: response.statusCode,
      body: _decodeBody(response.bodyBytes),
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = true,
  }) async {
    final raw = await getRaw(path, authenticated: authenticated);
    return _ensureSuccess(raw);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _client.post(
      Uri.parse(_resolveUrl(path)),
      headers: _headers(authenticated: authenticated),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _ensureSuccess(
      ApiRawResponse(
        statusCode: response.statusCode,
        body: _decodeBody(response.bodyBytes),
      ),
    );
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _client.delete(
      Uri.parse(_resolveUrl(path)),
      headers: _headers(authenticated: authenticated),
    );
    return _ensureSuccess(
      ApiRawResponse(
        statusCode: response.statusCode,
        body: _decodeBody(response.bodyBytes),
      ),
    );
  }

  Future<Map<String, dynamic>> postMultipartJson(
    String path, {
    required String filePath,
    required String fieldName,
    required MediaType contentType,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_resolveUrl(path)))
      ..headers.addAll(_headers(authenticated: true, isJson: false))
      ..fields.addAll(fields ?? <String, String>{})
      ..files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          filePath,
          contentType: contentType,
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _ensureSuccess(
      ApiRawResponse(
        statusCode: response.statusCode,
        body: _decodeBody(response.bodyBytes),
      ),
    );
  }

  Map<String, String> _headers({
    required bool authenticated,
    bool isJson = true,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (authenticated) {
      final token = _storage.getString(AppConstants.accessTokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _ensureSuccess(ApiRawResponse response) {
    final data = response.body;
    final message = _extractMessage(data);

    if (response.statusCode >= 400) {
      throw ApiException(message, statusCode: response.statusCode);
    }

    if (data.containsKey('code') && data['code'] != 200) {
      throw ApiException(message, statusCode: response.statusCode);
    }

    return data;
  }

  Map<String, dynamic> _decodeBody(List<int> bytes) {
    if (bytes.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = utf8.decode(bytes);
    if (decoded.isEmpty) {
      return <String, dynamic>{};
    }
    final jsonBody = jsonDecode(decoded);
    if (jsonBody is Map<String, dynamic>) {
      return jsonBody;
    }
    return <String, dynamic>{'data': jsonBody};
  }

  String _extractMessage(Map<String, dynamic> body) {
    return body['message'] as String? ??
        body['detail'] as String? ??
        '请求失败，请稍后重试';
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      return '$_baseUrl$path';
    }
    return '$_baseUrl/$path';
  }
}
