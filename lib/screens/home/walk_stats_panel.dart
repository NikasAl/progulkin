import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/walk_provider.dart';
import '../../providers/pedometer_provider.dart';
import '../../widgets/stats_widget.dart';
import '../../utils/panel_decorations.dart';

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
        decoration: topPanelDecoration(context),
        child: Consumer2<WalkProvider, PedometerProvider>(
          builder: (context, walkProvider, pedometerProvider, child) {
            final walk = walkProvider.currentWalk;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatsWidget.inline(
                  icon: Icons.directions_walk,
                  value: '${pedometerProvider.steps}',
                  label: 'шагов',
                  iconColor: Colors.green,
                ),
                verticalDivider(height: 32),
                StatsWidget.inline(
                  icon: Icons.straighten,
                  value: pedometerProvider.formattedDistance,
                  label: 'пройдено',
                  iconColor: Colors.blue,
                ),
                verticalDivider(height: 32),
                StatsWidget.inline(
                  icon: Icons.timer_outlined,
                  value: walkProvider.hasCurrentWalk
                      ? walkProvider.currentWalkFormattedDuration
                      : '0:00',
                  label: 'время',
                  iconColor: Colors.orange,
                ),
                verticalDivider(height: 32),
                StatsWidget.inline(
                  icon: Icons.speed_outlined,
                  value: walk?.formattedRecentSpeed ?? '0 км/ч',
                  label: 'скорость',
                  iconColor: Colors.purple,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
