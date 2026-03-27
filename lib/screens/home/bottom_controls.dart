import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/walk_provider.dart';
import '../../providers/pedometer_provider.dart';

/// Нижняя панель управления прогулкой
class BottomControls extends StatelessWidget {
  final VoidCallback onHistoryTap;
  final VoidCallback onMapCacheTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onMyLocationTap;
  final VoidCallback onStartWalk;
  final void Function(int steps) onStopWalk;
  final VoidCallback onPauseWalk;
  final VoidCallback onResumeWalk;

  const BottomControls({
    super.key,
    required this.onHistoryTap,
    required this.onMapCacheTap,
    required this.onSettingsTap,
    required this.onMyLocationTap,
    required this.onStartWalk,
    required this.onStopWalk,
    required this.onPauseWalk,
    required this.onResumeWalk,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Consumer2<WalkProvider, PedometerProvider>(
            builder: (context, walkProvider, pedometerProvider, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButtons(context),
                  const SizedBox(height: 16),
                  _buildMainButton(context, walkProvider, pedometerProvider),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context: context,
          icon: Icons.history,
          label: 'История',
          onTap: onHistoryTap,
        ),
        _buildActionButton(
          context: context,
          icon: Icons.map,
          label: 'Кэш карт',
          onTap: onMapCacheTap,
        ),
        _buildActionButton(
          context: context,
          icon: Icons.settings,
          label: 'Настройки',
          onTap: onSettingsTap,
        ),
        _buildActionButton(
          context: context,
          icon: Icons.my_location,
          label: 'Место',
          onTap: onMyLocationTap,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context,
    WalkProvider walkProvider,
    PedometerProvider pedometerProvider,
  ) {
    final hasWalk = walkProvider.hasCurrentWalk;

    if (hasWalk) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: walkProvider.isTracking ? onPauseWalk : onResumeWalk,
              icon: Icon(
                walkProvider.isTracking ? Icons.pause : Icons.play_arrow,
              ),
              label: Text(walkProvider.isTracking ? 'Пауза' : 'Продолжить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => onStopWalk(pedometerProvider.getCurrentSteps()),
              icon: const Icon(Icons.stop),
              label: const Text('Завершить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onStartWalk,
        icon: const Icon(Icons.play_arrow, size: 28),
        label: const Text(
          'Начать прогулку',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
