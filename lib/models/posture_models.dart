class PostureResult {
  final DateTime timestamp;
  final bool isLeaning;
  final String posture;
  final String type;
  final int code;

  PostureResult({
    required this.timestamp,
    required this.isLeaning,
    required this.posture,
    required this.type,
    required this.code,
  });

  factory PostureResult.fromJson(Map<String, dynamic> json) {
    return PostureResult(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] * 1000).round(),
      ),
      isLeaning: json['is_leaning'] ?? false,
      posture: json['posture'] ?? 'unknown',
      type: json['type'] ?? 'posture',
      code: json['code'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'PostureResult(timestamp: $timestamp, posture: $posture, isLeaning: $isLeaning, code: $code)';
  }
}

class PostureError {
  final DateTime timestamp;
  final String message;
  final String type;
  final int code;

  PostureError({
    required this.timestamp,
    required this.message,
    required this.type,
    required this.code,
  });

  factory PostureError.fromJson(Map<String, dynamic> json) {
    return PostureError(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] * 1000).round(),
      ),
      message: json['message'] ?? 'Unknown error',
      type: json['type'] ?? 'error',
      code: json['code'] ?? 1,
    );
  }

  @override
  String toString() {
    return 'PostureError(timestamp: $timestamp, message: $message, code: $code)';
  }
}

class PostureStatus {
  final DateTime timestamp;
  final String message;
  final String type;
  final int code;

  PostureStatus({
    required this.timestamp,
    required this.message,
    required this.type,
    required this.code,
  });

  factory PostureStatus.fromJson(Map<String, dynamic> json) {
    return PostureStatus(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] * 1000).round(),
      ),
      message: json['message'] ?? 'Unknown status',
      type: json['type'] ?? 'status',
      code: json['code'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'PostureStatus(timestamp: $timestamp, message: $message, code: $code)';
  }
}

class PostureMonitorConfig {
  final double interval;
  final int cameraIndex;
  final double sensitivity;
  final String pythonExecutable;
  final String cliScriptPath;

  const PostureMonitorConfig({
    this.interval = 1.0,
    this.cameraIndex = 0,
    this.sensitivity = 0.4,
    this.pythonExecutable =
        '/usr/share/posture_detector/scripts/venv/bin/python',
    this.cliScriptPath = '/usr/share/posture_detector/scripts/cli.py',
  });

  List<String> get arguments => [
    cliScriptPath,
    '--interval',
    interval.toString(),
    '--camera',
    cameraIndex.toString(),
    '--sensitivity',
    sensitivity.toString(),
  ];
}
