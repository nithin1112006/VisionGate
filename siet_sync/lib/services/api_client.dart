import 'dart:convert';
import 'package:http/http.dart' as http;

/// Custom HTTP client for API requests.
class ApiClient {
  final http.Client _client = http.Client();

  Map<String, String> _buildHeaders({
    String? token,
    Map<String, String>? extraHeaders,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<http.Response> get(
    String url, {
    String? token,
    String? cacheKey,
    Duration? cacheDuration,
    Map<String, String>? headers,
  }) async {
    return _client.get(
      Uri.parse(url),
      headers: _buildHeaders(token: token, extraHeaders: headers),
    );
  }

  Future<http.Response> post(
    String url, {
    String? token,
    Object? body,
    Encoding? encoding,
    Map<String, String>? headers,
  }) async {
    return _client.post(
      Uri.parse(url),
      headers: _buildHeaders(token: token, extraHeaders: headers),
      body: body,
      encoding: encoding,
    );
  }

  Future<http.Response> put(
    String url, {
    String? token,
    Object? body,
    Encoding? encoding,
    Map<String, String>? headers,
  }) async {
    return _client.put(
      Uri.parse(url),
      headers: _buildHeaders(token: token, extraHeaders: headers),
      body: body,
      encoding: encoding,
    );
  }

  Future<http.Response> delete(
    String url, {
    String? token,
    Object? body,
    Encoding? encoding,
    Map<String, String>? headers,
  }) async {
    return _client.delete(
      Uri.parse(url),
      headers: _buildHeaders(token: token, extraHeaders: headers),
      body: body,
      encoding: encoding,
    );
  }

  void close() {
    _client.close();
  }
}

/// Global API client instance - use this instead of direct http.get/post calls
final apiClient = ApiClient();
