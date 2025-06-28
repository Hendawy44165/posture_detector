import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowControls extends StatelessWidget {
  const WindowControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withAlpha(200),
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(25), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildMacWindowDot(
            color: const Color(0xFFFF5F57), // Red
            tooltip: 'Close',
            onPressed: () async => await windowManager.close(),
          ),
          const SizedBox(width: 8),
          _buildMacWindowDot(
            color: const Color(0xFFFFBD2E), // Yellow
            tooltip: 'Minimize',
            onPressed: () async => await windowManager.minimize(),
          ),
          const SizedBox(width: 8),
          _buildMacWindowDot(
            color: const Color(0xFF28C840), // Green
            tooltip: 'Maximize (Disabled)',
            onPressed: null, // Disabled
          ),
        ],
      ),
    );
  }

  Widget _buildMacWindowDot({
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withAlpha(onPressed != null ? 255 : 77),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
