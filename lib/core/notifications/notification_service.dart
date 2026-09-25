import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local push notifications driven by Brain events.
///
/// The node emits ``notification`` events (NotificationActuator); Brain
/// fans them out over ``/v1/events/stream``; this service turns each one
/// into a system notification. Delivery is confirmed Brain-side — the
/// local notification is a display path, not the store of record.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 1;

  Future<void> init() async {
    if (_ready) return;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(init);
    // Android 13+ requires a runtime permission request.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> show(String title, String body,
      {String severity = 'info',}) async {
    if (!_ready) await init();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'thoth_events', 'Thoth Events',
        channelDescription: 'Node predictions and automation alerts',
        importance: severity == 'alert'
            ? Importance.max
            : Importance.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(_nextId++, title, body, details);
  }
}
