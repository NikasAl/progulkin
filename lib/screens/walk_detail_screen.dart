import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/walk.dart';

/// Экран деталей прогулки
class WalkDetailScreen extends StatefulWidget {
  final Walk walk;

  const WalkDetailScreen({super.key, required this.walk});

  @override
  State<WalkDetailScreen> createState() => _WalkDetailScreenState();
}

class _WalkDetailScreenState extends State<WalkDetailScreen> {
  YandexMapController? _mapController;
  final List<MapObject> _mapObjects = [];

  @override
  void initState() {
    super.initState();
    _initMapObjects();
  }

  void _initMapObjects() {
    if (widget.walk.points.length < 2) return;

    final polylinePoints = widget.walk.points.map((p) => 
      Point(latitude: p.latitude, longitude: p.longitude)
    ).toList();

    _mapObjects.add(
      PolylineMapObject(
        mapId: const MapObjectId('walk_route'),
        polyline: Polyline(points: polylinePoints),
        strokeColor: Theme.of(context).colorScheme.primary,
        strokeWidth: 4,
      ),
    );
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
                  ? YandexMap(
                      mapObjects: _mapObjects,
                      apiKey: AppConfig.yandexMapApiKey,
                      onMapCreated: (controller) async {
                        _mapController = controller;
                        await _fitRouteOnMap();
                      },
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
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.directions_walk,
            iconColor: Colors.green,
            value: '${widget.walk.steps}',
            label: 'Шагов',
          ),
        ),
        const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                decoration: BoxDecoration(
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
                decoration: BoxDecoration(
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
  Future<void> _fitRouteOnMap() async {
    if (_mapController == null || widget.walk.points.isEmpty) return;

    final points = widget.walk.points.map((p) => 
      Point(latitude: p.latitude, longitude: p.longitude)
    ).toList();

    if (points.length < 2) {
      await _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 15),
        ),
      );
      return;
    }

    // Вычисляем границы
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final southWest = Point(latitude: minLat, longitude: minLon);
    final northEast = Point(latitude: maxLat, longitude: maxLon);

    await _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2,
          ),
          zoom: 12,
        ),
      ),
      animation: const MapAnimation(type: MapAnimationType.smooth),
    );
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

    final walkPoints = points as List<dynamic>;
    
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

    final path = Path();
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
    final fillPath = Path.from(path);
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
