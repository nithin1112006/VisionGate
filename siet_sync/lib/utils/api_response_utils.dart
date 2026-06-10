import 'dart:convert';

class ApiResponseUtils {
  static Map<String, dynamic>? tryParseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String nonJsonErrorMessage(int statusCode, String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return 'Server returned HTTP $statusCode with empty response.';
    }

    final lower = trimmed.toLowerCase();
    if (lower.contains('error code: 1033') || lower.contains('error 1033')) {
      return 'Server tunnel/domain is unavailable (error 1033). Please ensure the backend is running and the configured API URL is reachable.';
    }

    if (trimmed.startsWith('<!DOCTYPE html') || trimmed.startsWith('<html')) {
      return 'Server returned an HTML error page (HTTP $statusCode). Please verify the API URL in app configuration.';
    }

    final preview = trimmed.length > 180
        ? '${trimmed.substring(0, 180)}...'
        : trimmed;
    return 'Server error (HTTP $statusCode): $preview';
  }
}
