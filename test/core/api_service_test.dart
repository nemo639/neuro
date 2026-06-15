// Unit tests for ApiService — config & token storage helpers.
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse/core/api_service.dart';

void main() {
  group('ApiService config', () {
    test('baseUrl returns non-empty production URL', () {
      final url = ApiService.baseUrl;
      expect(url, isNotEmpty);
      expect(url.startsWith('http'), true,
          reason: 'baseUrl must be a valid HTTP/HTTPS URL');
    });

    test('apiVersion is /api/v1', () {
      expect(ApiService.apiVersion, '/api/v1');
    });

    test('full URL composition is correct', () {
      final fullUrl = '${ApiService.baseUrl}${ApiService.apiVersion}/health';
      expect(fullUrl, contains('/api/v1/health'));
    });

    test('baseUrl uses HTTPS in production', () {
      final url = ApiService.baseUrl;
      expect(url.startsWith('https://') || url.startsWith('http://localhost'), true,
          reason: 'Production URL should use HTTPS');
    });
  });
}
