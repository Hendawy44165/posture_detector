import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/posture_monitor_provider.dart';
import 'components/theme/app_theme.dart';
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

  runApp(const ProviderScope(child: PostureMonitorApp()));
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

class PostureMonitorScreen extends ConsumerStatefulWidget {
  const PostureMonitorScreen({super.key});

  @override
  ConsumerState<PostureMonitorScreen> createState() =>
      _PostureMonitorScreenState();
}

class _PostureMonitorScreenState extends ConsumerState<PostureMonitorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // TODO: make the animation pause when the app is not in focus

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(postureMonitorProvider);
    final monitorNotifier = ref.read(postureMonitorProvider.notifier);

    if (monitorState.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(monitorState.errorMessage!),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        monitorNotifier.clearErrorState();
      });
    }

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
                              postureState: monitorState.postureState,
                              isMonitoring: monitorState.isMonitoring,
                              pulseAnimation: _pulseAnimation,
                              isWideScreen: isWideScreen,
                            ),
                            SizedBox(height: isWideScreen ? 32 : 24),
                            SensitivityCard(
                              sensitivity: monitorState.sensitivity,
                              onSensitivityChanged: (value) {
                                monitorNotifier.updateSensitivity(value);
                              },
                              isWideScreen: isWideScreen,
                            ),
                            SizedBox(height: isWideScreen ? 32 : 24),
                            ControlButton(
                              isMonitoring: monitorState.isMonitoring,
                              onStartPressed: monitorNotifier.startMonitoring,
                              onStopPressed: monitorNotifier.stopMonitoring,
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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
