import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:posture_detector/models/posture_models.dart';

class PostureMonitorClient {
  final PostureMonitorConfig config;
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  final _postureController = StreamController<PostureResult>.broadcast();
  final _errorController = StreamController<PostureError>.broadcast();
  final _logController = StreamController<String>.broadcast();

  PostureMonitorClient({required this.config});

  Stream<PostureResult> get postureStream => _postureController.stream;

  Stream<PostureError> get errorStream => _errorController.stream;

  Stream<String> get logStream => _logController.stream;

  bool get isRunning => _process != null;

  Future<void> start() async {
    if (_process != null) {
      throw StateError('Posture monitor is already running');
    }

    try {
      _process = await Process.start(
        config.pythonExecutable,
        config.arguments,
        mode: ProcessStartMode.normal,
      );

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
      await _cleanup();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_process == null) {
      return;
    }

    try {
      _process!.kill(ProcessSignal.sigterm);

      await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (e) {
      _errorController.add(
        PostureError(
          timestamp: DateTime.now(),
          code: 500,
          type: 'unknown',
          message: 'Error stopping process: $e',
        ),
      );
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

        default:
          break;
      }
    } catch (e) {
      _errorController.add(
        PostureError(
          timestamp: DateTime.now(),
          code: 500,
          type: 'unknown',

          message: e.toString(),
        ),
      );
    }
  }

  void _handleStderrLine(String line) {
    if (line.trim().isNotEmpty) {
      _logController.add(line);
    }
  }

  void _handleStreamError(Object error) {
    _errorController.add(
      PostureError(
        timestamp: DateTime.now(),
        code: 500,
        type: 'unknown',
        message: error.toString(),
      ),
    );
  }

  void _handleStdoutDone() {
    _errorController.add(
      PostureError(
        timestamp: DateTime.now(),
        code: 500,
        type: 'unknown',
        message: 'Stdout stream closed',
      ),
    );
  }

  void _handleStderrDone() {
    _errorController.add(
      PostureError(
        timestamp: DateTime.now(),
        code: 500,
        type: 'unknown',
        message: 'Stderr stream closed',
      ),
    );
  }

  void _handleProcessExit(int exitCode) {
    _errorController.add(
      PostureError(
        timestamp: DateTime.now(),
        code: 500,
        type: 'unknown',
        message: 'Posture monitor process exited with code: $exitCode',
      ),
    );
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
    await _logController.close();
  }
}
