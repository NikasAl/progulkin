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
import '../widgets/location_marker.dart';
import 'history_screen.dart';
import 'walk_detail_screen.dart';
import 'settings_screen.dart';
import 'add_object_screen.dart';
import 'creature_collection_screen.dart';
import 'chat_list_screen.dart';
import 'about_app_screen.dart';

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
  bool _showFilters = false; // Показать панель фильтров
  LatLng? _currentLocation; // Текущая позиция пользователя
  LatLng _initialPosition = const LatLng(55.7558, 37.6173); // Москва по умолчанию
  final double _currentZoom = 15.0;
  UserInfo? _userInfo;
  Timer? _updateTimer; // Таймер для обновления времени
  Timer? _creatureSpawnTimer; // Таймер для спавна существ
  bool _mapReady = false; // Карта готова
  bool _pendingMoveToLocation = false; // Нужно перейти к позиции после готовности карты
  
  // Направление и скорость для маркера
  double _currentHeading = 0;
  double _currentSpeed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // При возобновлении приложения - переместить карту к текущей позиции
    if (state == AppLifecycleState.resumed) {
      _moveToCurrentLocationOnResume();
    }
  }
  
  /// Переместить карту к текущей позиции при возобновлении приложения
  Future<void> _moveToCurrentLocationOnResume() async {
    // Небольшая задержка для корректного восстановления состояния
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    // Получаем актуальную позицию
    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentHeading = position.heading;
        _currentSpeed = position.speed;
      });
      
      // Перемещаем карту к позиции
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
    
    // Инициализируем кэш тайлов
    try {
      await _tileCacheService.init();
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
        _currentHeading = position.heading;
        _currentSpeed = position.speed;
      });
      
      // Если карта уже готова - переходим к позиции
      if (_mapReady) {
        _moveToCurrentLocation();
      } else {
        _pendingMoveToLocation = true;
      }
    }
    
    // Если есть текущая прогулка, загружаем маршрут
    if (walkProvider.currentWalk?.points.isNotEmpty ?? false) {
      _loadRouteFromWalk(walkProvider.currentWalk!.points);
    }
    
    // Подписываемся на обновления позиции во время прогулки
    _locationService.positionStream.listen((point) {
      if (!mounted) return;

      final walkProvider = context.read<WalkProvider>();

      setState(() {
        _currentLocation = LatLng(point.latitude, point.longitude);
        // Добавляем точку в маршрут только если прогулка активна (не на паузе)
        if (walkProvider.isTracking) {
          _routePoints.add(_currentLocation!);
        }
        _currentHeading = point.heading;
        _currentSpeed = point.speed;
      });

      // Обновляем позицию для MapObjectProvider
      final mapObjectProvider = context.read<MapObjectProvider>();
      mapObjectProvider.updateUserPosition(point.latitude, point.longitude);
    });

    // Показываем вводный экран при первом запуске
    if (await shouldShowIntro() && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AboutAppScreen()),
      );
    }
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
          
          // Нижняя панель управления
          _buildBottomControls(),
          
          // Кнопки фильтра и добавления объектов (выровнены и подняты над нижней панелью)
          Positioned(
            right: 16,
            bottom: 170,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: FilterToggleButton(
                    mini: true,
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    activeFilters: _getActiveFiltersCount(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _openAddObject,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: const Icon(Icons.add_location_alt, size: 22),
                  ),
                ),
              ],
            ),
          ),
          
          // Панель фильтров
          if (_showFilters)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 250,
              child: ObjectFiltersWidget(),
            ),
          
          // Уведомление о близлежащих объектах
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

  /// Карта OpenStreetMap
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialPosition,
        initialZoom: _currentZoom,
        onMapReady: () {
          _mapReady = true;
          // Если позиция уже получена - переходим к ней
          if (_pendingMoveToLocation && _currentLocation != null) {
            _moveToCurrentLocation();
            _pendingMoveToLocation = false;
          }
        },
      ),
      children: [
        // Слой тайлов OpenStreetMap с поддержкой кэша
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.progulkin',
          maxZoom: 19,
          // Используем кэшированные тайлы если доступны
          tileProvider: _tileCacheService.isInitialized 
              ? _tileCacheService.getTileProvider()
              : null,
        ),
        // Слой маршрута
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: const Color(0xFF2E7D32), // Тёмно-зелёный, виден на любой карте
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
              // Маркер текущего положения со стрелкой направления
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

  /// Верхняя панель со статистикой (включает педометр)
  Widget _buildTopPanel() {
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
                // Шаги (педометр)
                _buildCompactStatItem(
                  icon: Icons.directions_walk,
                  value: '${pedometerProvider.steps}',
                  label: 'шагов',
                  color: Colors.green,
                ),
                _buildVerticalDivider(height: 32),
                // Метры (педометр)
                _buildCompactStatItem(
                  icon: Icons.straighten,
                  value: pedometerProvider.formattedDistance,
                  label: 'пройдено',
                  color: Colors.blue,
                ),
                _buildVerticalDivider(height: 32),
                // Время прогулки
                _buildCompactStatItem(
                  icon: Icons.timer_outlined,
                  value: walkProvider.hasCurrentWalk 
                      ? walkProvider.currentWalkFormattedDuration 
                      : '0:00',
                  label: 'время',
                  color: Colors.orange,
                ),
                _buildVerticalDivider(height: 32),
                // Скорость
                _buildCompactStatItem(
                  icon: Icons.speed_outlined,
                  value: walk?.formattedSpeed ?? '0 км/ч',
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

  /// Компактный элемент статистики для верхней панели
  Widget _buildCompactStatItem({
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

  /// Вертикальный разделитель
  Widget _buildVerticalDivider({double height = 40}) {
    return Container(
      height: height,
      width: 1,
      color: Colors.grey[300],
    );
  }

  /// Нижняя панель управления
  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                  // Горизонтально прокручиваемые кнопки
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIconButton(
                          icon: Icons.history,
                          tooltip: 'История',
                          onTap: () => _openHistory(context),
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          icon: Icons.settings,
                          tooltip: 'Настройки',
                          onTap: () => _openSettings(context),
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          icon: Icons.pets,
                          tooltip: 'Коллекция',
                          onTap: () => _openCreatureCollection(context),
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          icon: Icons.chat,
                          tooltip: 'Сообщения',
                          onTap: () => _openChatList(context),
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          icon: Icons.my_location,
                          tooltip: 'Моё местоположение',
                          onTap: _moveToCurrentLocation,
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          icon: Icons.info_outline,
                          tooltip: 'О приложении',
                          onTap: () => _openAboutApp(context),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMainButton(walkProvider, pedometerProvider),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Компактная кнопка-иконка
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22, color: Colors.grey[700]),
          ),
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
      
      // Запускаем спавн существ каждые 2 минуты
      _startCreatureSpawning();
    } else {
      _showError(walkProvider.error ?? 'Не удалось начать прогулку');
    }
  }

  /// Запустить периодический спавн существ
  void _startCreatureSpawning() {
    _creatureSpawnTimer?.cancel();
    
    // Первоначальный спавн через 30 секунд
    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted) return;
      _spawnCreatures();
    });
    
    // Периодический спавн каждые 2 минуты
    _creatureSpawnTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      _spawnCreatures();
    });
  }

  /// Остановить спавн существ
  void _stopCreatureSpawning() {
    _creatureSpawnTimer?.cancel();
    _creatureSpawnTimer = null;
  }

  /// Спавн существ вокруг игрока
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
        debugPrint('🦊 Заспавнено: ${creature.creatureType.emoji} ${creature.creatureType.name} (${creature.rarity.badge})');
      }
    }
  }

  /// Остановить прогулку
  Future<void> _stopWalk(
    WalkProvider walkProvider,
    PedometerProvider pedometerProvider,
  ) async {
    // Останавливаем спавн существ
    _stopCreatureSpawning();
    
    // Очищаем диких существ после прогулки
    final mapObjectProvider = context.read<MapObjectProvider>();
    await mapObjectProvider.cleanAllWildCreatures();
    
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
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
  
  /// Открыть коллекцию существ
  void _openCreatureCollection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatureCollectionScreen()),
    );
  }
  
  /// Открыть список чатов
  void _openChatList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatListScreen()),
    );
  }

  /// Открыть экран "О приложении"
  void _openAboutApp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutAppScreen()),
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
            // Управление напоминаниями
            onReminderToggle: object.type == MapObjectType.reminderCharacter
                ? (reminderId) async {
                    final reminder = object as ReminderCharacter;
                    if (reminder.isActive) {
                      await mapObjectProvider.deactivateReminder(reminderId);
                    } else {
                      await mapObjectProvider.activateReminder(reminderId);
                    }
                    if (context.mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(reminder.isActive ? 'Напоминание отключено' : 'Напоминание включено'),
                          backgroundColor: Colors.cyan,
                        ),
                      );
                    }
                  }
                : null,
            onReminderSnooze: object.type == MapObjectType.reminderCharacter
                ? (reminderId, duration) async {
                    await mapObjectProvider.snoozeReminder(reminderId, duration);
                    if (context.mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Напоминание отложено на ${_formatSnoozeDuration(duration)}'),
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
          final success = await provider.catchCreature(
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
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                    if (!context.mounted) return;
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
    if (result != null && mounted) {
      final walkProvider = context.read<WalkProvider>();
      if (walkProvider.hasCurrentWalk) {
        walkProvider.recordObjectAdded(result.points);
      }
    }
  }
  
  /// Форматировать длительность откладывания
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

/// Вспомогательный класс для результата чтения секретного сообщения
class _SecretReadResult {
  final String title;
  final String content;
  
  const _SecretReadResult({required this.title, required this.content});
}
