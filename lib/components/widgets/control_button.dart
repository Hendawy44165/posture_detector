import 'package:flutter/material.dart';

/// A button widget for starting or stopping posture monitoring.
///
/// Displays a play or stop icon and label depending on monitoring state.
class ControlButton extends StatelessWidget {
  /// Creates a [ControlButton].
  ///
  /// Args:
  ///   - isMonitoring: [bool] whether monitoring is active.
  ///   - onStartPressed: [VoidCallback] called when start is pressed.
  ///   - onStopPressed: [VoidCallback] called when stop is pressed.
  ///   - isWideScreen: [bool] adjusts layout for wide screens.
  const ControlButton({
    super.key,
    required this.isMonitoring,
    required this.onStartPressed,
    required this.onStopPressed,
    this.isWideScreen = true,
  });

  final bool isMonitoring;
  final VoidCallback onStartPressed;
  final VoidCallback onStopPressed;
  final bool isWideScreen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: isWideScreen ? 64 : 56,
      child: ElevatedButton.icon(
        onPressed: isMonitoring ? onStopPressed : onStartPressed,
        icon: Icon(
          isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: isWideScreen ? 28 : 24,
        ),
        label: Text(
          isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
          style: TextStyle(
            fontSize: isWideScreen ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isMonitoring
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor:
              (isMonitoring ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                  .withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
