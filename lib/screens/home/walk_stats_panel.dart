import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/walk_provider.dart';
import '../../providers/pedometer_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/planned_route.dart';
import '../../widgets/stats_widget.dart';
import '../../utils/panel_decorations.dart';

/// Верхняя панель со статистикой прогулки и выбранным маршрутом
/// Отображает шаги, расстояние, время, скорость и информацию о маршруте
class WalkStatsPanel extends StatelessWidget {
  const WalkStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<WalkProvider, PedometerProvider, RouteProvider>(
      builder: (context, walkProvider, pedometerProvider, routeProvider, child) {
        final route = routeProvider.selectedRoute;

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: topPanelDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Информация о маршруте (если выбран)
                if (route != null) _buildRouteInfo(context, route, routeProvider),
                // Разделитель если есть маршрут
                if (route != null)
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.3)),
                // Статистика прогулки
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: _buildStats(walkProvider, pedometerProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteInfo(BuildContext context, PlannedRoute route, RouteProvider routeProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Color(route.colorValue),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.route,
                      size: 16,
                      color: Color(route.colorValue),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${route.formattedDistance} • ${route.formattedTime} • ${route.waypointCount} точек',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => routeProvider.clearSelectedRoute(),
            tooltip: 'Отключить маршрут',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(WalkProvider walkProvider, PedometerProvider pedometerProvider) {
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
  }
}
