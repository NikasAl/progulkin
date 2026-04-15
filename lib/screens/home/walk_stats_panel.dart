import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/walk_provider.dart';
import '../../providers/pedometer_provider.dart';

/// Верхняя панель со статистикой прогулки
/// Отображает шаги, расстояние, время и скорость
class WalkStatsPanel extends StatelessWidget {
  const WalkStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Consumer2<WalkProvider, PedometerProvider>(
          builder: (context, walkProvider, pedometerProvider, child) {
            final walk = walkProvider.currentWalk;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  context: context,
                  icon: Icons.directions_walk,
                  value: '${pedometerProvider.steps}',
                  label: 'шагов',
                  color: Colors.green,
                ),
                _buildVerticalDivider(context, height: 32),
                _buildStatItem(
                  context: context,
                  icon: Icons.straighten,
                  value: pedometerProvider.formattedDistance,
                  label: 'пройдено',
                  color: Colors.blue,
                ),
                _buildVerticalDivider(context, height: 32),
                _buildStatItem(
                  context: context,
                  icon: Icons.timer_outlined,
                  value: walkProvider.hasCurrentWalk
                      ? walkProvider.currentWalkFormattedDuration
                      : '0:00',
                  label: 'время',
                  color: Colors.orange,
                ),
                _buildVerticalDivider(context, height: 32),
                _buildStatItem(
                  context: context,
                  icon: Icons.speed_outlined,
                  value: walk?.formattedRecentSpeed ?? '0 км/ч',
                  label: 'скорость',
                  color: Colors.purple,
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
    required String value,
    required String label,
    Color? color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(BuildContext context, {double height = 40}) {
    return Container(
      height: height,
      width: 1,
      color: Colors.grey[300],
    );
  }
}
