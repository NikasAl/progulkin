import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/walk.dart';
import '../services/tile_cache_service.dart';

/// Экран деталей прогулки
class WalkDetailScreen extends StatefulWidget {
  final Walk walk;

  const WalkDetailScreen({super.key, required this.walk});

  @override
  State<WalkDetailScreen> createState() => _WalkDetailScreenState();
}

class _WalkDetailScreenState extends State<WalkDetailScreen> {
  final MapController _mapController = MapController();
  final TileCacheService _tileCacheService = TileCacheService();
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _initRoutePoints();
    _initTileCache();
  }

  void _initRoutePoints() {
    _routePoints = widget.walk.points.map((p) => 
      LatLng(p.latitude, p.longitude)
    ).toList();
  }

  Future<void> _initTileCache() async {
    try {
      // Инициализируем кэш тайлов (singleton, безопасно вызывать многократно)
      await _tileCacheService.init();
    } catch (e) {
      debugPrint('TileCache init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'ru_RU');
    final timeFormat = DateFormat('HH:mm', 'ru_RU');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar с картой
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.walk.points.isNotEmpty
                  ? FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _routePoints.isNotEmpty 
                            ? _routePoints.first 
                            : LatLng(55.7558, 37.6173),
                        initialZoom: 14,
                        onMapReady: _fitRouteOnMap,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.progulkin',
                          maxZoom: 19,
                          // Используем кэшированные тайлы если доступны
                          tileProvider: _tileCacheService.isInitialized 
                              ? _tileCacheService.getTileProvider()
                              : null,
                        ),
                        if (_routePoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                color: const Color(0xFF2E7D32), // Тёмно-зелёный, виден на любой карте
                                strokeWidth: 4,
                              ),
                            ],
                          ),
                        // Маркер начала
                        if (_routePoints.isNotEmpty)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _routePoints.first,
                                width: 30,
                                height: 30,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              Marker(
                                point: _routePoints.last,
                                width: 30,
                                height: 30,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.flag,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.map_outlined, size: 60, color: Colors.grey),
                      ),
                    ),
            ),
          ),

          // Контент
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Дата и время
                  Text(
                    dateFormat.format(widget.walk.startTime),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeFormat.format(widget.walk.startTime)} - ${widget.walk.endTime != null ? timeFormat.format(widget.walk.endTime!) : 'в процессе'}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Основная статистика
                  _buildMainStats(context),
                  const SizedBox(height: 24),

                  // Статистика по объектам карты
                  if (widget.walk.objectStats.totalActions > 0) ...[
                    _buildObjectStats(context),
                    const SizedBox(height: 24),
                  ],

                  // Детальная статистика
                  _buildDetailedStats(context),
                  const SizedBox(height: 24),

                  // График скорости (placeholder)
                  _buildSpeedChart(context),
                  const SizedBox(height: 24),

                  // Заметки
                  if (widget.walk.notes != null && widget.walk.notes!.isNotEmpty) ...[
                    Text(
                      'Заметки',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(widget.walk.notes!),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Точки маршрута
                  _buildPointsInfo(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Основная статистика
  Widget _buildMainStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.route,
            iconColor: Colors.blue,
            value: widget.walk.formattedDistance,
            label: 'Расстояние',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.directions_walk,
            iconColor: Colors.green,
            value: '${widget.walk.steps}',
            label: 'Шагов',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.timer,
            iconColor: Colors.orange,
            value: widget.walk.formattedDuration,
            label: 'Время',
          ),
        ),
      ],
    );
  }

  /// Карточка статистики
  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Статистика по объектам карты
  Widget _buildObjectStats(BuildContext context) {
    final stats = widget.walk.objectStats;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Активность на карте',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Сетка с действиями
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (stats.objectsAdded > 0)
                _buildActionChip(
                  context,
                  icon: Icons.add_location,
                  label: 'Добавлено: ${stats.objectsAdded}',
                  color: Colors.blue,
                ),
              if (stats.objectsConfirmed > 0)
                _buildActionChip(
                  context,
                  icon: Icons.thumb_up,
                  label: 'Подтверждено: ${stats.objectsConfirmed}',
                  color: Colors.green,
                ),
              if (stats.objectsCleaned > 0)
                _buildActionChip(
                  context,
                  icon: Icons.cleaning_services,
                  label: 'Убрано: ${stats.objectsCleaned}',
                  color: Colors.teal,
                ),
              if (stats.creaturesCaught > 0)
                _buildActionChip(
                  context,
                  icon: Icons.pets,
                  label: 'Поймано: ${stats.creaturesCaught}',
                  color: Colors.purple,
                ),
              if (stats.secretsRead > 0)
                _buildActionChip(
                  context,
                  icon: Icons.lock_open,
                  label: 'Прочитано: ${stats.secretsRead}',
                  color: Colors.amber,
                ),
            ],
          ),
          
          // Очки
          if (stats.pointsEarned > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '+${stats.pointsEarned} очков',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Chip для действия
  Widget _buildActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Детальная статистика
  Widget _buildDetailedStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Детали',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            context,
            label: 'Средняя скорость',
            value: widget.walk.formattedSpeed,
          ),
          _buildDetailRow(
            context,
            label: 'Точек маршрута',
            value: '${widget.walk.points.length}',
          ),
          if (widget.walk.points.isNotEmpty) ...[
            _buildDetailRow(
              context,
              label: 'Начальная высота',
              value: '${widget.walk.points.first.altitude.toStringAsFixed(1)} м',
            ),
            _buildDetailRow(
              context,
              label: 'Конечная высота',
              value: '${widget.walk.points.last.altitude.toStringAsFixed(1)} м',
            ),
          ],
          _buildDetailRow(
            context,
            label: 'Ср. длина шага',
            value: widget.walk.steps > 0 
                ? '${(widget.walk.totalDistance / widget.walk.steps).toStringAsFixed(2)} м'
                : '-',
          ),
        ],
      ),
    );
  }

  /// Строка детальной информации
  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// График скорости (placeholder)
  Widget _buildSpeedChart(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Скорость по маршруту',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: _SpeedChartPainter(
                points: widget.walk.points,
                color: Theme.of(context).colorScheme.primary,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  /// Информация о точках
  Widget _buildPointsInfo(BuildContext context) {
    if (widget.walk.points.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Начало: ${widget.walk.points.first.latitude.toStringAsFixed(6)}, ${widget.walk.points.first.longitude.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Конец: ${widget.walk.points.last.latitude.toStringAsFixed(6)}, ${widget.walk.points.last.longitude.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Разместить маршрут на карте
  void _fitRouteOnMap() {
    if (_routePoints.isEmpty) return;

    if (_routePoints.length < 2) {
      _mapController.move(_routePoints.first, 15);
      return;
    }

    // Вычисляем центр и зум
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLon = _routePoints.first.longitude;
    double maxLon = _routePoints.first.longitude;

    for (final point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    _mapController.move(center, 13);
  }
}

/// Отрисовщик графика скорости
class _SpeedChartPainter extends CustomPainter {
  final List<dynamic> points;
  final Color color;

  _SpeedChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      // Рисуем плоскую линию если нет данных
      final paint = Paint()
        ..color = Colors.grey[300]!
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    final walkPoints = points;
    
    // Находим максимальную скорость
    double maxSpeed = 0;
    for (final p in walkPoints) {
      final speed = (p as dynamic).speed as double;
      if (speed > maxSpeed) maxSpeed = speed;
    }
    if (maxSpeed == 0) maxSpeed = 1;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = ui.Path();
    final stepX = size.width / (walkPoints.length - 1);

    for (int i = 0; i < walkPoints.length; i++) {
      final speed = (walkPoints[i] as dynamic).speed as double;
      final x = i * stepX;
      final y = size.height - (speed / maxSpeed * size.height * 0.8) - size.height * 0.1;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Заливка под графиком
    final fillPath = ui.Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
