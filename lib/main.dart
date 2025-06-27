import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import 'models/posture_models.dart';
import 'services/background_process_service.dart';

///TODO:
//! - Clean code architecture
//! - Implement proper state management
//! - Improve code readability and maintainability
//! - Improve UI
//! - Handle delay in state and notifications
//! - Implement proper notifications
//! - Handle if multiple people in front of screen

/// Entry point for the Posture Monitor Flutter application.
/// Initializes window manager and launches the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(400, 300),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const PostureMonitorApp());
}

/// The root widget for the Posture Monitor app.
class PostureMonitorApp extends StatelessWidget {
  const PostureMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Monitor',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const PostureMonitorHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Enum representing the user's posture state.
enum PostureState { upright, leaning, notResolved }

/// The main home screen for posture monitoring.
class PostureMonitorHome extends StatefulWidget {
  const PostureMonitorHome({super.key});

  @override
  State<PostureMonitorHome> createState() => _PostureMonitorHomeState();
}

class _PostureMonitorHomeState extends State<PostureMonitorHome>
    with WindowListener {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  PostureMonitorClient? _client;
  PostureState _currentPosture = PostureState.notResolved;
  bool _isMonitoring = false;
  double _sensitivity = 0.4;

  StreamSubscription<PostureResult>? _postureSubscription;
  StreamSubscription<PostureError>? _errorSubscription;
  StreamSubscription<PostureStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeNotifications();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _stopMonitoring();
    _client?.dispose();
    super.dispose();
  }

  /// Initializes local notifications for posture alerts and errors.
  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const initializationSettings = InitializationSettings(
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap if needed
      },
    );
  }

  /// Shows a local notification with the given [title] and [body].
  Future<void> _showNotification(String title, String body) async {
    const platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'posture_monitor',
        'Posture Monitor',
        channelDescription: 'Notifications for posture monitoring',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  /// Starts posture monitoring and subscribes to result streams.
  void _startMonitoring() async {
    try {
      final config = PostureMonitorConfig(
        sensitivity: _sensitivity,
        interval: 1.0,
        verbose: true,
      );
      _client = PostureMonitorClient(config: config);

      _postureSubscription = _client!.postureStream.listen((result) {
        setState(() {
          _currentPosture = result.isLeaning
              ? PostureState.leaning
              : PostureState.upright;
        });
        if (result.isLeaning) {
          _showNotification(
            'Posture Alert',
            'You are leaning! Please sit up straight.',
          );
        }
      });

      _errorSubscription = _client!.errorStream.listen((error) {
        setState(() {
          _currentPosture = PostureState.notResolved;
        });
        _showNotification(
          'Posture Monitor Error',
          'Could not detect posture: ${error.message}',
        );
      });

      _statusSubscription = _client!.statusStream.listen((status) {
        // Optionally handle status updates
        print('Status: ${status.message}');
      });

      await _client!.start();
      setState(() {
        _isMonitoring = true;
      });
    } catch (e) {
      setState(() {
        _currentPosture = PostureState.notResolved;
      });
      _showNotification('Failed to Start Monitoring', 'Error: ${e.toString()}');
    }
  }

  /// Stops posture monitoring and cancels all subscriptions.
  void _stopMonitoring() async {
    await _postureSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _client?.stop();
    setState(() {
      _isMonitoring = false;
      _currentPosture = PostureState.notResolved;
    });
  }

  /// Returns the color representing the current posture state.
  Color _getStatusColor() {
    switch (_currentPosture) {
      case PostureState.upright:
        return Colors.green;
      case PostureState.leaning:
        return Colors.red;
      case PostureState.notResolved:
        return Colors.orange;
    }
  }

  /// Returns the text label for the current posture state.
  String _getStatusText() {
    switch (_currentPosture) {
      case PostureState.upright:
        return 'Upright';
      case PostureState.leaning:
        return 'Leaning';
      case PostureState.notResolved:
        return 'Not Resolved';
    }
  }

  /// Returns the icon for the current posture state.
  IconData _getStatusIcon() {
    switch (_currentPosture) {
      case PostureState.upright:
        return Icons.check_circle;
      case PostureState.leaning:
        return Icons.warning;
      case PostureState.notResolved:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posture Monitor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getStatusColor().withValues(alpha: 0.1),
                border: Border.all(color: _getStatusColor(), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(_getStatusIcon(), size: 48, color: _getStatusColor()),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Sensitivity Slider
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensitivity: ${_sensitivity.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: _sensitivity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: _isMonitoring
                          ? null
                          : (value) {
                              setState(() {
                                _sensitivity = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Start/Stop Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
                icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles window close event to hide to system tray instead of exiting.
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }
}
