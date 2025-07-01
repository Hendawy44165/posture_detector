enum ErrorCategory { user, system }

extension ErrorMessageExtension on String {
  String get userFriendly {
    final clue = toLowerCase();
    if (clue.contains('posture')) return 'No person detected.';
    if (clue.contains('camera')) return 'Camera hardware error.';
    if (clue.contains('monitor')) return 'Camera subscription error.';
    return 'An error has occurred in the detection process.';
  }
}
