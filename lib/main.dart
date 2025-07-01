import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/posture_monitor_provider.dart';
import 'components/theme/app_theme.dart';
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
    minimumSize: Size(600, 400),
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
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
    with WindowListener {
  late StateNotifierProvider<PostureMonitorNotifier, PostureMonitorState>
  postureMonitorProvider;
  late PostureMonitorNotifier monitorNotifier;

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(postureMonitorProvider);

    if (monitorState.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        monitorNotifier.clearErrorState();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Column(
          children: [
            // const WindowControls(),
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

  @override
  void initState() {
    super.initState();
    postureMonitorProvider = getPostureMonitorProvider();
    monitorNotifier = ref.read(postureMonitorProvider.notifier);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    monitorNotifier.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }
}
