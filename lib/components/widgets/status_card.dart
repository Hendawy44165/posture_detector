import 'package:flutter/material.dart';
import '../enums/posture_state.dart' show PostureState, PostureStateExtension;

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.postureState,
    required this.isMonitoring,
    required this.pulseAnimation,
    this.isWideScreen = true,
  });

  final PostureState postureState;
  final bool isMonitoring;
  final Animation<double> pulseAnimation;
  final bool isWideScreen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: postureState == PostureState.notResolved && isMonitoring
              ? pulseAnimation.value
              : 1.0,
          child: Card(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(isWideScreen ? 32 : 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: postureState.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: postureState.color, width: 3),
                    ),
                    child: Icon(
                      postureState.icon,
                      size: isWideScreen ? 64 : 48,
                      color: postureState.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    postureState.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: postureState.color,
                    ),
                  ),
                  if (isMonitoring) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Monitoring active',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
