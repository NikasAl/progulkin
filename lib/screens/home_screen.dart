import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/walk_provider.dart';
import '../providers/pedometer_provider.dart';
import '../providers/map_object_provider.dart';
import '../models/walk_point.dart';
import '../models/map_objects/map_objects.dart';
import '../services/location_service.dart';
import '../services/user_id_service.dart';
import '../services/tile_cache_service.dart';
import '../services/object_action_service.dart';
import '../widgets/map_objects_layer.dart';
import '../widgets/object_filters_widget.dart';
import '../widgets/nearby_objects_notifier.dart';
import '../widgets/object_details_sheet.dart';
import 'history_screen.dart';
import 'walk_detail_screen.dart';
import 'settings_screen.dart';
import 'add_object_screen.dart';
import 'route_planning_screen.dart';
import 'storage_screen.dart';

/// Главный экран с картой OpenStreetMap
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final UserIdService _userIdService = UserIdService();
  final TileCacheService _tileCacheService = TileCacheService();
  final ObjectActionService _actionService = ObjectActionService();
  final List<LatLng> _routePoints = [];
  bool _initialized = false;
  bool _mapObjectsInitialized = false;
  bool _tileCacheInitialized = false;
  bool _showFilters = false; // Показать панель фильтров
  LatLng? _currentLocation; // Текущая позиция пользователя
  LatLng _initialPosition = const LatLng(55.7558, 37.6173); // Москва по умолчанию
  double _currentZoom = 15.0;
  UserInfo? _userInfo;
  Timer? _updateTimer; // Таймер для обновления времени

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProviders();
    });
    
    // Таймер для обновления времени каждую секунду
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final walkProvider = context.read<WalkProvider>();
      if (walkProvider.hasCurrentWalk) {
        setState(() {});
      }
    });
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initProviders() async {
    if (_initialized) return;
    _initialized = true;
    
    final walkProvider = context.read<WalkProvider>();
    final pedometerProvider = context.read<PedometerProvider>();
    
    await walkProvider.init();
    await pedometerProvider.init();
    
    // Инициализируем кэш тайлов
    try {
      await _tileCacheService.init();
      _tileCacheInitialized = true;
    } catch (e) {
      debugPrint('Ошибка инициализации кэша тайлов: $e');
    }
    
    // Получаем информацию о пользователе
    _userInfo = await _userIdService.getUserInfo();
    
    // Получаем текущую позицию
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _initialPosition = _currentLocation!;
      });
    }
    
    // Если есть текущая прогулка, загружаем маршрут
    if (walkProvider.currentWalk?.points.isNotEmpty ?? false) {
      _loadRouteFromWalk(walkProvider.currentWalk!.points);
    }
    
    // Подписываемся на обновления позиции во время прогулки
    _locationService.positionStream.listen((point) {
      setState(() {
        _currentLocation = LatLng(point.latitude, point.longitude);
        _routePoints.add(_currentLocation!);
      });
      
      // Обновляем позицию для MapObjectProvider
      final mapObjectProvider = context.read<MapObjectProvider>();
      mapObjectProvider.updateUserPosition(point.latitude, point.longitude);
    });
  }
  
  /// Инициализация объектов карты (вызывается при первом отображении карты)
  Future<void> _initMapObjects() async {
    if (_mapObjectsInitialized) return;
    _mapObjectsInitialized = true;
    
    final mapObjectProvider = context.read<MapObjectProvider>();
    await mapObjectProvider.init();
    
    // Обновляем позицию если уже известна
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

  /// Получить количество активных фильтров
  int _getActiveFiltersCount() {
    final provider = context.read<MapObjectProvider>();
    int count = 0;
    
    // Считаем отключенные типы как активные фильтры
    if (!provider.enabledTypes.contains(MapObjectType.trashMonster)) count++;
    if (!provider.enabledTypes.contains(MapObjectType.secretMessage)) count++;
    if (!provider.enabledTypes.contains(MapObjectType.creature)) count++;
    
    // Дополнительные фильтры
    if (provider.showCleaned) count++;
    if (provider.minReputation > 0) count++;
    
    return count;
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
          
          // FAB для добавления объектов
          Positioned(
            right: 16,
            bottom: 180,
            child: FloatingActionButton(
              onPressed: _openAddObject,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.add_location_alt),
            ),
          ),
          
          // Кнопка фильтров
          Positioned(
            right: 16,
            bottom: 250,
            child: FilterToggleButton(
              onTap: () => setState(() => _showFilters = !_showFilters),
              activeFilters: _getActiveFiltersCount(),
            ),
          ),
          
          // Панель фильтров
          if (_showFilters)
            Positioned(
              left: 16,
              right: 16,
              bottom: 320,
              child: const ObjectFiltersWidget(),
            ),
          
          // Уведомление о близлежащих объектах
          if (_currentLocation != null)
            Positioned(
              left: 16,
              right: 16,
              top: 130,
              child: NearbyObjectsNotifier(
                key: ValueKey('nearby_${_currentLocation!.latitude.toStringAsFixed(4)}_${_currentLocation!.longitude.toStringAsFixed(4)}'),
                currentLat: _currentLocation!.latitude,
                currentLng: _currentLocation!.longitude,
                alertRadius: 100,
              ),
            ),
        ],
      ),
    );
  }

  /// Карта OpenStreetMap
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialPosition,
        initialZoom: _currentZoom,
        onMapReady: () {
          // Карта готова
        },
      ),
      children: [
        // Слой тайлов OpenStreetMap с поддержкой кэша
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.progulkin',
          maxZoom: 19,
          // Используем кэшированные тайлы если доступны
          tileProvider: _tileCacheInitialized 
              ? _tileCacheService.getTileProvider()
              : null,
        ),
        // Слой маршрута
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 5,
              ),
            ],
          ),
        // Слой объектов карты (мусорные монстры, сообщения, существа)
        Consumer<MapObjectProvider>(
          builder: (context, mapObjectProvider, child) {
            // Инициализируем при первой отрисовке
            if (!_mapObjectsInitialized) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initMapObjects();
              });
            }
            return MapObjectsLayer(
              objects: mapObjectProvider.objects,
              onObjectTap: (obj) => _showObjectDetails(obj),
              onObjectLongPress: (obj) => _showObjectOptions(obj),
            );
          },
        ),
        // Маркер текущей позиции
        if (_currentLocation != null)
          MarkerLayer(
            markers: [
              // Маркер текущего положения (синий круг с пульсацией)
              Marker(
                point: _currentLocation!,
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Внешний пульсирующий круг
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Средний круг
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Внутренний круг с направлением
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue,
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
                    ),
                  ],
                ),
              ),
              // Маркер начала маршрута (зелёный)
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
                  // Используем геттер из провайдера для корректного времени с паузой
                  value: walkProvider.hasCurrentWalk 
                      ? walkProvider.currentWalkFormattedDuration 
                      : '0 сек',
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
                        icon: Icons.storage,
                        label: 'Хранилище',
                        onTap: _openStorage,
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
    // Показываем кнопки паузы/продолжить если есть текущая прогулка (активная или на паузе)
    final hasWalk = walkProvider.hasCurrentWalk;
    final isTracking = walkProvider.isTracking;

    if (hasWalk) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (walkProvider.isTracking) {
                  walkProvider.pauseWalk();
                  pedometerProvider.pauseCounting();
                } else {
                  walkProvider.resumeWalk();
                  pedometerProvider.resumeCounting();
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
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16);
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

  /// Открыть хранилище объектов
  void _openStorage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StorageScreen()),
    );
  }

  /// Открыть настройки
  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    );
  }
  
  /// Открыть экран планирования маршрута (кэширование карт)
  void _openRoutePlanning() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoutePlanningScreen()),
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
  
  /// Показать детали объекта в BottomSheet
  void _showObjectDetails(MapObject object) {
    final mapObjectProvider = context.read<MapObjectProvider>();
    final walkProvider = context.read<WalkProvider>();
    final isWalking = walkProvider.isTracking;
    final userId = _userInfo?.id ?? '';
    
    // Вычисляем расстояние до объекта
    double? distance;
    if (_currentLocation != null) {
      distance = calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        object.latitude,
        object.longitude,
      );
    }
    
    // Проверяем возможность действия через сервис
    final actionCheck = _actionService.canPerformAction(
      object,
      isWalking: isWalking,
      userLocation: _currentLocation,
      userId: userId,
    );
    
    // Создаём callback для действия если оно доступно
    VoidCallback? onAction;
    if (actionCheck.canPerform) {
      onAction = () async {
        final result = await _performObjectAction(object, mapObjectProvider, userId);
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
              await mapObjectProvider.confirmObject(object.id);
              // Записываем статистику прогулки
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
              await mapObjectProvider.denyObject(object.id);
              // Записываем статистику прогулки
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
                      await mapObjectProvider.removeInterestFromNote(noteId, userId);
                    } else {
                      await mapObjectProvider.addInterestToNote(noteId, userId);
                    }
                    if (context.mounted) {
                      setState(() {});
                    }
                  }
                : null,
            onContactAuthor: object.type == MapObjectType.interestNote
                ? (note) => _showContactAuthorDialog(note)
                : null,
          ),
        ),
      ),
    );
  }
  
  /// Выполнить действие с объектом
  Future<Object?> _performObjectAction(
    MapObject object,
    MapObjectProvider provider,
    String userId,
  ) async {
    try {
      switch (object.type) {
        case MapObjectType.trashMonster:
          final monster = object as TrashMonster;
          await provider.cleanTrashMonster(monster.id, userId);
          return monster;
          
        case MapObjectType.secretMessage:
          final secret = object as SecretMessage;
          final content = await provider.readSecretMessage(secret.id, userId);
          if (content != null) {
            return _SecretReadResult(title: secret.title, content: content);
          }
          return null;
          
        case MapObjectType.creature:
          final creature = object as Creature;
          await provider.catchCreature(
            creature.id,
            userId,
            _userInfo?.name ?? 'Прогульщик',
          );
          return creature;
          
        default:
          return null;
      }
    } catch (e) {
      debugPrint('Ошибка выполнения действия: $e');
      return null;
    }
  }
  
  /// Обработать результат действия
  void _handleActionResult(dynamic result, MapObject object, WalkProvider walkProvider) {
    if (result is TrashMonster) {
      // Записываем статистику прогулки
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
      // Записываем статистику прогулки
      if (walkProvider.hasCurrentWalk) {
        walkProvider.recordCreatureCaught(20); // Базовые очки за поимку
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.creatureType.name} пойман!'),
          backgroundColor: Colors.purple,
        ),
      );
    } else if (result is _SecretReadResult) {
      // Записываем статистику прогулки
      if (walkProvider.hasCurrentWalk) {
        walkProvider.recordSecretRead();
      }
      _showSecretContent(result.title, result.content);
    }
  }
  
  /// Показать содержимое секретного сообщения
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

  /// Показать диалог связи с автором заметки
  void _showContactAuthorDialog(InterestNote note) {
    Navigator.pop(context); // Закрываем BottomSheet

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Row(
                children: [
                  Text(note.category.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Связаться с автором',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          note.ownerName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Заметка
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (note.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(note.description),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Варианты связи
              const Text(
                'Способы связи:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // VK
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.language, color: Colors.white),
                ),
                title: const Text('ВКонтакте'),
                subtitle: const Text('Написать сообщение'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Открыть VK профиль
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Открытие VK... (в разработке)')),
                  );
                },
              ),

              // Max
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat, color: Colors.white),
                ),
                title: const Text('Max Messenger'),
                subtitle: const Text('Написать сообщение'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Открыть Max
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Открытие Max... (в разработке)')),
                  );
                },
              ),

              // P2P
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.wifi, color: Colors.white),
                ),
                title: const Text('P2P сообщение'),
                subtitle: const Text('Написать напрямую через приложение'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Открыть P2P чат
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('P2P чат в разработке')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Показать опции объекта
  void _showObjectOptions(MapObject object) {
    final isOwner = object.ownerId == _userInfo?.id;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
              title: const Text('Подробности'),
              onTap: () {
                Navigator.pop(context);
                _showObjectDetails(object);
              },
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Удалить объект?'),
                      content: const Text('Это действие нельзя отменить.'),
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
                    await context.read<MapObjectProvider>().deleteObject(
                      object.id,
                      _userInfo?.id ?? '',
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Объект удалён'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Пожаловаться'),
              onTap: () async {
                await context.read<MapObjectProvider>().denyObject(object.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Жалоба отправлена')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// Открыть экран добавления объекта
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
    
    // Записываем статистику если объект создан во время прогулки
    if (result != null) {
      final walkProvider = context.read<WalkProvider>();
      if (walkProvider.hasCurrentWalk) {
        walkProvider.recordObjectAdded(result.points);
      }
    }
  }
}

/// Вспомогательный класс для результата чтения секретного сообщения
class _SecretReadResult {
  final String title;
  final String content;
  
  const _SecretReadResult({required this.title, required this.content});
}
