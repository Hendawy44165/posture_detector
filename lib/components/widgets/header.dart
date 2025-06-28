import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  const Header({super.key, this.isWideScreen = true});

  final bool isWideScreen;

  @override
  Widget build(BuildContext context) {
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
}
