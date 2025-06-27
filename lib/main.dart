// ignore_for_file: avoid_print

import 'package:posture_detector/process_handler.dart';

Future<void> main() async {
  final config = PostureMonitorConfig(
    interval: 2.0,
    sensitivity: 0.4,
    verbose: false,
  );

  final client = PostureMonitorClient(config: config);

  client.postureStream.listen((result) {
    print(result.isLeaning ? 'leaning' : 'not leaning');
  });

  try {
    await client.start();
    // Keep running until manually stopped
    await Future.delayed(const Duration(seconds: 30));
  } finally {
    await client.stop();
    await client.dispose();
  }
}
