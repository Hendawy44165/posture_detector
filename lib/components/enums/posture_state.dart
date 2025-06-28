import 'package:flutter/material.dart';

enum PostureState { upright, leaning, notResolved }

extension PostureStateExtension on PostureState {
  Color get color {
    switch (this) {
      case PostureState.upright:
        return const Color(0xFF10B981); // Green
      case PostureState.leaning:
        return const Color(0xFFEF4444); // Red
      case PostureState.notResolved:
        return const Color(0xFFF59E0B); // Amber
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
