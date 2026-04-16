import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/planned_route.dart';
import '../providers/route_provider.dart';
import '../services/location_service.dart';
import '../di/service_locator.dart';
import '../utils/snackbar_helper.dart';

/// Экран планирования маршрутов прогулок
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = getIt<LocationService>();

  // Временные точки для нового маршрута
  final List<LatLng> _currentWaypoints = [];
  LatLng? _currentPosition;

  // Режим редактирования
  bool _isEditing = false;
  PlannedRoute? _editingRoute;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _currentPosition = LatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Ошибка получения позиции: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _currentWaypoints.add(point);
    });

    _showPointAddedSnackbar(point);
  }

  void _showPointAddedSnackbar(LatLng point) {
    final distance = _calculateDistance();
    final distanceText = distance > 0 ? ' • ${_formatDistance(distance)}' : '';

    showInfoSnackBar(
      context,
      'Точка ${_currentWaypoints.length}: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}$distanceText',
    );
  }

  double _calculateDistance() {
    if (_currentWaypoints.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < _currentWaypoints.length - 1; i++) {
      final d = const Distance();
      total += d(_currentWaypoints[i], _currentWaypoints[i + 1]);
    }
    return total;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} м';
    }
    return '${(meters / 1000).toStringAsFixed(2)} км';
  }

  String _estimateTime(double meters) {
    if (meters < 100) return '< 1 мин';
    final minutes = (meters / 83.3).round();
    if (minutes < 60) return '~$minutes мин';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '~$hours ч' : '~$hours ч $mins мин';
  }

  void _undoLastPoint() {
    if (_currentWaypoints.isNotEmpty) {
      setState(() {
        _currentWaypoints.removeLast();
      });
    }
  }

  void _clearRoute() {
    setState(() {
      _currentWaypoints.clear();
      _isEditing = false;
      _editingRoute = null;
    });
  }

  void _editRoute(PlannedRoute route) {
    setState(() {
      _currentWaypoints.clear();
      _currentWaypoints.addAll(route.waypoints);
      _isEditing = true;
      _editingRoute = route;
    });

    // Центрируем карту на маршруте
    if (route.waypoints.isNotEmpty) {
      _fitRouteOnMap(route.waypoints);
    }
  }

  void _fitRouteOnMap(List<LatLng> waypoints) {
    if (waypoints.isEmpty) return;

    if (waypoints.length == 1) {
      _mapController.move(waypoints.first, 15);
      return;
    }

    double minLat = waypoints.first.latitude;
    double maxLat = waypoints.first.latitude;
    double minLon = waypoints.first.longitude;
    double maxLon = waypoints.first.longitude;

    for (final point in waypoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    _mapController.move(center, 13);
  }

  Future<void> _saveRoute() async {
    if (_currentWaypoints.length < 2) {
      showErrorSnackBar(context, 'Маршрут должен содержать минимум 2 точки');
      return;
    }

    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;

    final routeProvider = context.read<RouteProvider>();

    if (_isEditing && _editingRoute != null) {
      // Обновляем существующий маршрут
      final updated = _editingRoute!.copyWith(
        name: name,
        waypoints: List.from(_currentWaypoints),
      );
      await routeProvider.updateRoute(updated);
      showSuccessSnackBar(context, 'Маршрут обновлён');
    } else {
      // Создаём новый маршрут
      final success = await routeProvider.createRouteFromWaypoints(
        name: name,
        waypoints: List.from(_currentWaypoints),
      );
      if (success) {
        showSuccessSnackBar(context, 'Маршрут сохранён');
      } else {
        showErrorSnackBar(context, routeProvider.error ?? 'Ошибка сохранения');
      }
    }

    _clearRoute();
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController(
      text: _editingRoute?.name ?? 'Маршрут ${DateTime.now().day}.${DateTime.now().month}',
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isEditing ? 'Переименовать маршрут' : 'Сохранить маршрут'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название маршрута',
            hintText: 'Например: Утренняя прогулка',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoute(PlannedRoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить маршрут?'),
        content: Text('Маршрут "${route.name}" будет удалён безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<RouteProvider>().deleteRoute(route.id);
      showSuccessSnackBar(context, 'Маршрут удалён');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Планирование маршрутов')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Редактирование: ${_editingRoute?.name}' : 'Планирование маршрутов'),
        actions: [
          if (_currentWaypoints.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoLastPoint,
              tooltip: 'Отменить последнюю точку',
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearRoute,
              tooltip: 'Очистить',
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Карта
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(55.7558, 37.6173),
              initialZoom: 14,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ru.kreagenium.progulkin',
                maxZoom: 19,
              ),
              // Текущий редактируемый маршрут
              if (_currentWaypoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _currentWaypoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // Маркеры текущих точек
              if (_currentWaypoints.isNotEmpty)
                MarkerLayer(
                  markers: _currentWaypoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final point = entry.value;
                    final isFirst = index == 0;
                    final isLast = index == _currentWaypoints.length - 1;

                    return Marker(
                      point: point,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _currentWaypoints.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isFirst
                                ? Colors.green
                                : isLast
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              // Текущая позиция
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Информационная панель
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _currentWaypoints.isEmpty
                    ? const Text('Нажмите на карту, чтобы добавить точки маршрута')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.route, size: 20, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('Точек: ${_currentWaypoints.length}'),
                              if (_currentWaypoints.length >= 2) ...[
                                const SizedBox(width: 16),
                                Icon(Icons.straighten, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(_formatDistance(_calculateDistance()),
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 16),
                                Icon(Icons.access_time, size: 20, color: Colors.orange[700]),
                                const SizedBox(width: 4),
                                Text(_estimateTime(_calculateDistance()),
                                    style: TextStyle(color: Colors.orange[700])),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Удерживайте маркер для удаления точки',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Кнопка сохранения
          if (_currentWaypoints.length >= 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _saveRoute,
                    icon: const Icon(Icons.save),
                    label: Text(_isEditing ? 'Обновить маршрут' : 'Сохранить маршрут'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // Список сохранённых маршрутов
      drawer: _buildRoutesDrawer(),
    );
  }

  Widget _buildRoutesDrawer() {
    return Drawer(
      child: Consumer<RouteProvider>(
        builder: (context, routeProvider, child) {
          final routes = routeProvider.routes;

          return Column(
            children: [
              AppBar(
                title: const Text('Мои маршруты'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.pop(context);
                      _clearRoute();
                    },
                    tooltip: 'Новый маршрут',
                  ),
                ],
              ),
              if (routeProvider.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (routes.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Нет сохранённых маршрутов.\n\nНажмите на карту, чтобы создать новый маршрут.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return _buildRouteTile(route, routeProvider);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRouteTile(PlannedRoute route, RouteProvider routeProvider) {
    final isSelected = routeProvider.selectedRoute?.id == route.id;

    return ListTile(
      leading: Icon(
        route.isFavorite ? Icons.star : Icons.route,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        route.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(
        '${route.formattedDistance} • ${route.formattedTime} • ${route.waypointCount} точек',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'edit':
              Navigator.pop(context);
              _editRoute(route);
              break;
            case 'delete':
              await _deleteRoute(route);
              break;
            case 'favorite':
              await routeProvider.toggleFavorite(route.id);
              break;
            case 'select':
              Navigator.pop(context);
              await routeProvider.selectRoute(route);
              showSuccessSnackBar(context, 'Маршрут "${route.name}" выбран для прогулки');
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'select', child: Text('Выбрать для прогулки')),
          const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
          PopupMenuItem(
            value: 'favorite',
            child: Text(route.isFavorite ? 'Убрать из избранного' : 'В избранное'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
      onTap: () {
        Navigator.pop(context);
        _editRoute(route);
      },
    );
  }
}
