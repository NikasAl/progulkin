import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/walk_provider.dart';

/// Верхняя панель со статистикой прогулки
class WalkStatsPanel extends StatelessWidget {
  const WalkStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Consumer<WalkProvider>(
          builder: (context, walkProvider, child) {
            final walk = walkProvider.currentWalk;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context: context,
                  icon: Icons.route_outlined,
                  label: 'Расстояние',
                  value: walk?.formattedDistance ?? '0 м',
                ),
                _buildVerticalDivider(context),
                _buildStatItem(
                  context: context,
                  icon: Icons.timer_outlined,
                  label: 'Время',
                  value: walkProvider.hasCurrentWalk
                      ? walkProvider.currentWalkFormattedDuration
                      : '0 сек',
                ),
                _buildVerticalDivider(context),
                _buildStatItem(
                  context: context,
                  icon: Icons.speed_outlined,
                  label: 'Скорость',
                  value: walk?.formattedSpeed ?? '0 км/ч',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }
}
