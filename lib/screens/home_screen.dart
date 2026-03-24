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
import '../widgets/map_objects_layer.dart';
import 'history_screen.dart';
import 'walk_detail_screen.dart';
import 'settings_screen.dart';
import 'add_object_screen.dart';

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
  final List<LatLng> _routePoints = [];
  bool _initialized = false;
  bool _mapObjectsInitialized = false;
  LatLng? _currentLocation; // Текущая позиция пользователя
  LatLng _initialPosition = const LatLng(55.7558, 37.6173); // Москва по умолчанию
  double _currentZoom = 15.0;
  UserInfo? _userInfo;

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
        // Слой тайлов OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.progulkin',
          maxZoom: 19,
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
  
  /// Показать детали объекта в BottomSheet
  void _showObjectDetails(MapObject object) {
    final mapObjectProvider = context.read<MapObjectProvider>();
    final walkProvider = context.read<WalkProvider>();
    final isWalking = walkProvider.isTracking;
    
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
    
    // Получаем действие и подсказку
    final actionInfo = _getObjectActionInfo(object, mapObjectProvider, isWalking);
    
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
          child: _ObjectDetailsContent(
            object: object,
            userId: _userInfo?.id ?? '',
            distance: distance,
            isWalking: isWalking,
            onConfirm: () async {
              await mapObjectProvider.confirmObject(object.id);
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
            onAction: actionInfo['action'],
            actionHint: actionInfo['hint'],
          ),
        ),
      ),
    );
  }
  
  /// Получить информацию о действии для объекта
  Map<String, dynamic> _getObjectActionInfo(MapObject object, MapObjectProvider provider, bool isWalking) {
    if (object.type == MapObjectType.trashMonster) {
      final monster = object as TrashMonster;
      if (monster.isCleaned) {
        return {'action': null, 'hint': 'Уже убрано'};
      }
      if (!isWalking) {
        return {'action': null, 'hint': '💼 Начните прогулку, чтобы отметить как убранное'};
      }
      if (_currentLocation == null) {
        return {'action': null, 'hint': '📍 Определяем ваше местоположение...'};
      }
      final distance = calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        monster.latitude,
        monster.longitude,
      );
      if (distance > 100) {
        return {'action': null, 'hint': '📍 Подойдите ближе (${distance.toInt()} м до цели)'};
      }
      return {
        'action': () async {
          await provider.cleanTrashMonster(monster.id, _userInfo?.id ?? '');
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Отлично! +${monster.cleaningPoints} очков'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        'hint': null,
      };
    }
    
    if (object.type == MapObjectType.creature) {
      final creature = object as Creature;
      if (!creature.isWild) {
        return {'action': null, 'hint': '🏠 Уже приручено ${creature.ownerName}'};
      }
      if (!isWalking) {
        return {'action': null, 'hint': '💼 Начните прогулку, чтобы поймать'};
      }
      if (_currentLocation == null) {
        return {'action': null, 'hint': '📍 Определяем ваше местоположение...'};
      }
      final distance = calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        creature.latitude,
        creature.longitude,
      );
      if (distance > 50) {
        return {'action': null, 'hint': '📍 Подойдите ближе (${distance.toInt()} м до цели)'};
      }
      return {
        'action': () async {
          await provider.catchCreature(
            creature.id,
            _userInfo?.id ?? '',
            _userInfo?.name ?? 'Прогульщик',
          );
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${creature.creatureType.name} пойман!'),
                backgroundColor: Colors.purple,
              ),
            );
          }
        },
        'hint': null,
      };
    }
    
    if (object.type == MapObjectType.secretMessage) {
      final secret = object as SecretMessage;
      final userId = _userInfo?.id ?? '';
      
      if (secret.isReadByUser(userId)) {
        return {'action': null, 'hint': '✅ Вы уже прочитали это сообщение'};
      }
      if (!isWalking) {
        return {'action': null, 'hint': '💼 Начните прогулку, чтобы прочитать сообщение'};
      }
      if (_currentLocation == null) {
        return {'action': null, 'hint': '📍 Определяем ваше местоположение...'};
      }
      final distance = calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        secret.latitude,
        secret.longitude,
      );
      if (distance > secret.unlockRadius) {
        return {'action': null, 'hint': '📍 Подойдите ближе (${distance.toInt()} м до разблокировки)'};
      }
      return {
        'action': () async {
          final content = await provider.readSecretMessage(secret.id, userId);
          if (mounted && content != null) {
            Navigator.pop(context);
            _showSecretContent(secret.title, content);
          }
        },
        'hint': null,
      };
    }
    
    return {'action': null, 'hint': null};
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
  void _openAddObject() {
    if (_currentLocation == null) {
      _showError('Определите местоположение сначала');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddObjectScreen(
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
          userInfo: _userInfo!,
        ),
      ),
    );
  }
}

/// Контент для BottomSheet с деталями объекта
class _ObjectDetailsContent extends StatelessWidget {
  final MapObject object;
  final String userId;
  final double? distance;
  final bool isWalking;
  final VoidCallback? onConfirm;
  final VoidCallback? onDeny;
  final VoidCallback? onAction;
  final String? actionHint;
  
  const _ObjectDetailsContent({
    required this.object,
    required this.userId,
    required this.isWalking,
    this.distance,
    this.onConfirm,
    this.onDeny,
    this.onAction,
    this.actionHint,
  });
  
  @override
  Widget build(BuildContext context) {
    // Форматируем расстояние
    String distanceText = 'Неизвестно';
    if (distance != null) {
      if (distance! < 1000) {
        distanceText = '${distance!.toInt()} м';
      } else {
        distanceText = '${(distance! / 1000).toStringAsFixed(1)} км';
      }
    }
    
    // Определяем метку и иконку для кнопки действия
    String actionLabel;
    IconData actionIcon;
    switch (object.type) {
      case MapObjectType.trashMonster:
        actionLabel = 'Убрано!';
        actionIcon = Icons.cleaning_services;
        break;
      case MapObjectType.secretMessage:
        actionLabel = 'Прочитать';
        actionIcon = Icons.lock_open;
        break;
      case MapObjectType.creature:
        actionLabel = 'Поймать!';
        actionIcon = Icons.pets;
        break;
      default:
        actionLabel = 'Действие';
        actionIcon = Icons.check;
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            children: [
              Text(
                object.type.emoji,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitle(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      object.shortDescription,
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
          
          // Информация
          _buildInfoSection(context),
          
          const SizedBox(height: 16),
          
          // Статистика
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                object.ownerName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              const Icon(Icons.thumb_up, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text('${object.confirms}'),
              const SizedBox(width: 12),
              const Icon(Icons.thumb_down, size: 16, color: Colors.red),
              const SizedBox(width: 4),
              Text('${object.denies}'),
              const SizedBox(width: 12),
              Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('${object.views}'),
              if (object.isTrusted) ...[
                const SizedBox(width: 12),
                const Icon(Icons.verified, size: 16, color: Colors.green),
              ],
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Кнопки подтверждения/опровержения
          Row(
            children: [
              if (onConfirm != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.thumb_up, size: 18),
                    label: const Text('Подтвердить'),
                  ),
                ),
              if (onConfirm != null && onDeny != null)
                const SizedBox(width: 8),
              if (onDeny != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDeny,
                    icon: const Icon(Icons.thumb_down, size: 18),
                    label: const Text('Опровергнуть'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          
          // Кнопка действия или подсказка
          if (onAction != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else if (actionHint != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      actionHint!,
                      style: TextStyle(color: Colors.orange[700]),
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
  
  String _getTitle() {
    switch (object.type) {
      case MapObjectType.trashMonster:
        final monster = object as TrashMonster;
        return '${monster.trashType.emoji} ${monster.trashType.name}';
      case MapObjectType.secretMessage:
        final secret = object as SecretMessage;
        return '📜 ${secret.title}';
      case MapObjectType.creature:
        final creature = object as Creature;
        return '${creature.rarity.badge} ${creature.creatureType.name}';
      default:
        return object.type.name;
    }
  }
  
  Widget _buildInfoSection(BuildContext context) {
    final items = <Widget>[];
    
    switch (object.type) {
      case MapObjectType.trashMonster:
        final monster = object as TrashMonster;
        items.addAll([
          _buildInfoRow(
            context,
            icon: Icons.layers,
            label: 'Класс',
            value: '${monster.monsterClass.badge} ${monster.monsterClass.name}',
          ),
          _buildInfoRow(
            context,
            icon: Icons.cleaning_services,
            label: 'Количество',
            value: monster.quantity.name,
          ),
          _buildInfoRow(
            context,
            icon: Icons.star,
            label: 'Очки за уборку',
            value: '${monster.cleaningPoints}',
          ),
          if (monster.description.isNotEmpty)
            _buildInfoRow(
              context,
              icon: Icons.description,
              label: 'Описание',
              value: monster.description,
            ),
          if (monster.isCleaned) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Убрано ${monster.cleanedBy == userId ? "вами" : ""}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ]);
        break;
        
      case MapObjectType.secretMessage:
        final secret = object as SecretMessage;
        items.addAll([
          _buildInfoRow(
            context,
            icon: Icons.lock,
            label: 'Тип',
            value: secret.secretType.name,
          ),
          _buildInfoRow(
            context,
            icon: Icons.location_on,
            label: 'Радиус разблокировки',
            value: '${secret.unlockRadius.toInt()} м',
          ),
          _buildInfoRow(
            context,
            icon: Icons.visibility,
            label: 'Прочитано раз',
            value: '${secret.currentReads}',
          ),
          if (secret.isOneTime)
            _buildInfoRow(
              context,
              icon: Icons.timer,
              label: 'Одноразовое',
              value: 'Да',
            ),
        ]);
        break;
        
      case MapObjectType.creature:
        final creature = object as Creature;
        items.addAll([
          _buildInfoRow(
            context,
            icon: Icons.auto_awesome,
            label: 'Редкость',
            value: '${creature.rarity.badge} ${creature.rarity.name}',
          ),
          _buildInfoRow(
            context,
            icon: Icons.terrain,
            label: 'Среда обитания',
            value: creature.habitat.name,
          ),
          _buildInfoRow(
            context,
            icon: Icons.favorite,
            label: 'HP',
            value: '${creature.currentHealth}/${creature.maxHealth}',
          ),
          _buildInfoRow(
            context,
            icon: Icons.flash_on,
            label: 'Атака',
            value: '${creature.attack}',
          ),
          _buildInfoRow(
            context,
            icon: Icons.shield,
            label: 'Защита',
            value: '${creature.defense}',
          ),
          if (!creature.isWild)
            _buildInfoRow(
              context,
              icon: Icons.person,
              label: 'Владелец',
              value: creature.ownerName ?? 'Неизвестно',
            ),
        ]);
        break;
        
      default:
        break;
    }
    
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(children: items);
  }
  
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
