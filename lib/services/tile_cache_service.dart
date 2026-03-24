import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

/// Сервис для кэширования тайлов карт для оффлайн использования
class TileCacheService {
  static const String _storeName = 'progulkin_map_cache';
  static const String _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  
  bool _isInitialized = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedTiles = 0;
  int _totalTiles = 0;
  String? _currentDownloadArea;
  
  // Геттеры
  bool get isInitialized => _isInitialized;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  int get downloadedTiles => _downloadedTiles;
  int get totalTiles => _totalTiles;
  String? get currentDownloadArea => _currentDownloadArea;
  
  /// Инициализация хранилища кэша
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Инициализируем глобальную систему кэширования
      await FMTCObjectBoxBackend().initialise();
      
      // Создаём или открываем хранилище
      final store = FMTCStore(_storeName);
      await store.manage.create();
      
      _isInitialized = true;
      debugPrint('TileCacheService: Инициализирован успешно');
    } catch (e) {
      debugPrint('TileCacheService: Ошибка инициализации: $e');
      // Не пробрасываем ошибку, чтобы приложение могло работать без кэша
      _isInitialized = false;
    }
  }
  
  /// Получить провайдер тайлов с поддержкой кэша
  TileProvider? getTileProvider() {
    if (!_isInitialized) {
      return null;
    }
    
    try {
      return FMTCStore(_storeName).getTileProvider();
    } catch (e) {
      debugPrint('TileCacheService: Ошибка получения провайдера: $e');
      return null;
    }
  }
  
  /// Получить статистику кэша
  Future<CacheStats> getCacheStats() async {
    if (!_isInitialized) {
      return const CacheStats(tileCount: 0, sizeBytes: 0);
    }
    
    try {
      final store = FMTCStore(_storeName);
      final stats = await store.stats.downloadStats();
      
      return CacheStats(
        tileCount: stats.cachedTiles,
        sizeBytes: stats.cachedSize,
      );
    } catch (e) {
      debugPrint('TileCacheService: Ошибка получения статистики: $e');
      return const CacheStats(tileCount: 0, sizeBytes: 0);
    }
  }
  
  /// Загрузить тайлы вдоль маршрута на разных уровнях масштаба
  /// 
  /// [routePoints] - точки маршрута
  /// [zoomLevels] - уровни масштаба (по умолчанию 13-17)
  /// [bufferMeters] - буфер вокруг маршрута в метрах (по умолчанию 200м)
  Future<DownloadResult> downloadTilesAlongRoute({
    required List<LatLng> routePoints,
    List<int> zoomLevels = const [13, 14, 15, 16, 17],
    double bufferMeters = 200,
    Function(double progress, int downloaded, int total)? onProgress,
  }) async {
    if (!_isInitialized) {
      return const DownloadResult(
        success: false,
        tilesDownloaded: 0,
        error: 'Сервис кэширования не инициализирован',
      );
    }
    
    if (routePoints.isEmpty) {
      return const DownloadResult(
        success: false,
        tilesDownloaded: 0,
        error: 'Маршрут пуст',
      );
    }
    
    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadedTiles = 0;
    _totalTiles = 0;
    
    try {
      // Находим границы маршрута с буфером
      double minLat = double.infinity;
      double maxLat = double.negativeInfinity;
      double minLon = double.infinity;
      double maxLon = double.negativeInfinity;
      
      for (final point in routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLon = math.min(minLon, point.longitude);
        maxLon = math.max(maxLon, point.longitude);
      }
      
      // Добавляем буфер (примерно 1 градус ≈ 111 км)
      final bufferDegrees = bufferMeters / 111000.0;
      minLat -= bufferDegrees;
      maxLat += bufferDegrees;
      minLon -= bufferDegrees;
      maxLon += bufferDegrees;
      
      _currentDownloadArea = 'Lat: ${minLat.toStringAsFixed(4)} - ${maxLat.toStringAsFixed(4)}, '
          'Lon: ${minLon.toStringAsFixed(4)} - ${maxLon.toStringAsFixed(4)}';
      
      debugPrint('TileCacheService: Область загрузки: $_currentDownloadArea');
      
      final store = FMTCStore(_storeName);
      int totalDownloaded = 0;
      
      // Создаём область для загрузки
      final bounds = LatLngBounds(
        LatLng(minLat, minLon),
        LatLng(maxLat, maxLon),
      );
      
      // Загружаем для каждого уровня масштаба
      for (final zoom in zoomLevels) {
        debugPrint('TileCacheService: Загрузка zoom $zoom...');
        
        // Создаём регион для загрузки
        final region = RectangleRegion(bounds);
        
        final downloadable = region.toDownloadable(
          minZoom: zoom,
          maxZoom: zoom,
          options: TileLayer(
            urlTemplate: _tileUrl,
            userAgentPackageName: 'com.example.progulkin',
          ),
        );
        
        // Оценка количества тайлов
        _totalTiles += downloadable.totalTilesAndSize.totalTiles;
        
        // Запускаем загрузку
        try {
          final download = store.download.startForeground(
            downloadable,
            parallelThreads: 4,
            skipExistingTiles: true,
          );
          
          await for (final progress in download) {
            _downloadedTiles = progress.downloadedTiles.toInt();
            _downloadProgress = progress.downloadProgress;
            
            onProgress?.call(_downloadProgress, _downloadedTiles, _totalTiles);
            
            if (progress.isComplete) {
              totalDownloaded += progress.downloadedTiles.toInt();
              debugPrint('TileCacheService: Zoom $zoom завершён, загружено ${progress.downloadedTiles} тайлов');
            }
          }
        } catch (e) {
          debugPrint('TileCacheService: Ошибка загрузки zoom $zoom: $e');
          // Продолжаем с другим zoom
        }
      }
      
      _isDownloading = false;
      _currentDownloadArea = null;
      
      return DownloadResult(
        success: true,
        tilesDownloaded: totalDownloaded,
      );
    } catch (e) {
      _isDownloading = false;
      _currentDownloadArea = null;
      
      debugPrint('TileCacheService: Ошибка загрузки: $e');
      return DownloadResult(
        success: false,
        tilesDownloaded: 0,
        error: e.toString(),
      );
    }
  }
  
  /// Загрузить тайлы для текущей видимой области
  Future<DownloadResult> downloadVisibleArea({
    required LatLngBounds bounds,
    List<int> zoomLevels = const [14, 15, 16, 17],
    Function(double progress, int downloaded, int total)? onProgress,
  }) async {
    if (!_isInitialized) {
      return const DownloadResult(
        success: false,
        tilesDownloaded: 0,
        error: 'Сервис кэширования не инициализирован',
      );
    }
    
    _isDownloading = true;
    _downloadProgress = 0.0;
    
    try {
      final store = FMTCStore(_storeName);
      int totalDownloaded = 0;
      
      for (final zoom in zoomLevels) {
        final region = RectangleRegion(bounds);
        
        final downloadable = region.toDownloadable(
          minZoom: zoom,
          maxZoom: zoom,
          options: TileLayer(
            urlTemplate: _tileUrl,
            userAgentPackageName: 'com.example.progulkin',
          ),
        );
        
        _totalTiles += downloadable.totalTilesAndSize.totalTiles;
        
        try {
          final download = store.download.startForeground(
            downloadable,
            parallelThreads: 4,
            skipExistingTiles: true,
          );
          
          await for (final progress in download) {
            _downloadedTiles = progress.downloadedTiles.toInt();
            _downloadProgress = progress.downloadProgress;
            onProgress?.call(_downloadProgress, _downloadedTiles, _totalTiles);
            
            if (progress.isComplete) {
              totalDownloaded += progress.downloadedTiles.toInt();
            }
          }
        } catch (e) {
          debugPrint('TileCacheService: Ошибка загрузки zoom $zoom: $e');
        }
      }
      
      _isDownloading = false;
      
      return DownloadResult(
        success: true,
        tilesDownloaded: totalDownloaded,
      );
    } catch (e) {
      _isDownloading = false;
      
      return DownloadResult(
        success: false,
        tilesDownloaded: 0,
        error: e.toString(),
      );
    }
  }
  
  /// Очистить кэш
  Future<void> clearCache() async {
    if (!_isInitialized) return;
    
    try {
      final store = FMTCStore(_storeName);
      await store.manage.reset();
      debugPrint('TileCacheService: Кэш очищен');
    } catch (e) {
      debugPrint('TileCacheService: Ошибка очистки кэша: $e');
    }
  }
}

/// Статистика кэша
class CacheStats {
  final int tileCount;
  final int sizeBytes;
  
  const CacheStats({
    required this.tileCount,
    required this.sizeBytes,
  });
  
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes Б';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} КБ';
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
  }
}

/// Результат загрузки
class DownloadResult {
  final bool success;
  final int tilesDownloaded;
  final String? error;
  
  const DownloadResult({
    required this.success,
    required this.tilesDownloaded,
    this.error,
  });
}
