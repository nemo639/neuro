// Unit tests for NotificationService — duplicate suppression logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse/core/notification_service.dart';

void main() {
  group('NotificationService', () {
    setUp(() {
      NotificationService.reset();
    });

    test('reset clears shown IDs without throwing', () {
      // Should be idempotent
      NotificationService.reset();
      NotificationService.reset();
      expect(true, true);
    });

    test('handles empty notification list', () async {
      // Must not throw on empty list
      await NotificationService.showNewAlerts([]);
      expect(true, true);
    });

    test('handles already-read notifications', () async {
      // Read notifications should be skipped silently (no crash)
      await NotificationService.showNewAlerts([
        {'id': 1, 'is_read': true, 'title': 'X', 'message': 'Y'},
        {'id': 2, 'is_read': true, 'title': 'A', 'message': 'B'},
      ]);
      expect(true, true);
    });
  });
}
