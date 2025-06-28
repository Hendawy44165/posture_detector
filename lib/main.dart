import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import 'models/posture_models.dart';
import 'services/background_process_service.dart';

import 'components/theme/app_theme.dart';
import 'components/enums/posture_state.dart';
import 'components/widgets/window_controls.dart';
import 'components/widgets/header.dart';
import 'components/widgets/status_card.dart';
import 'components/widgets/sensitivity_card.dart';
import 'components/widgets/control_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    fullScreen: true,
    minimumSize: Size(600, 400),
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const PostureMonitorApp());
}

class PostureMonitorApp extends StatelessWidget {
  const PostureMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Monitor',
      theme: AppTheme.darkTheme,
      home: const PostureMonitorScreen(),
    );
  }
}

class PostureMonitorScreen extends StatefulWidget {
  const PostureMonitorScreen({super.key});

  @override
  State<PostureMonitorScreen> createState() => _PostureMonitorScreenState();
}

class _PostureMonitorScreenState extends State<PostureMonitorScreen>
    with TickerProviderStateMixin {
  PostureMonitorClient? _client;
  PostureState _currentPosture = PostureState.notResolved;
  bool _isMonitoring = false;
  double _sensitivity = 0.4;

  StreamSubscription<PostureResult>? _postureSubscription;
  StreamSubscription<PostureError>? _errorSubscription;
  StreamSubscription<PostureStatus>? _statusSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // TODO: make the animation pause when the app is not in focus

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _startMonitoring() async {
    try {
      final config = PostureMonitorConfig(
        sensitivity: _sensitivity,
        interval: 1.0,
        verbose: true,
      );
      _client = PostureMonitorClient(config: config);

      _postureSubscription = _client!.postureStream.listen(
        _handlePostureResult,
        onError: _handleStreamError,
      );

      _errorSubscription = _client!.errorStream.listen(
        _handlePostureError,
        onError: _handleStreamError,
      );

      _statusSubscription = _client!.statusStream.listen(
        _handleStatusUpdate,
        onError: _handleStreamError,
      );

      await _client!.start();
      setState(() => _isMonitoring = true);
    } catch (e) {
      setState(() => _currentPosture = PostureState.notResolved);
      _showErrorSnackBar('Failed to start monitoring: ${e.toString()}');
    }
  }

  Future<void> _stopMonitoring() async {
    await _postureSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _client?.stop();

    setState(() {
      _isMonitoring = false;
      _currentPosture = PostureState.notResolved;
    });
  }

  void _handlePostureResult(PostureResult result) {
    setState(() {
      _currentPosture = result.isLeaning
          ? PostureState.leaning
          : PostureState.upright;
    });
  }

  void _handlePostureError(PostureError error) {
    setState(() => _currentPosture = PostureState.notResolved);
    _showErrorSnackBar('Detection error: ${error.message}');
  }

  void _handleStatusUpdate(PostureStatus status) {
    debugPrint('Status: ${status.message}');
  }

  void _handleStreamError(dynamic error) {
    setState(() => _currentPosture = PostureState.notResolved);
    _showErrorSnackBar('Stream error: ${error.toString()}');
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Column(
          children: [
            const WindowControls(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 800;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isWideScreen ? 48.0 : 24.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Header(isWideScreen: isWideScreen),
                            SizedBox(height: isWideScreen ? 48 : 32),
                            StatusCard(
                              postureState: _currentPosture,
                              isMonitoring: _isMonitoring,
                              pulseAnimation: _pulseAnimation,
                              isWideScreen: isWideScreen,
                            ),
                            SizedBox(height: isWideScreen ? 32 : 24),
                            SensitivityCard(
                              sensitivity: _sensitivity,
                              onSensitivityChanged: (value) {
                                setState(() => _sensitivity = value);
                                _stopMonitoring();
                              },
                              isWideScreen: isWideScreen,
                            ),
                            SizedBox(height: isWideScreen ? 32 : 24),
                            ControlButton(
                              isMonitoring: _isMonitoring,
                              onStartPressed: _startMonitoring,
                              onStopPressed: _stopMonitoring,
                              isWideScreen: isWideScreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopMonitoring();
    _client?.dispose();
    super.dispose();
  }
}
