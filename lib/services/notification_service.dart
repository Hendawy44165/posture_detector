import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open');

    const InitializationSettings initSettings = InitializationSettings(
      linux: linuxSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> show(String title, String body) async {
    if (!_initialized) await init();

    final linuxDetails = const LinuxNotificationDetails();
    final details = NotificationDetails(linux: linuxDetails);

    await _plugin.show(0, title, body, details);
  }
}
