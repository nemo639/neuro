// Unit tests for CacheService — SharedPreferences-backed JSON cache with TTL.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuroverse/core/cache_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('CacheService', () {
    test('returns null for missing key', () async {
      final result = await CacheService.get('nonexistent');
      expect(result, isNull);
    });

    test('stores and retrieves data', () async {
      final data = {'name': 'Test User', 'age': 25};
      await CacheService.set('user_profile', data);
      final result = await CacheService.get('user_profile');
      expect(result, isNotNull);
      expect(result!['name'], 'Test User');
      expect(result['age'], 25);
    });

    test('stores nested objects', () async {
      final data = {
        'dash': {'success': true, 'data': {'risk': 30}},
        'profile': {'first_name': 'Test'},
      };
      await CacheService.set('home_dashboard', data);
      final result = await CacheService.get('home_dashboard');
      expect(result, isNotNull);
      expect(result!['dash']['success'], true);
      expect(result['profile']['first_name'], 'Test');
    });

    test('clear removes a single entry', () async {
      await CacheService.set('key1', {'foo': 'bar'});
      await CacheService.set('key2', {'baz': 'qux'});
      await CacheService.clear('key1');
      expect(await CacheService.get('key1'), isNull);
      expect(await CacheService.get('key2'), isNotNull);
    });

    test('clearAll removes everything', () async {
      await CacheService.set('a', {'x': 1});
      await CacheService.set('b', {'y': 2});
      await CacheService.clearAll();
      expect(await CacheService.get('a'), isNull);
      expect(await CacheService.get('b'), isNull);
    });

    test('overwrites existing key', () async {
      await CacheService.set('user', {'name': 'Alice'});
      await CacheService.set('user', {'name': 'Bob'});
      final result = await CacheService.get('user');
      expect(result!['name'], 'Bob');
    });
  });
}
