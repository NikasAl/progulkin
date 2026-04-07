import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_objects/creature.dart';

/// Кэшированный результат анализа habitat для тайла
class CachedHabitatTile {
  final int x;
  final int y;
  final int zoom;
  final CreatureHabitat habitat;
  final int red;
  final int green;
  final int blue;
  final DateTime cachedAt;

  const CachedHabitatTile({
    required this.x,
    required this.y,
    required this.zoom,
    required this.habitat,
    required this.red,
    required this.green,
    required this.blue,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'zoom': zoom,
    'habitat': habitat.index,
    'r': red,
    'g': green,
    'b': blue,
    'at': cachedAt.millisecondsSinceEpoch,
  };

  factory CachedHabitatTile.fromJson(Map<String, dynamic> json) {
    return CachedHabitatTile(
      x: json['x'] as int,
      y: json['y'] as int,
      zoom: json['zoom'] as int,
      habitat: CreatureHabitat.values[json['habitat'] as int],
      red: json['r'] as int,
      green: json['g'] as int,
      blue: json['b'] as int,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
    );
  }

  String get key => '${zoom}_${x}_$y';
}

/// Сервис для кэширования результатов анализа habitats
/// Позволяет предварительно проанализировать область и использовать результаты офлайн
class HabitatCacheService {
  static final HabitatCacheService _instance = HabitatCacheService._internal();
  factory HabitatCacheService() => _instance;
  HabitatCacheService._internal();

  /// Ключ для SharedPreferences
  static const String _prefsKey = 'habitat_tiles_cache';

  /// URL шаблон для тайлов OSM
  static const String _tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// In-memory кэш тайлов
  final Map<String, CachedHabitatTile> _tilesCache = {};

  /// Инициализирован ли кэш
  bool _isInitialized = false;

  /// Инициализировать кэш из постоянного хранилища
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);

      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        for (final json in jsonList) {
          final tile = CachedHabitatTile.fromJson(json as Map<String, dynamic>);
          _tilesCache[tile.key] = tile;
        }
        debugPrint('HabitatCacheService: Загружено ${_tilesCache.length} тайлов из кэша');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('HabitatCacheService: Ошибка загрузки кэша: $e');
      _isInitialized = true;
    }
  }

  /// Сохранить кэш в постоянное хранилище
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _tilesCache.values.map((t) => t.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(jsonList));
      debugPrint('HabitatCacheService: Сохранено ${_tilesCache.length} тайлов в кэш');
    } catch (e) {
      debugPrint('HabitatCacheService: Ошибка сохранения кэша: $e');
    }
  }

  /// Получить habitat для координаты из кэша
  CachedHabitatTile? getHabitatForLocation(double lat, double lng, {int zoom = 15}) {
    final coords = _latLngToTileCoords(lat, lng, zoom);
    final key = '${zoom}_${coords.x}_${coords.y}';
    return _tilesCache[key];
  }

  /// Получить habitat для координаты с интерполяцией (ищем ближайшие тайлы)
  CreatureHabitat? getHabitatWithInterpolation(double lat, double lng, {int zoom = 15}) {
    final tile = getTileWithInterpolation(lat, lng, zoom: zoom);
    return tile?.habitat;
  }

  /// Получить полный tile с RGB для координаты с интерполяцией (ищем ближайшие тайлы)
  CachedHabitatTile? getTileWithInterpolation(double lat, double lng, {int zoom = 15}) {
    // Сначала точное совпадение
    final exact = getHabitatForLocation(lat, lng, zoom: zoom);
    if (exact != null) {
      return exact;
    }

    // Ищем в соседних тайлах
    final coords = _latLngToTileCoords(lat, lng, zoom);
    final neighborTiles = <CachedHabitatTile>[];

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        final key = '${zoom}_${coords.x + dx}_${coords.y + dy}';
        final tile = _tilesCache[key];
        if (tile != null) {
          neighborTiles.add(tile);
        }
      }
    }

    if (neighborTiles.isEmpty) {
      return null;
    }

    // Возвращаем самый частый habitat среди соседей
    final counts = <CreatureHabitat, int>{};
    for (final tile in neighborTiles) {
      counts[tile.habitat] = (counts[tile.habitat] ?? 0) + 1;
    }

    CreatureHabitat bestHabitat = neighborTiles.first.habitat;
    int bestCount = 0;
    counts.forEach((h, c) {
      if (c > bestCount) {
        bestCount = c;
        bestHabitat = h;
      }
    });

    // Возвращаем первый tile с наиболее частым habitat
    // (его RGB будет использоваться для отображения)
    for (final tile in neighborTiles) {
      if (tile.habitat == bestHabitat) {
        return tile;
      }
    }

    return neighborTiles.first;
  }

  /// Скачать и проанализировать тайлы для области
  /// Возвращает количество проанализированных тайлов
  Future<int> downloadAndAnalyzeArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    int zoom = 15,
    Function(int current, int total)? onProgress,
  }) async {
    // Вычисляем границы тайлов
    final topLeft = _latLngToTileCoords(maxLat, minLon, zoom);
    final bottomRight = _latLngToTileCoords(minLat, maxLon, zoom);

    final minX = topLeft.x;
    final maxX = bottomRight.x;
    final minY = topLeft.y;
    final maxY = bottomRight.y;

    final totalTiles = (maxX - minX + 1) * (maxY - minY + 1);
    int currentTile = 0;
    int analyzedTiles = 0;

    debugPrint('HabitatCacheService: Анализ области $totalTiles тайлов (zoom $zoom)');

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        currentTile++;
        onProgress?.call(currentTile, totalTiles);

        // Пропускаем если уже в кэше
        final key = '${zoom}_${x}_$y';
        if (_tilesCache.containsKey(key)) {
          continue;
        }

        // Скачиваем и анализируем тайл
        final tile = await _downloadAndAnalyzeTile(x, y, zoom);
        if (tile != null) {
          _tilesCache[key] = tile;
          analyzedTiles++;
        }

        // Небольшая пауза чтобы не перегрузить сервер
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    // Сохраняем в постоянное хранилище
    await _saveToPrefs();

    debugPrint('HabitatCacheService: Проанализировано $analyzedTiles новых тайлов');
    return analyzedTiles;
  }

  /// Скачать и проанализировать один тайл
  Future<CachedHabitatTile?> _downloadAndAnalyzeTile(int x, int y, int zoom) async {
    final tileUrl = _tileUrlTemplate
        .replaceAll('{z}', zoom.toString())
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString());

    try {
      final response = await http.get(
        Uri.parse(tileUrl),
        headers: {
          'User-Agent': 'Progulkin/1.0 (https://github.com/progulkin)',
          'Accept': 'image/png',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final bytes = response.bodyBytes;

      // Анализируем центр тайла
      final analysis = _analyzeTileBytes(bytes);
      if (analysis == null) {
        return null;
      }

      return CachedHabitatTile(
        x: x,
        y: y,
        zoom: zoom,
        habitat: analysis.habitat,
        red: analysis.r,
        green: analysis.g,
        blue: analysis.b,
        cachedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('HabitatCacheService: Ошибка загрузки тайла $tileUrl: $e');
      return null;
    }
  }

  /// Анализировать байты тайла
  _ColorAnalysis? _analyzeTileBytes(Uint8List bytes) {
    try {
      final image = img.decodePng(bytes);
      if (image == null) return null;

      // Анализируем центр тайла и surrounding area
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;

      // Берём средний цвет из области 20x20 в центре
      int totalR = 0, totalG = 0, totalB = 0;
      int count = 0;
      const radius = 10;

      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          final px = (centerX + dx).clamp(0, image.width - 1);
          final py = (centerY + dy).clamp(0, image.height - 1);
          final pixel = image.getPixel(px, py);
          totalR += pixel.r.toInt();
          totalG += pixel.g.toInt();
          totalB += pixel.b.toInt();
          count++;
        }
      }

      final avgR = totalR ~/ count;
      final avgG = totalG ~/ count;
      final avgB = totalB ~/ count;

      // Конвертируем в HSL
      final hsl = _rgbToHsl(avgR, avgG, avgB);

      // Определяем habitat по цвету
      final habitat = _mapColorToHabitat(hsl);

      return _ColorAnalysis(r: avgR, g: avgG, b: avgB, habitat: habitat);
    } catch (e) {
      return null;
    }
  }

  /// Маппинг цвета на habitat
  /// Основано на реальных цветах OpenStreetMap Carto:
  /// - Лес: RGB(203,217,181)/RGB(176,211,163) → HSL(83-104°, 32-35%, 73-78%)
  /// - Поле: RGB(236,236,208)/RGB(238,240,213) → HSL(60-64°, 42-47%, 87-89%)
  /// - Город: RGB(212,198,205)/RGB(241,239,236) → HSL(36-337°, 14-17%, 80-94%)
  /// - Вода: RGB(171,210,222)/RGB(170,211,223) → HSL(194°, 44-45%, 77%)
  CreatureHabitat _mapColorToHabitat(_HSL hsl) {
    final h = hsl.hue;
    final s = hsl.saturation;
    final l = hsl.lightness;

    // === ВОДА (голубой/синий) ===
    // HSL(194°, 44-45%, 77%)
    if (h >= 185 && h <= 215 && s > 0.30 && l > 0.65 && l < 0.85) {
      return CreatureHabitat.water;
    }

    // === ЛЕС (зелёный) ===
    // HSL(83-104°, 32-35%, 73-78%)
    if (h >= 70 && h <= 130 && s >= 0.25 && s <= 0.50 && l >= 0.65 && l <= 0.85) {
      return CreatureHabitat.forest;
    }

    // === ПОЛЕ (жёлто-зелёный, светло-жёлтый) ===
    // HSL(60-64°, 42-47%, 87-89%)
    if (h >= 50 && h <= 80 && s >= 0.30 && s <= 0.55 && l >= 0.80 && l <= 0.95) {
      return CreatureHabitat.field;
    }

    // Дополнительный зелёный для поля (менее насыщенный)
    if (h >= 70 && h <= 130 && s >= 0.15 && s < 0.25 && l >= 0.70 && l <= 0.90) {
      return CreatureHabitat.field;
    }

    // === БОЛОТО (тёмный жёлто-зелёный) ===
    if (h >= 60 && h <= 100 && s >= 0.10 && s <= 0.40 && l >= 0.40 && l <= 0.65) {
      return CreatureHabitat.swamp;
    }

    // === ГОРОД (серый, бежевый, розоватый - низкая насыщенность) ===
    // HSL(36-337°, 14-17%, 80-94%)
    if (s <= 0.22 && l >= 0.70 && l <= 0.98) {
      return CreatureHabitat.city;
    }

    // === ЗДАНИЯ/ДОМА (розоватый, коричневатый - более насыщенные) ===
    if (h >= 0 && h <= 40 && s > 0.22 && l > 0.40 && l < 0.70) {
      if (s > 0.30 && l > 0.45 && l < 0.65) {
        return CreatureHabitat.home;
      }
      return CreatureHabitat.city;
    }

    // По умолчанию - город
    return CreatureHabitat.city;
  }

  /// Конвертация lat/lng в координаты тайла
  _TileCoords _latLngToTileCoords(double lat, double lng, int zoom) {
    final n = math.pow(2, zoom).toDouble();
    final x = ((lng + 180) / 360 * n).floor();
    final y = ((1 - math.log(math.tan(lat * math.pi / 180) +
                1 / math.cos(lat * math.pi / 180)) /
            math.pi) /
        2 *
        n)
        .floor();
    return _TileCoords(x: x, y: y);
  }

  /// Конвертация RGB в HSL
  _HSL _rgbToHsl(int r, int g, int b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final max = math.max(rNorm, math.max(gNorm, bNorm));
    final min = math.min(rNorm, math.min(gNorm, bNorm));
    final delta = max - min;

    double h = 0;
    double s = 0;
    final l = (max + min) / 2;

    if (delta > 0) {
      s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);

      if (max == rNorm) {
        h = ((gNorm - bNorm) / delta + (gNorm < bNorm ? 6 : 0)) * 60;
      } else if (max == gNorm) {
        h = ((bNorm - rNorm) / delta + 2) * 60;
      } else {
        h = ((rNorm - gNorm) / delta + 4) * 60;
      }
    }

    return _HSL(hue: h, saturation: s, lightness: l);
  }

  /// Получить статистику кэша
  Map<String, dynamic> getStats() {
    final habitatCounts = <CreatureHabitat, int>{};
    for (final tile in _tilesCache.values) {
      habitatCounts[tile.habitat] = (habitatCounts[tile.habitat] ?? 0) + 1;
    }

    return {
      'totalTiles': _tilesCache.length,
      'byHabitat': habitatCounts.map((k, v) => MapEntry(k.name, v)),
    };
  }

  /// Очистить кэш
  Future<void> clearCache() async {
    _tilesCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      debugPrint('HabitatCacheService: Кэш очищен');
    } catch (e) {
      debugPrint('HabitatCacheService: Ошибка очистки кэша: $e');
    }
  }
}

/// Вспомогательные классы
class _TileCoords {
  final int x;
  final int y;
  const _TileCoords({required this.x, required this.y});
}

class _HSL {
  final double hue;
  final double saturation;
  final double lightness;
  const _HSL({required this.hue, required this.saturation, required this.lightness});
}

class _ColorAnalysis {
  final int r;
  final int g;
  final int b;
  final CreatureHabitat habitat;
  const _ColorAnalysis({required this.r, required this.g, required this.b, required this.habitat});
}
