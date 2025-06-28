import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import 'models/posture_models.dart';
import 'services/background_process_service.dart';

/// Entry point for the Posture Monitor Flutter application.
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

/// The root application widget with modern dark theme.
class PostureMonitorApp extends StatelessWidget {
  const PostureMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Monitor',
      theme: _buildDarkTheme(),
      home: const PostureMonitorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  /// Creates a modern dark theme with rounded corners and smooth animations.
  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Enum representing different posture states.
enum PostureState { upright, leaning, notResolved }

/// Extension to provide UI properties for posture states.
extension PostureStateExtension on PostureState {
  Color get color {
    switch (this) {
      case PostureState.upright:
        return const Color(0xFF10B981);
      case PostureState.leaning:
        return const Color(0xFFEF4444);
      case PostureState.notResolved:
        return const Color(0xFFF59E0B);
    }
  }

  String get label {
    switch (this) {
      case PostureState.upright:
        return 'Perfect Posture';
      case PostureState.leaning:
        return 'Poor Posture';
      case PostureState.notResolved:
        return 'Detecting...';
    }
  }

  IconData get icon {
    switch (this) {
      case PostureState.upright:
        return Icons.check_circle_rounded;
      case PostureState.leaning:
        return Icons.warning_rounded;
      case PostureState.notResolved:
        return Icons.sync_rounded;
    }
  }
}

/// The main posture monitoring screen with modern UI design.
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

  /// Initialize animations for the status indicator.
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

  /// Starts posture monitoring with the current configuration.
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

  /// Stops posture monitoring and cleans up resources.
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

  /// Handles posture detection results.
  void _handlePostureResult(PostureResult result) {
    setState(() {
      _currentPosture = result.isLeaning
          ? PostureState.leaning
          : PostureState.upright;
    });
  }

  /// Handles posture detection errors.
  void _handlePostureError(PostureError error) {
    setState(() => _currentPosture = PostureState.notResolved);
    _showErrorSnackBar('Detection error: ${error.message}');
  }

  /// Handles status updates from the monitoring service.
  void _handleStatusUpdate(PostureStatus status) {
    debugPrint('Status: ${status.message}');
  }

  /// Handles stream errors.
  void _handleStreamError(dynamic error) {
    setState(() => _currentPosture = PostureState.notResolved);
    _showErrorSnackBar('Stream error: ${error.toString()}');
  }

  /// Shows an error message using a SnackBar.
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
                      _buildHeader(isWideScreen),
                      SizedBox(height: isWideScreen ? 48 : 32),
                      _buildStatusCard(isWideScreen),
                      SizedBox(height: isWideScreen ? 32 : 24),
                      _buildSensitivityCard(isWideScreen),
                      SizedBox(height: isWideScreen ? 32 : 24),
                      _buildControlButton(isWideScreen),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds the application header.
  Widget _buildHeader(bool isWideScreen) {
    return Column(
      children: [
        Icon(
          Icons.monitor_heart_rounded,
          size: isWideScreen ? 64 : 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Posture Monitor',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Monitor your posture in real-time',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  /// Builds the posture status display card.
  Widget _buildStatusCard(bool isWideScreen) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _currentPosture == PostureState.notResolved && _isMonitoring
              ? _pulseAnimation.value
              : 1.0,
          child: Card(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(isWideScreen ? 32 : 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _currentPosture.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _currentPosture.color,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      _currentPosture.icon,
                      size: isWideScreen ? 64 : 48,
                      color: _currentPosture.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentPosture.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _currentPosture.color,
                    ),
                  ),
                  if (_isMonitoring) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Monitoring active',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the sensitivity configuration card.
  Widget _buildSensitivityCard(bool isWideScreen) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isWideScreen ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detection Sensitivity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(_sensitivity * 100).round()}%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              ),
              child: Slider(
                value: _sensitivity,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: _isMonitoring
                    ? null
                    : (value) {
                        setState(() => _sensitivity = value);
                      },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Low',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
                Text(
                  'High',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the start/stop monitoring control button.
  Widget _buildControlButton(bool isWideScreen) {
    return SizedBox(
      width: double.infinity,
      height: isWideScreen ? 64 : 56,
      child: ElevatedButton.icon(
        onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
        icon: Icon(
          _isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: isWideScreen ? 28 : 24,
        ),
        label: Text(
          _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
          style: TextStyle(
            fontSize: isWideScreen ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isMonitoring
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor:
              (_isMonitoring
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981))
                  .withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
