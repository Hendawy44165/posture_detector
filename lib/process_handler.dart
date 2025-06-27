import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Represents a posture detection result from the CLI
class PostureResult {
  final DateTime timestamp;
  final bool isLeaning;
  final String posture;
  final String type;

  PostureResult({
    required this.timestamp,
    required this.isLeaning,
    required this.posture,
    required this.type,
  });

  factory PostureResult.fromJson(Map<String, dynamic> json) {
    return PostureResult(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] * 1000).round(),
      ),
      isLeaning: json['is_leaning'] ?? false,
      posture: json['posture'] ?? 'unknown',
      type: json['type'] ?? 'posture',
    );
  }

  @override
  String toString() {
    return 'PostureResult(timestamp: $timestamp, posture: $posture, isLeaning: $isLeaning)';
  }
}

/// Represents an error message from the CLI
class PostureError {
  final DateTime timestamp;
  final String message;
  final String type;

  PostureError({
    required this.timestamp,
    required this.message,
    required this.type,
  });

  factory PostureError.fromJson(Map<String, dynamic> json) {
    return PostureError(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] * 1000).round(),
      ),
      message: json['message'] ?? 'Unknown error',
      type: json['type'] ?? 'error',
    );
  }

  @override
  String toString() {
    return 'PostureError(timestamp: $timestamp, message: $message)';
  }
}

/// Represents a status message from the CLI
class PostureStatus {
  final DateTime timestamp;
  final String message;
  final String type;

  PostureStatus({
    required this.timestamp,
    required this.message,
    required this.type,
  });

  factory PostureStatus.fromJson(Map<String, dynamic> json) {
    return PostureStatus(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] * 1000).round(),
      ),
      message: json['message'] ?? 'Unknown status',
      type: json['type'] ?? 'status',
    );
  }

  @override
  String toString() {
    return 'PostureStatus(timestamp: $timestamp, message: $message)';
  }
}

/// Configuration for the posture monitor client
class PostureMonitorConfig {
  final double interval;
  final int cameraIndex;
  final double sensitivity;
  final bool verbose;
  final String pythonExecutable;
  final String cliScriptPath;

  const PostureMonitorConfig({
    this.interval = 10.0,
    this.cameraIndex = 0,
    this.sensitivity = 0.4,
    this.verbose = false,
    this.pythonExecutable = 'python3',
    this.cliScriptPath = 'scripts/cli.py',
  });

  List<String> get arguments => [
    cliScriptPath,
    '--interval',
    interval.toString(),
    '--camera',
    cameraIndex.toString(),
    '--sensitivity',
    sensitivity.toString(),
    '--format',
    'json',
    if (verbose) '--verbose',
  ];
}

/// Client for communicating with the posture monitor CLI
class PostureMonitorClient {
  final PostureMonitorConfig config;
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  // Stream controllers for different message types
  final StreamController<PostureResult> _postureController =
      StreamController<PostureResult>.broadcast();
  final StreamController<PostureError> _errorController =
      StreamController<PostureError>.broadcast();
  final StreamController<PostureStatus> _statusController =
      StreamController<PostureStatus>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  PostureMonitorClient({required this.config});

  /// Stream of posture detection results
  Stream<PostureResult> get postureStream => _postureController.stream;

  /// Stream of error messages
  Stream<PostureError> get errorStream => _errorController.stream;

  /// Stream of status messages
  Stream<PostureStatus> get statusStream => _statusController.stream;

  /// Stream of raw log messages from stderr
  Stream<String> get logStream => _logController.stream;

  /// Whether the monitor is currently running
  bool get isRunning => _process != null;

  /// Start the posture monitor CLI process
  Future<void> start() async {
    if (_process != null) {
      throw StateError('Posture monitor is already running');
    }

    try {
      print('Starting posture monitor with config: ${config.arguments}');

      _process = await Process.start(
        config.pythonExecutable,
        config.arguments,
        mode: ProcessStartMode.normal,
      );

      print('Posture monitor process started with PID: ${_process!.pid}');

      // Listen to stdout for JSON data
      _stdoutSubscription = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleStdoutLine,
            onError: _handleStreamError,
            onDone: _handleStdoutDone,
          );

      // Listen to stderr for logs
      _stderrSubscription = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleStderrLine,
            onError: _handleStreamError,
            onDone: _handleStderrDone,
          );

      // Handle process exit
      _process!.exitCode.then(_handleProcessExit);
    } catch (e) {
      print('Failed to start posture monitor: $e');
      await _cleanup();
      rethrow;
    }
  }

  /// Stop the posture monitor CLI process
  Future<void> stop() async {
    if (_process == null) {
      return;
    }

    print('Stopping posture monitor...');

    try {
      // Send SIGTERM for graceful shutdown
      _process!.kill(ProcessSignal.sigterm);

      // Wait for process to exit, with timeout
      await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Process did not exit gracefully, sending SIGKILL');
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (e) {
      print('Error stopping process: $e');
    } finally {
      await _cleanup();
    }
  }

  /// Handle a line from stdout (JSON data)
  void _handleStdoutLine(String line) {
    if (line.trim().isEmpty) return;

    try {
      final Map<String, dynamic> json = jsonDecode(line);
      final String type = json['type'] ?? 'unknown';

      switch (type) {
        case 'posture':
          final result = PostureResult.fromJson(json);
          _postureController.add(result);
          break;
        case 'error':
          final error = PostureError.fromJson(json);
          _errorController.add(error);
          break;
        case 'status':
          final status = PostureStatus.fromJson(json);
          _statusController.add(status);
          break;
        default:
          print('Unknown message type: $type');
      }
    } catch (e) {
      print('Failed to parse JSON from stdout: $line');
      print('Parse error: $e');
    }
  }

  /// Handle a line from stderr (logs)
  void _handleStderrLine(String line) {
    if (line.trim().isNotEmpty) {
      _logController.add(line);
    }
  }

  /// Handle stdout stream errors
  void _handleStreamError(Object error) {
    print('Stream error: $error');
  }

  /// Handle stdout stream completion
  void _handleStdoutDone() {
    print('Stdout stream closed');
  }

  /// Handle stderr stream completion
  void _handleStderrDone() {
    print('Stderr stream closed');
  }

  /// Handle process exit
  void _handleProcessExit(int exitCode) {
    print('Posture monitor process exited with code: $exitCode');
    _cleanup();
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _process = null;
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    await stop();
    await _postureController.close();
    await _errorController.close();
    await _statusController.close();
    await _logController.close();
  }
}

/// Example usage and testing
