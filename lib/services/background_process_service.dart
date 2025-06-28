import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:posture_detector/models/posture_models.dart';

//TODO: make the error message more verbose, and handle them

class PostureMonitorClient {
  final PostureMonitorConfig config;
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  final _postureController = StreamController<PostureResult>.broadcast();
  final _errorController = StreamController<PostureError>.broadcast();
  final _statusController = StreamController<PostureStatus>.broadcast();
  final _logController = StreamController<String>.broadcast();

  PostureMonitorClient({required this.config});

  Stream<PostureResult> get postureStream => _postureController.stream;

  Stream<PostureError> get errorStream => _errorController.stream;

  Stream<PostureStatus> get statusStream => _statusController.stream;

  Stream<String> get logStream => _logController.stream;

  bool get isRunning => _process != null;

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

      _stdoutSubscription = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleStdoutLine,
            onError: _handleStreamError,
            onDone: _handleStdoutDone,
          );

      _stderrSubscription = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleStderrLine,
            onError: _handleStreamError,
            onDone: _handleStderrDone,
          );

      _process!.exitCode.then(_handleProcessExit);
    } catch (e) {
      print('Failed to start posture monitor: $e');
      await _cleanup();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_process == null) {
      return;
    }

    print('Stopping posture monitor...');

    try {
      _process!.kill(ProcessSignal.sigterm);

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

  void _handleStderrLine(String line) {
    if (line.trim().isNotEmpty) {
      _logController.add(line);
    }
  }

  void _handleStreamError(Object error) {
    print('Stream error: $error');
  }

  void _handleStdoutDone() {
    print('Stdout stream closed');
  }

  void _handleStderrDone() {
    print('Stderr stream closed');
  }

  void _handleProcessExit(int exitCode) {
    print('Posture monitor process exited with code: $exitCode');
    _cleanup();
  }

  Future<void> _cleanup() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _process = null;
  }

  Future<void> dispose() async {
    await stop();
    await _postureController.close();
    await _errorController.close();
    await _statusController.close();
    await _logController.close();
  }
}
