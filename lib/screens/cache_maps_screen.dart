import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/tile_cache_service.dart';
import '../services/location_service.dart';
import '../di/service_locator.dart';

/// Экран кэширования карт для оффлайн-доступа
class CacheMapsScreen extends StatefulWidget {
  const CacheMapsScreen({super.key});

  @override
  State<CacheMapsScreen> createState() => _CacheMapsScreenState();
}

class _CacheMapsScreenState extends State<CacheMapsScreen> {
  final MapController _mapController = MapController();
  final TileCacheService _tileCacheService = getIt<TileCacheService>();
  final LocationService _locationService = getIt<LocationService>();

  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedTiles = 0;
  int _totalTiles = 0;
  String? _statusMessage;
  CacheStats? _cacheStats;

  // Настройки загрузки
  final Set<int> _selectedZoomLevels = {14, 15, 16, 17};

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    try {
      await _tileCacheService.init();

      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _currentPosition = LatLng(position.latitude, position.longitude);
      }

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
                Text(
                  'Чем больше уровней, тем больше тайлов будет загружено.',
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Кэширование карт')),
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
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ru.kreagenium.progulkin',
                maxZoom: 19,
              ),
              // Маркер текущей позиции
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

          // Нижняя панель с кнопкой
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
                    Text(
                      'Переместите карту в нужную область и нажмите "Загрузить"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _downloadCurrentArea,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download),
                        label: Text(_isDownloading ? 'Загрузка...' : 'Загрузить видимую область'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
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
