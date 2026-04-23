import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../di/service_locator.dart';
import '../services/tile_cache_service.dart';
import '../services/location_service.dart';

/// Экран планирования маршрута и кэширования карт
class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({super.key});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final MapController _mapController = MapController();
  final TileCacheService _tileCacheService = getIt<TileCacheService>();
  final LocationService _locationService = getIt<LocationService>();
  final Distance _distanceCalculator = Distance();
  
  final List<LatLng> _waypoints = [];
  LatLng? _currentPosition; // Текущая позиция (null пока не получена)
  final double _currentZoom = 14.0;
  
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedTiles = 0;
  int _totalTiles = 0;
  String? _statusMessage;
  CacheStats? _cacheStats;
  
  // Настройки загрузки
  final Set<int> _selectedZoomLevels = {14, 15, 16, 17};
  double _bufferMeters = 200;
  
  @override
  void initState() {
    super.initState();
    _initScreen();
  }
  
  Future<void> _initScreen() async {
    try {
      // Инициализируем сервис кэширования
      await _tileCacheService.init();
      
      // Получаем текущую позицию
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _currentPosition = LatLng(position.latitude, position.longitude);
      }
      
      // Загружаем статистику кэша
      final stats = await _tileCacheService.getCacheStats();
      _cacheStats = stats;
      _statusMessage = 'В кэше: ${stats.tileCount} тайлов (${stats.formattedSize})';
    } catch (e) {
      _statusMessage = 'Ошибка инициализации: $e';
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_isDownloading) return;
    
    setState(() {
      _waypoints.add(point);
    });
    
    final distance = _calculateRouteDistance();
    final distanceText = distance > 0 ? ' • ${_formatDistance(distance)}' : '';
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Точка ${_waypoints.length}: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}$distanceText'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  void _undoLastPoint() {
    if (_waypoints.isNotEmpty) {
      setState(() {
        _waypoints.removeLast();
      });
    }
  }
  
  void _clearRoute() {
    setState(() {
      _waypoints.clear();
    });
  }
  
  /// Рассчитывает общую длину маршрута в метрах
  double _calculateRouteDistance() {
    if (_waypoints.length < 2) return 0;
    
    double totalDistance = 0;
    for (int i = 0; i < _waypoints.length - 1; i++) {
      totalDistance += _distanceCalculator(_waypoints[i], _waypoints[i + 1]);
    }
    return totalDistance;
  }
  
  /// Форматирует расстояние для отображения
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} м';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(2)} км';
    }
  }
  
  /// Рассчитывает примерное время ходьбы (средняя скорость 5 км/ч)
  String _estimateWalkTime(double meters) {
    if (meters < 100) return '< 1 мин';
    
    // Средняя скорость ходьбы ~5 км/ч = 83.3 м/мин
    final minutes = (meters / 83.3).round();
    
    if (minutes < 60) {
      return '~$minutes мин';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '~$hours ч';
      }
      return '~$hours ч $mins мин';
    }
  }
  
  Future<void> _downloadTiles() async {
    if (_waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одну точку маршрута'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_selectedZoomLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы один уровень масштаба'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadedTiles = 0;
      _totalTiles = 0;
      _statusMessage = 'Подготовка к загрузке...';
    });
    
    final zoomLevels = _selectedZoomLevels.toList()..sort();
    
    final result = await _tileCacheService.downloadTilesAlongRoute(
      routePoints: _waypoints,
      zoomLevels: zoomLevels,
      bufferMeters: _bufferMeters,
      onProgress: (progress, downloaded, total) {
        setState(() {
          _downloadProgress = progress;
          _downloadedTiles = downloaded;
          _totalTiles = total;
          _statusMessage = 'Загрузка: $downloaded/$total тайлов (${(progress * 100).toStringAsFixed(0)}%)';
        });
      },
    );
    
    setState(() {
      _isDownloading = false;
    });
    
    if (result.success) {
      // Обновляем статистику
      final stats = await _tileCacheService.getCacheStats();
      setState(() {
        _cacheStats = stats;
        _statusMessage = 'Готово! Загружено ${result.tilesDownloaded} тайлов';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Карты успешно загружены! ${result.tilesDownloaded} тайлов'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() {
        _statusMessage = 'Ошибка: ${result.error}';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _downloadCurrentArea() async {
    if (_isDownloading) return;
    
    final bounds = _mapController.camera.visibleBounds;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Загрузка текущей области...';
      _downloadedTiles = 0;
      _totalTiles = 0;
    });
    
    final zoomLevels = _selectedZoomLevels.toList()..sort();
    
    final result = await _tileCacheService.downloadVisibleArea(
      bounds: bounds,
      zoomLevels: zoomLevels,
      onProgress: (progress, downloaded, total) {
        setState(() {
          _downloadProgress = progress;
          _downloadedTiles = downloaded;
          _totalTiles = total;
          _statusMessage = 'Загрузка: $downloaded/$total тайлов (${(progress * 100).toStringAsFixed(0)}%)';
        });
      },
    );
    
    setState(() {
      _isDownloading = false;
    });
    
    if (result.success) {
      final stats = await _tileCacheService.getCacheStats();
      setState(() {
        _cacheStats = stats;
        _statusMessage = 'Готово! Загружено ${result.tilesDownloaded} тайлов';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Область загружена! ${result.tilesDownloaded} тайлов'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() {
        _statusMessage = 'Ошибка: ${result.error}';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить кэш?'),
        content: Text('Будут удалены все ${_cacheStats?.tileCount ?? 0} загруженных тайлов (${_cacheStats?.formattedSize ?? '0 Б'}).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _tileCacheService.clearCache();
      final stats = await _tileCacheService.getCacheStats();
      setState(() {
        _cacheStats = stats;
        _statusMessage = 'Кэш очищен';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Кэш очищен'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Настройки загрузки'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Уровни масштаба:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [13, 14, 15, 16, 17, 18].map((zoom) {
                    final isSelected = _selectedZoomLevels.contains(zoom);
                    return FilterChip(
                      label: Text('z$zoom'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _selectedZoomLevels.add(zoom);
                          } else {
                            _selectedZoomLevels.remove(zoom);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Буфер вокруг маршрута:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _bufferMeters,
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '${_bufferMeters.toInt()} м',
                  onChanged: (value) {
                    setDialogState(() {
                      _bufferMeters = value;
                    });
                    setState(() {});
                  },
                ),
                Text(
                  'Загружать тайлы на ${_bufferMeters.toInt()} м вокруг маршрута',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Показываем индикатор загрузки пока позиция не получена
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Кэширование карт'),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Определение местоположения...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кэширование карт'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _isDownloading ? null : _showSettingsDialog,
            tooltip: 'Настройки',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _isDownloading ? null : _clearCache,
            tooltip: 'Очистить кэш',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Карта
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(55.7558, 37.6173),
              initialZoom: _currentZoom,
              onTap: _onMapTap,
            ),
            children: [
              // Слой тайлов
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.progulkin',
                maxZoom: 19,
              ),
              // Слой маршрута
              if (_waypoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _waypoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // Маркеры точек
              if (_waypoints.isNotEmpty)
                MarkerLayer(
                  markers: _waypoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final point = entry.value;
                    final isFirst = index == 0;
                    final isLast = index == _waypoints.length - 1;
                    
                    return Marker(
                      point: point,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _waypoints.removeAt(index);
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
              // Маркер текущей позиции
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Верхняя панель с информацией
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage ?? 'Загрузка...',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    if (_waypoints.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.route,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Точек: ${_waypoints.length}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_waypoints.length >= 2) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.straighten,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDistance(_calculateRouteDistance()),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _estimateWalkTime(_calculateRouteDistance()),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (_isDownloading) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_downloadedTiles / $_totalTiles тайлов',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Нижняя панель с кнопками
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Подсказка
                    Text(
                      'Нажмите на карту, чтобы добавить точки маршрута',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Кнопки управления точками
                    if (_waypoints.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: _isDownloading ? null : _undoLastPoint,
                            icon: const Icon(Icons.undo),
                            label: const Text('Отменить'),
                          ),
                          TextButton.icon(
                            onPressed: _isDownloading ? null : _clearRoute,
                            icon: const Icon(Icons.clear),
                            label: const Text('Очистить'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    // Основные кнопки
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isDownloading ? null : _downloadCurrentArea,
                            icon: const Icon(Icons.map),
                            label: const Text('Текущая область'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDownloading ? null : _downloadTiles,
                            icon: _isDownloading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download),
                            label: Text(_isDownloading ? 'Загрузка...' : 'Загрузить маршрут'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
