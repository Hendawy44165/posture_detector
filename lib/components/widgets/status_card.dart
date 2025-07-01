import 'package:flutter/material.dart';
import '../enums/posture_state.dart' show PostureState, PostureStateExtension;

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.postureState,
    required this.isMonitoring,
    this.isWideScreen = true,
  });

  final PostureState postureState;
  final bool isMonitoring;
  final bool isWideScreen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isWideScreen ? 32 : 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMonitoring
                    ? postureState.color.withValues(alpha: 0.1)
                    : Theme.of(context).disabledColor.withValues(alpha: 0.1),
              ),
              child: Icon(
                isMonitoring
                    ? postureState.icon
                    : Icons.power_settings_new_rounded,
                size: isWideScreen ? 48 : 36,
                color: isMonitoring
                    ? postureState.color
                    : Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isMonitoring ? postureState.label : 'Off',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isMonitoring
                    ? postureState.color
                    : Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
