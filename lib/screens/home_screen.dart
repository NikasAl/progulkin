import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/walk_provider.dart';
import '../providers/pedometer_provider.dart';
import '../providers/map_object_provider.dart';
import '../providers/creature_provider.dart';
import '../providers/moderation_provider.dart';
import '../providers/interest_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/route_provider.dart';
import '../models/walk_point.dart';
import '../models/map_objects/map_objects.dart';
import '../models/planned_route.dart';
import '../services/location_service.dart';
import '../services/user_id_service.dart';
import '../services/tile_cache_service.dart';
import '../services/object_action_service.dart';
import '../widgets/map_objects_layer.dart';
import '../widgets/object_filters_widget.dart';
import '../widgets/nearby_objects_notifier.dart';
import '../widgets/object_details_sheet.dart';
import '../widgets/location_marker.dart';
import 'home/home.dart'; // Вынесенные компоненты
import 'history_screen.dart';
import 'walk_detail_screen.dart';
import 'settings_screen.dart';
import 'add_object_screen.dart';
import 'creature_collection_screen.dart';
import 'chat_list_screen.dart';
import 'about_app_screen.dart';
import 'route_planner_screen.dart';

/// Главный экран с картой OpenStreetMap
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final UserIdService _userIdService = UserIdService();
  final TileCacheService _tileCacheService = TileCacheService();
  final ObjectActionService _actionService = ObjectActionService();
  final List<LatLng> _routePoints = [];
  bool _initialized = false;
  bool _mapObjectsInitialized = false;
  bool _showFilters = false;
  LatLng? _currentLocation;
  LatLng _initialPosition = const LatLng(55.7558, 37.6173);
  final double _currentZoom = 15.0;
  UserInfo? _userInfo;
  Timer? _updateTimer;
  Timer? _creatureSpawnTimer;
  bool _mapReady = false;
  bool _pendingMoveToLocation = false;

  double _currentHeading = 0;
  double _currentSpeed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProviders();
    });

    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final walkProvider = context.read<WalkProvider>();
      if (walkProvider.hasCurrentWalk) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _moveToCurrentLocationOnResume();
    }
  }

  Future<void> _moveToCurrentLocationOnResume() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentHeading = position.heading;
        _currentSpeed = position.speed;
      });

      if (_mapReady) {
        _moveToCurrentLocation();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    _creatureSpawnTimer?.cancel();
    super.dispose();
  }

  Future<void> _initProviders() async {
    if (_initialized) return;
    _initialized = true;

    final walkProvider = context.read<WalkProvider>();
    final pedometerProvider = context.read<PedometerProvider>();

    await walkProvider.init();
    await pedometerProvider.init();

    try {
      await _tileCacheService.init();
    } catch (e) {
      debugPrint('Ошибка инициализации кэша тайлов: $e');
    }

    _userInfo = await _userIdService.getUserInfo();

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _initialPosition = _currentLocation!;
        _currentHeading = position.heading;
        _currentSpeed = position.speed;
      });

      if (_mapReady) {
        _moveToCurrentLocation();
      } else {
        _pendingMoveToLocation = true;
      }
    }

    if (walkProvider.currentWalk?.points.isNotEmpty ?? false) {
      _loadRouteFromWalk(walkProvider.currentWalk!.points);
    }

    _locationService.positionStream.listen((point) {
      if (!mounted) return;

      final walkProvider = context.read<WalkProvider>();

      setState(() {
        _currentLocation = LatLng(point.latitude, point.longitude);
        if (walkProvider.isTracking) {
          _routePoints.add(_currentLocation!);
        }
        _currentHeading = point.heading;
        _currentSpeed = point.speed;
      });

      final mapObjectProvider = context.read<MapObjectProvider>();
      mapObjectProvider.updateUserPosition(point.latitude, point.longitude);
    });

    if (await shouldShowIntro() && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AboutAppScreen()),
      );
    }
  }

  Future<void> _initMapObjects() async {
    if (_mapObjectsInitialized) return;
    _mapObjectsInitialized = true;

    final mapObjectProvider = context.read<MapObjectProvider>();
    await mapObjectProvider.init();

    if (_currentLocation != null) {
      mapObjectProvider.updateUserPosition(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
    }
  }

  void _loadRouteFromWalk(List<WalkPoint> points) {
    _routePoints.clear();
    for (final point in points) {
      _routePoints.add(LatLng(point.latitude, point.longitude));
    }
    if (_routePoints.isNotEmpty) {
      _currentLocation = _routePoints.last;
    }
    setState(() {});
  }

  int _getActiveFiltersCount() {
    final provider = context.read<MapObjectProvider>();
    int count = 0;

    if (!provider.enabledTypes.contains(MapObjectType.trashMonster)) count++;
    if (!provider.enabledTypes.contains(MapObjectType.secretMessage)) count++;
    if (!provider.enabledTypes.contains(MapObjectType.creature)) count++;

    if (provider.showCleaned) count++;
    if (provider.minReputation > 0) count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          const WalkStatsPanel(),
          _buildBottomControls(),
          _buildSideButtons(),
          if (_showFilters)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 250,
              child: ObjectFiltersWidget(),
            ),
          if (_currentLocation != null)
            Positioned(
              left: 16,
              right: 16,
              top: 130,
              child: NearbyObjectsNotifier(
                currentLat: _currentLocation!.latitude,
                currentLng: _currentLocation!.longitude,
                alertRadius: 100,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideButtons() {
    return Positioned(
      right: 16,
      bottom: 170,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Кнопка выбора маршрута
          Consumer<RouteProvider>(
            builder: (context, routeProvider, child) {
              final hasRoute = routeProvider.hasSelectedRoute;
              final routeColor = hasRoute
                  ? Color(routeProvider.selectedRoute!.colorValue)
                  : null;
              return _buildSideButton(
                icon: Icons.route,
                onPressed: () => _showRouteSelectionSheet(routeProvider),
                backgroundColor: hasRoute ? routeColor : null,
                iconColor: hasRoute ? Colors.white : null,
                tooltip: 'Выбрать маршрут',
              );
            },
          ),
          const SizedBox(height: 10),
          // Кнопка фильтров
          _buildSideButton(
            icon: Icons.tune,
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Фильтры объектов',
            badge: _getActiveFiltersCount() > 0 ? '$_getActiveFiltersCount()' : null,
          ),
          const SizedBox(height: 10),
          // Кнопка добавления объекта
          _buildSideButton(
            icon: Icons.add_location_alt,
            onPressed: _openAddObject,
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconColor: Theme.of(context).colorScheme.onPrimary,
            tooltip: 'Добавить объект',
          ),
        ],
      ),
    );
  }

  /// Унифицированная боковая кнопка
  Widget _buildSideButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? iconColor,
    String? badge,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
              ),
              if (badge != null)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Показать панель выбора маршрута
  void _showRouteSelectionSheet(RouteProvider routeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.route),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Выбор маршрута',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (routeProvider.hasSelectedRoute)
                      TextButton(
                        onPressed: () {
                          routeProvider.clearSelectedRoute();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Маршрут отключён'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        child: const Text('Отключить'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Список маршрутов
              Expanded(
                child: routeProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : routeProvider.routes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.route_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет сохранённых маршрутов',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RoutePlannerScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Создать маршрут'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: routeProvider.routes.length,
                            itemBuilder: (context, index) {
                              final route = routeProvider.routes[index];
                              final isSelected = routeProvider.selectedRoute?.id == route.id;
                              return _buildRouteSelectionTile(route, isSelected, routeProvider);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSelectionTile(
    PlannedRoute route,
    bool isSelected,
    RouteProvider routeProvider,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(route.colorValue),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.black, width: 2)
              : null,
        ),
        child: Icon(
          route.isFavorite ? Icons.star : Icons.route,
          color: Colors.white,
          size: 20,
        ),
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
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      selected: isSelected,
      onTap: () async {
        await routeProvider.selectRoute(route);
        if (context.mounted) {
          Navigator.pop(context);
          // Центрируем карту на маршруте
          if (route.waypoints.isNotEmpty) {
            _fitMapToRoute(route.waypoints);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Маршрут "${route.name}" выбран'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  /// Центрировать карту на маршруте
  void _fitMapToRoute(List<LatLng> waypoints) {
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

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialPosition,
        initialZoom: _currentZoom,
        onMapReady: () {
          _mapReady = true;
          if (_pendingMoveToLocation && _currentLocation != null) {
            _moveToCurrentLocation();
            _pendingMoveToLocation = false;
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.progulkin',
          maxZoom: 19,
          tileProvider: _tileCacheService.isInitialized
              ? _tileCacheService.getTileProvider()
              : null,
        ),
        // Запланированный маршрут (пунктирная линия)
        Consumer<RouteProvider>(
          builder: (context, routeProvider, child) {
            final route = routeProvider.selectedRoute;
            if (route == null || route.waypoints.length < 2) {
              return const SizedBox.shrink();
            }
            return PolylineLayer(
              polylines: [
                Polyline(
                  points: route.waypoints,
                  color: Color(route.colorValue).withValues(alpha: 0.5),
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                  // Пунктирный эффект имитируется через прозрачность
                  // В flutter_map 6.x нет поддержки pattern
                ),
              ],
            );
          },
        ),
        // Маркеры начальной и конечной точек запланированного маршрута
        Consumer<RouteProvider>(
          builder: (context, routeProvider, child) {
            final route = routeProvider.selectedRoute;
            if (route == null || route.waypoints.isEmpty) {
              return const SizedBox.shrink();
            }
            return MarkerLayer(
              markers: [
                // Начальная точка (зелёная)
                if (route.start != null)
                  Marker(
                    point: route.start!,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                // Конечная точка (красная)
                if (route.end != null && route.waypoints.length > 1)
                  Marker(
                    point: route.end!,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Текущий маршрут прогулки (сплошная линия)
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: const Color(0xFF2E7D32),
                strokeWidth: 5,
              ),
            ],
          ),
        Consumer<MapObjectProvider>(
          builder: (context, mapObjectProvider, child) {
            if (!_mapObjectsInitialized) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initMapObjects();
              });
            }
            return MapObjectsLayer(
              objects: mapObjectProvider.objects,
              onObjectTap: (obj) => _showObjectDetails(obj),
              onObjectLongPress: (obj) => _showObjectOptions(obj),
              userLocation: _currentLocation,
            );
          },
        ),
        if (_currentLocation != null) _buildLocationMarkers(),
      ],
    );
  }

  Widget _buildLocationMarkers() {
    return MarkerLayer(
      markers: [
        Marker(
          point: _currentLocation!,
          width: 50,
          height: 50,
          child: LocationMarker(
            movementHeading: _currentHeading,
            speed: _currentSpeed,
            showCompassWhenStationary: true,
          ),
        ),
        if (_routePoints.isNotEmpty)
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
      ],
    );
  }

  Widget _buildBottomControls() {
    return WalkControlPanel(
      onHistoryTap: () => _openScreen(const HistoryScreen()),
      onSettingsTap: () => _openScreen(const SettingsScreen()),
      onCollectionTap: () => _openScreen(const CreatureCollectionScreen()),
      onChatTap: () => _openScreen(const ChatListScreen()),
      onLocationTap: _moveToCurrentLocation,
      onAboutTap: () => _openScreen(const AboutAppScreen()),
      onStartWalk: _startWalk,
      onPauseWalk: _pauseWalk,
      onResumeWalk: _resumeWalk,
      onStopWalk: _stopWalk,
    );
  }

  void _openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // === Управление прогулкой ===

  Future<void> _startWalk() async {
    final walkProvider = context.read<WalkProvider>();
    final pedometerProvider = context.read<PedometerProvider>();

    final success = await walkProvider.startWalk();
    if (success) {
      await pedometerProvider.startCounting();

      final walk = walkProvider.currentWalk;
      if (walk?.points.isNotEmpty ?? false) {
        final point = walk!.points.first;
        _moveToPosition(point.latitude, point.longitude);
      }

      _startCreatureSpawning();
    } else {
      _showError(walkProvider.error ?? 'Не удалось начать прогулку');
    }
  }

  void _pauseWalk() {
    context.read<WalkProvider>().pauseWalk();
    context.read<PedometerProvider>().pauseCounting();
  }

  void _resumeWalk() {
    context.read<WalkProvider>().resumeWalk();
    context.read<PedometerProvider>().resumeCounting();
  }

  Future<void> _stopWalk() async {
    _stopCreatureSpawning();

    final creatureProvider = context.read<CreatureProvider>();
    final mapObjectProvider = context.read<MapObjectProvider>();
    await creatureProvider.cleanAllWildCreatures(mapObjectProvider.allObjects);

    final walkProvider = context.read<WalkProvider>();
    final pedometerProvider = context.read<PedometerProvider>();

    final steps = pedometerProvider.getCurrentSteps();
    final success = await walkProvider.stopWalk(steps: steps);

    if (success) {
      pedometerProvider.stopCounting();
      pedometerProvider.reset();
      _routePoints.clear();
      setState(() {});

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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          WalkDetailScreen(walk: walkProvider.walksHistory.first),
                    ),
                  );
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

  void _startCreatureSpawning() {
    _creatureSpawnTimer?.cancel();

    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted) return;
      _spawnCreatures();
    });

    _creatureSpawnTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      _spawnCreatures();
    });
  }

  void _stopCreatureSpawning() {
    _creatureSpawnTimer?.cancel();
    _creatureSpawnTimer = null;
  }

  Future<void> _spawnCreatures() async {
    if (_currentLocation == null) return;

    final mapObjectProvider = context.read<MapObjectProvider>();
    final spawned = await mapObjectProvider.spawnCreaturesAroundPlayer(
      playerLat: _currentLocation!.latitude,
      playerLng: _currentLocation!.longitude,
      maxCreatures: 2,
      radiusKm: 1.5,
    );

    if (spawned.isNotEmpty && mounted) {
      for (final creature in spawned) {
        debugPrint(
            '🦊 Заспавнено: ${creature.creatureType.emoji} ${creature.creatureType.name} (${creature.rarity.badge})');
      }
    }
  }

  // === Навигация ===

  void _moveToPosition(double lat, double lon) {
    _mapController.move(LatLng(lat, lon), _mapController.camera.zoom);
  }

  void _moveToCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16);
    }
  }

  // === Взаимодействие с объектами ===

  void _showObjectDetails(MapObject object) {
    final mapObjectProvider = context.read<MapObjectProvider>();
    final moderationProvider = context.read<ModerationProvider>();
    final interestProvider = context.read<InterestProvider>();
    final reminderProvider = context.read<ReminderProvider>();
    final creatureProvider = context.read<CreatureProvider>();
    final walkProvider = context.read<WalkProvider>();
    final isWalking = walkProvider.isTracking;
    final userId = _userInfo?.id ?? '';

    double? distance;
    if (_currentLocation != null) {
      distance = calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        object.latitude,
        object.longitude,
      );
    }

    final actionCheck = _actionService.canPerformAction(
      object,
      isWalking: isWalking,
      userLocation: _currentLocation,
      userId: userId,
    );

    VoidCallback? onAction;
    if (actionCheck.canPerform) {
      onAction = () async {
        final result = await _performObjectAction(
          object,
          mapObjectProvider,
          creatureProvider,
          userId,
        );
        if (mounted && result != null) {
          Navigator.pop(context);
          _handleActionResult(result, object, walkProvider);
        }
      };
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ObjectDetailsSheet(
            object: object,
            userId: userId,
            distance: distance,
            isWalking: isWalking,
            onConfirm: () async {
              await moderationProvider.confirmObject(object.id);
              if (walkProvider.hasCurrentWalk) {
                walkProvider.recordObjectConfirmed();
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Подтверждено! Спасибо за помощь.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            onDeny: () async {
              await moderationProvider.denyObject(object.id);
              if (walkProvider.hasCurrentWalk) {
                walkProvider.recordObjectDenied();
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Жалоба отправлена.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            onAction: onAction,
            actionHint: actionCheck.hint,
            onInterestToggle: object.type == MapObjectType.interestNote
                ? (noteId, userId) async {
                    final note = object as InterestNote;
                    if (note.hasInterestFrom(userId)) {
                      await interestProvider.removeInterestFromNote(noteId, userId);
                    } else {
                      await interestProvider.addInterestToNote(noteId, userId);
                    }
                    if (context.mounted) {
                      setState(() {});
                    }
                  }
                : null,
            onContactAuthor: object.type == MapObjectType.interestNote
                ? (note) {
                    Navigator.pop(context);
                    showContactAuthorSheet(context, note);
                  }
                : null,
            onReminderToggle: object.type == MapObjectType.reminderCharacter
                ? (reminderId) async {
                    final reminder = object as ReminderCharacter;
                    if (reminder.isActive) {
                      await reminderProvider.deactivateReminder(reminderId);
                    } else {
                      await reminderProvider.activateReminder(reminderId);
                    }
                    if (context.mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(reminder.isActive
                              ? 'Напоминание отключено'
                              : 'Напоминание включено'),
                          backgroundColor: Colors.cyan,
                        ),
                      );
                    }
                  }
                : null,
            onReminderSnooze: object.type == MapObjectType.reminderCharacter
                ? (reminderId, duration) async {
                    await reminderProvider.snoozeReminder(reminderId, duration);
                    if (context.mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Напоминание отложено на ${_formatSnoozeDuration(duration)}'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                : null,
          ),
        ),
      ),
    );
  }

  void _showObjectOptions(MapObject object) {
    showObjectOptionsSheet(
      context: context,
      object: object,
      userId: _userInfo?.id,
      onShowDetails: () => _showObjectDetails(object),
      onDelete: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Объект удалён'),
            backgroundColor: Colors.orange,
          ),
        );
      },
      onReport: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Жалоба отправлена')),
        );
      },
    );
  }

  Future<Object?> _performObjectAction(
    MapObject object,
    MapObjectProvider mapObjectProvider,
    CreatureProvider creatureProvider,
    String userId,
  ) async {
    try {
      switch (object.type) {
        case MapObjectType.trashMonster:
          final monster = object as TrashMonster;
          await mapObjectProvider.cleanTrashMonster(monster.id, userId);
          return monster;

        case MapObjectType.secretMessage:
          final secret = object as SecretMessage;
          final content =
              await mapObjectProvider.readSecretMessage(secret.id, userId);
          if (content != null) {
            return _SecretReadResult(title: secret.title, content: content);
          }
          return null;

        case MapObjectType.creature:
          final creature = object as Creature;
          final success = await creatureProvider.catchCreature(
            creature.id,
            userId,
            _userInfo?.name ?? 'Прогульщик',
            userLat: _currentLocation?.latitude,
            userLng: _currentLocation?.longitude,
          );
          if (success) {
            return creature;
          }
          return null;

        default:
          return null;
      }
    } catch (e) {
      debugPrint('Ошибка выполнения действия: $e');
      return null;
    }
  }

  void _handleActionResult(
      dynamic result, MapObject object, WalkProvider walkProvider) {
    if (result is TrashMonster) {
      if (walkProvider.hasCurrentWalk) {
        walkProvider.recordMonsterCleaned(result.cleaningPoints);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Отлично! +${result.cleaningPoints} очков'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result is Creature) {
      if (walkProvider.hasCurrentWalk) {
        walkProvider.recordCreatureCaught(20);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.creatureType.name} пойман!'),
          backgroundColor: Colors.purple,
        ),
      );
    } else if (result is _SecretReadResult) {
      if (walkProvider.hasCurrentWalk) {
        walkProvider.recordSecretRead();
      }
      _showSecretContent(result.title, result.content);
    }
  }

  void _showSecretContent(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📜 $title'),
        content: SelectableText(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddObject() async {
    if (_currentLocation == null) {
      _showError('Определите местоположение сначала');
      return;
    }

    final result = await Navigator.push<ObjectCreatedResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddObjectScreen(
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
          userInfo: _userInfo!,
        ),
      ),
    );

    if (result != null && mounted) {
      final walkProvider = context.read<WalkProvider>();
      if (walkProvider.hasCurrentWalk) {
        walkProvider.recordObjectAdded(result.points);
      }
    }
  }

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

  String _formatSnoozeDuration(Duration duration) {
    if (duration.inHours >= 24) {
      return 'до завтра';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return '$hours ч $minutes мин';
      }
      return '$hours ч';
    } else {
      return '${duration.inMinutes} мин';
    }
  }
}

class _SecretReadResult {
  final String title;
  final String content;

  const _SecretReadResult({required this.title, required this.content});
}
