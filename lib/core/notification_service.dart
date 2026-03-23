import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize the notification plugin. Call once in main().
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(initSettings);

    // Request notification permission on Android 13+
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Show a local notification with sound and vibration.
  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'neuroverse_alerts',
      'NeuroVerse Alerts',
      channelDescription: 'Notifications for reports, login alerts, and health updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details);
  }

  /// Show notifications for new unread items from the backend.
  /// Tracks already-shown IDs to avoid duplicate rings.
  static final Set<int> _shownIds = {};

  static Future<void> showNewAlerts(List<dynamic> notifications) async {
    for (final notif in notifications) {
      final id = notif['id'] as int? ?? 0;
      final isRead = notif['is_read'] as bool? ?? true;

      if (!isRead && !_shownIds.contains(id)) {
        _shownIds.add(id);
        await show(
          id: id,
          title: notif['title'] ?? 'NeuroVerse',
          body: notif['message'] ?? '',
        );
      }
    }
  }

  /// Clear tracked IDs (e.g. on logout).
  static void reset() {
    _shownIds.clear();
  }
}
