import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/walk_provider.dart';
import '../providers/pedometer_provider.dart';
import '../models/walk_point.dart';
import 'history_screen.dart';
import 'walk_detail_screen.dart';
import 'settings_screen.dart';

/// Главный экран с картой OpenStreetMap
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _routePoints = [];
  bool _initialized = false;
  LatLng _currentPosition = LatLng(55.7558, 37.6173); // Москва по умолчанию
  double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProviders();
    });
  }

  Future<void> _initProviders() async {
    if (_initialized) return;
    _initialized = true;
    
    final walkProvider = context.read<WalkProvider>();
    final pedometerProvider = context.read<PedometerProvider>();
    
    await walkProvider.init();
    await pedometerProvider.init();
    
    // Если есть текущая прогулка, загружаем маршрут
    if (walkProvider.currentWalk?.points.isNotEmpty ?? false) {
      _loadRouteFromWalk(walkProvider.currentWalk!.points);
    }
  }

  void _loadRouteFromWalk(List<WalkPoint> points) {
    _routePoints.clear();
    for (final point in points) {
      _routePoints.add(LatLng(point.latitude, point.longitude));
    }
    if (_routePoints.isNotEmpty) {
      _currentPosition = _routePoints.last;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // OpenStreetMap карта
          _buildMap(),
          
          // Верхняя панель со статистикой
          _buildTopPanel(),
          
          // Панель шагов
          _buildStepsPanel(),
          
          // Нижняя панель управления
          _buildBottomControls(),
        ],
      ),
    );
  }

  /// Карта OpenStreetMap
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition,
        initialZoom: _currentZoom,
        onMapReady: () {
          // Карта готова
        },
      ),
      children: [
        // Слой тайлов OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.progulkin',
          maxZoom: 19,
        ),
        // Слой маршрута
        PolylineLayer(
          polylines: [
            Polyline(
              points: _routePoints,
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 5,
            ),
          ],
        ),
        // Маркер текущей позиции
        MarkerLayer(
          markers: _routePoints.isEmpty ? [] : [
            Marker(
              point: _routePoints.last,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.directions_walk,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Верхняя панель со статистикой
  Widget _buildTopPanel() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
                  icon: Icons.route_outlined,
                  label: 'Расстояние',
                  value: walk?.formattedDistance ?? '0 м',
                ),
                _buildVerticalDivider(),
                _buildStatItem(
                  icon: Icons.timer_outlined,
                  label: 'Время',
                  value: walk?.formattedDuration ?? '0 сек',
                ),
                _buildVerticalDivider(),
                _buildStatItem(
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

  /// Элемент статистики
  Widget _buildStatItem({
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

  /// Вертикальный разделитель
  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }

  /// Панель шагов
  Widget _buildStepsPanel() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 250,
      child: Consumer<PedometerProvider>(
        builder: (context, pedometerProvider, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_walk,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pedometerProvider.steps}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        'шагов • ${pedometerProvider.formattedDistance}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Нижняя панель управления
  Widget _buildBottomControls() {
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.history,
                        label: 'История',
                        onTap: () => _openHistory(context),
                      ),
                      _buildActionButton(
                        icon: Icons.settings,
                        label: 'Настройки',
                        onTap: () => _openSettings(context),
                      ),
                      _buildActionButton(
                        icon: Icons.my_location,
                        label: 'Место',
                        onTap: _moveToCurrentLocation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMainButton(walkProvider, pedometerProvider),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Кнопка действия
  Widget _buildActionButton({
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

  /// Главная кнопка
  Widget _buildMainButton(
    WalkProvider walkProvider,
    PedometerProvider pedometerProvider,
  ) {
    final isTracking = walkProvider.isTracking;

    if (isTracking) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (walkProvider.isTracking) {
                  walkProvider.pauseWalk();
                  pedometerProvider.stopCounting();
                } else {
                  walkProvider.resumeWalk();
                  pedometerProvider.startCounting();
                }
              },
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
              onPressed: () => _stopWalk(walkProvider, pedometerProvider),
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
        onPressed: () => _startWalk(walkProvider, pedometerProvider),
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

  /// Начать прогулку
  Future<void> _startWalk(
    WalkProvider walkProvider,
    PedometerProvider pedometerProvider,
  ) async {
    final success = await walkProvider.startWalk();
    if (success) {
      await pedometerProvider.startCounting();
      
      final walk = walkProvider.currentWalk;
      if (walk?.points.isNotEmpty ?? false) {
        final point = walk!.points.first;
        _moveToPosition(point.latitude, point.longitude);
      }
    } else {
      _showError(walkProvider.error ?? 'Не удалось начать прогулку');
    }
  }

  /// Остановить прогулку
  Future<void> _stopWalk(
    WalkProvider walkProvider,
    PedometerProvider pedometerProvider,
  ) async {
    final steps = pedometerProvider.getCurrentSteps();
    final success = await walkProvider.stopWalk(steps: steps);
    
    if (success) {
      pedometerProvider.stopCounting();
      pedometerProvider.reset();
      _clearMapRoute();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Прогулка сохранена! $steps шагов'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Открыть',
              textColor: Colors.white,
              onPressed: () {
                if (walkProvider.walksHistory.isNotEmpty) {
                  _openWalkDetail(context, walkProvider.walksHistory.first);
                }
              },
            ),
          ),
        );
      }
    } else {
      _showError(walkProvider.error ?? 'Не удалось сохранить прогулку');
    }
  }

  /// Переместить карту на позицию
  void _moveToPosition(double lat, double lon) {
    final position = LatLng(lat, lon);
    _mapController.move(position, _mapController.camera.zoom);
  }

  /// Переместить на текущую позицию
  void _moveToCurrentLocation() {
    final walkProvider = context.read<WalkProvider>();
    final walk = walkProvider.currentWalk;
    
    if (walk?.points.isNotEmpty ?? false) {
      final point = walk!.points.last;
      _moveToPosition(point.latitude, point.longitude);
    }
  }

  /// Обновить маршрут на карте
  void _updateMapRoute(List<WalkPoint> points) {
    _routePoints.clear();
    for (final point in points) {
      _routePoints.add(LatLng(point.latitude, point.longitude));
    }
    setState(() {});
  }

  /// Очистить маршрут на карте
  void _clearMapRoute() {
    _routePoints.clear();
    setState(() {});
  }

  /// Открыть историю
  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  /// Открыть настройки
  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    );
  }

  /// Открыть детали прогулки
  void _openWalkDetail(BuildContext context, walk) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkDetailScreen(walk: walk),
      ),
    );
  }

  /// Показать ошибку
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
