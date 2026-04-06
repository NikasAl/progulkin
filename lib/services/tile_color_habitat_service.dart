import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/map_objects/creature.dart';

/// Результат определения среды обитания по цвету тайла
class TileColorHabitatResult {
  final CreatureHabitat primaryHabitat;
  final Map<CreatureHabitat, double> habitatScores;
  final ColorAnalysis colorAnalysis;
  final bool fromCache;
  final DateTime detectedAt;

  const TileColorHabitatResult({
    required this.primaryHabitat,
    required this.habitatScores,
    required this.colorAnalysis,
    this.fromCache = false,
    required this.detectedAt,
  });
}

/// Анализ цвета пикселя
class ColorAnalysis {
  final int red;
  final int green;
  final int blue;
  final double hue;
  final double saturation;
  final double lightness;
  final String colorName;

  const ColorAnalysis({
    required this.red,
    required this.green,
    required this.blue,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.colorName,
  });
}

/// Сервис для определения среды обитания по цвету пикселей на тайлах карты
/// Работает офлайн, используя кэшированные тайлы
class TileColorHabitatService {
  static final TileColorHabitatService _instance = TileColorHabitatService._internal();
  factory TileColorHabitatService() => _instance;
  TileColorHabitatService._internal();

  /// Имя хранилища кэша тайлов
  static const String _storeName = 'progulkin_map_cache';

  /// URL шаблон для тайлов OSM
  static const String _tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Кэш результатов по geohash
  final Map<String, TileColorHabitatResult> _cache = {};

  /// Время жизни кэша (10 минут)
  static const Duration cacheLifetime = Duration(minutes: 10);

  /// Уровень масштаба для анализа (15 = ~4.8м на пиксель, хороший баланс)
  static const int _analysisZoom = 15;

  /// Размер тайла OSM в пикселях
  static const int _tileSize = 256;

  /// Определить среду обитания по координатам
  Future<TileColorHabitatResult?> detectHabitat(
    double latitude,
    double longitude,
  ) async {
    // Проверяем кэш
    final geohash = _computeGeohash(latitude, longitude, 7);
    final cached = _cache[geohash];
    if (cached != null) {
      final age = DateTime.now().difference(cached.detectedAt);
      if (age < cacheLifetime) {
        return TileColorHabitatResult(
          primaryHabitat: cached.primaryHabitat,
          habitatScores: cached.habitatScores,
          colorAnalysis: cached.colorAnalysis,
          fromCache: true,
          detectedAt: cached.detectedAt,
        );
      }
    }

    try {
      // Загружаем тайл и анализируем цвет
      final tileBytes = await _loadTile(latitude, longitude, _analysisZoom);
      if (tileBytes == null) {
        debugPrint('⚠️ Не удалось загрузить тайл для ($latitude, $longitude)');
        return null;
      }

      // Анализируем цвета в области вокруг точки
      final result = await _analyzeTileColors(
        tileBytes,
        latitude,
        longitude,
        _analysisZoom,
      );

      if (result != null) {
        _cache[geohash] = result;
      }

      return result;
    } catch (e) {
      debugPrint('⚠️ Ошибка определения среды по тайлу: $e');
      return null;
    }
  }

  /// Загрузить тайл из кэша или скачать
  Future<Uint8List?> _loadTile(double lat, double lng, int zoom) async {
    // Вычисляем координаты тайла
    final tileCoords = _latLngToTileCoords(lat, lng, zoom);
    final tileUrl = _tileUrlTemplate
        .replaceAll('{z}', zoom.toString())
        .replaceAll('{x}', tileCoords.x.toString())
        .replaceAll('{y}', tileCoords.y.toString());

    debugPrint('🗺️ Загрузка тайла: $tileUrl');

    // Пробуем загрузить из кэша
    try {
      final cachedTile = await FMTCBackendAccess.internal.readTile(
        url: tileUrl,
        storeName: _storeName,
      );

      if (cachedTile != null) {
        debugPrint('✅ Тайл найден в кэше');
        return cachedTile.bytes;
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка чтения из кэша: $e');
    }

    // Если нет в кэше - скачиваем
    debugPrint('⬇️ Скачиваем тайл...');
    try {
      final response = await http.get(
        Uri.parse(tileUrl),
        headers: {
          'User-Agent': 'Progulkin/1.0 (https://github.com/progulkin)',
          'Accept': 'image/png',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Тайл скачан (${response.bodyBytes.length} байт)');
        return response.bodyBytes;
      } else {
        debugPrint('⚠️ Ошибка скачивания: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка скачивания тайла: $e');
    }

    return null;
  }

  /// Анализировать цвета тайла и определить среду обитания
  Future<TileColorHabitatResult?> _analyzeTileColors(
    Uint8List tileBytes,
    double lat,
    double lng,
    int zoom,
  ) async {
    try {
      // Декодируем PNG
      final image = img.decodePng(tileBytes);
      if (image == null) {
        debugPrint('⚠️ Не удалось декодировать PNG');
        return null;
      }

      // Вычисляем позицию пикселя внутри тайла
      final pixelPos = _latLngToPixelInTile(lat, lng, zoom);

      // Берём средний цвет из области 5x5 пикселей вокруг точки
      final avgColor = _getAverageColorAround(image, pixelPos.x, pixelPos.y, 5);

      // Анализируем цвет
      final colorAnalysis = _analyzeColor(avgColor);

      // Маппинг цвета на среду обитания
      final habitatScores = _mapColorToHabitat(colorAnalysis);

      // Находим основную среду
      CreatureHabitat primaryHabitat = CreatureHabitat.city;
      double maxScore = 0;
      habitatScores.forEach((habitat, score) {
        if (score > maxScore) {
          maxScore = score;
          primaryHabitat = habitat;
        }
      });

      debugPrint('🎨 Цвет: RGB(${avgColor.r}, ${avgColor.g}, ${avgColor.b}) '
          'HSL(${colorAnalysis.hue.toStringAsFixed(0)}°, '
          '${(colorAnalysis.saturation * 100).toStringAsFixed(0)}%, '
          '${(colorAnalysis.lightness * 100).toStringAsFixed(0)}%)');
      debugPrint('🏷️ Определённый тип: ${colorAnalysis.colorName}');
      debugPrint('🦊 Среда: ${primaryHabitat.emoji} ${primaryHabitat.name}');

      return TileColorHabitatResult(
        primaryHabitat: primaryHabitat,
        habitatScores: habitatScores,
        colorAnalysis: colorAnalysis,
        detectedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('⚠️ Ошибка анализа тайла: $e');
      return null;
    }
  }

  /// Получить средний цвет вокруг точки
  _AvgColor _getAverageColorAround(img.Image image, int centerX, int centerY, int radius) {
    int totalR = 0, totalG = 0, totalB = 0;
    int count = 0;

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final x = (centerX + dx).clamp(0, image.width - 1);
        final y = (centerY + dy).clamp(0, image.height - 1);

        final pixel = image.getPixel(x, y);
        totalR += pixel.r.toInt();
        totalG += pixel.g.toInt();
        totalB += pixel.b.toInt();
        count++;
      }
    }

    return _AvgColor(
      r: totalR ~/ count,
      g: totalG ~/ count,
      b: totalB ~/ count,
    );
  }

  /// Анализировать цвет и определить его название
  ColorAnalysis _analyzeColor(_AvgColor color) {
    // Конвертируем RGB в HSL
    final hsl = _rgbToHsl(color.r, color.g, color.b);

    String colorName;

    // Определяем тип цвета по HSL
    if (hsl.saturation < 0.1) {
      // Ненасыщенные цвета - серые/белые/чёрные
      if (hsl.lightness > 0.8) {
        colorName = 'white';
      } else if (hsl.lightness < 0.2) {
        colorName = 'black';
      } else {
        colorName = 'gray';
      }
    } else if (hsl.hue >= 0 && hsl.hue < 15) {
      colorName = 'red';
    } else if (hsl.hue >= 15 && hsl.hue < 45) {
      colorName = 'orange';
    } else if (hsl.hue >= 45 && hsl.hue < 75) {
      colorName = 'yellow';
    } else if (hsl.hue >= 75 && hsl.hue < 165) {
      colorName = 'green';
    } else if (hsl.hue >= 165 && hsl.hue < 195) {
      colorName = 'cyan';
    } else if (hsl.hue >= 195 && hsl.hue < 255) {
      colorName = 'blue';
    } else if (hsl.hue >= 255 && hsl.hue < 285) {
      colorName = 'purple';
    } else if (hsl.hue >= 285 && hsl.hue < 330) {
      colorName = 'magenta';
    } else {
      colorName = 'red';
    }

    return ColorAnalysis(
      red: color.r,
      green: color.g,
      blue: color.b,
      hue: hsl.hue,
      saturation: hsl.saturation,
      lightness: hsl.lightness,
      colorName: colorName,
    );
  }

  /// Маппинг цвета на среды обитания
  /// Основано на стандартных цветах OpenStreetMap Carto
  Map<CreatureHabitat, double> _mapColorToHabitat(ColorAnalysis color) {
    final scores = <CreatureHabitat, double>{};
    final h = color.hue;
    final s = color.saturation;
    final l = color.lightness;

    // === ЛЕС (густой зелёный) ===
    // OSM: #A0D8A0, #8BC34A, #7DBD4C, #A0C890
    if (h >= 75 && h <= 165 && s > 0.2 && l > 0.25 && l < 0.7) {
      // Насыщенный зелёный - лес
      if (s > 0.35 && l > 0.35 && l < 0.65) {
        scores[CreatureHabitat.forest] = 1.0;
        scores[CreatureHabitat.field] = 0.3;
      } else {
        // Менее насыщенный - поле/парк
        scores[CreatureHabitat.field] = 0.8;
        scores[CreatureHabitat.forest] = 0.3;
      }
    }

    // === ВОДА (синий, голубой) ===
    // OSM: #A0CFF0, #74B0E0, #9FC5E8, #7DC4E0
    if (h >= 185 && h <= 250 && s > 0.15 && l > 0.3 && l < 0.8) {
      scores[CreatureHabitat.water] = 1.0;
    }

    // === БОЛОТО (болотистый зелёный/коричневый) ===
    // OSM: #B8D0A0, #9DBD78 (wetland)
    if (h >= 60 && h <= 100 && s > 0.1 && s < 0.5 && l > 0.4 && l < 0.7) {
      // Тусклый жёлто-зелёный
      scores[CreatureHabitat.swamp] = 0.7;
      scores[CreatureHabitat.forest] = 0.3;
    }

    // === ПОЛЕ / ЛУГ (светло-зелёный, жёлто-зелёный) ===
    // OSM: #CFD8A0, #C8D8B0, #E8E0B0 (farmland, meadow)
    if (h >= 50 && h <= 100 && s > 0.05 && s < 0.4 && l > 0.5 && l < 0.85) {
      scores[CreatureHabitat.field] = 0.9;
    }

    // === ПАРКИ (светлый зелёный) ===
    // OSM: #C0E8B0, #D5E8D0 (leisure=park)
    if (h >= 75 && h <= 150 && s > 0.1 && s < 0.45 && l > 0.6) {
      scores[CreatureHabitat.field] = 0.7;
      scores[CreatureHabitat.city] = 0.2;
    }

    // === ГОРОД (серый, бежевый, розоватый) ===
    // OSM: #D9D0C6, #E5D0C5, #E0D8D0 (residential)
    // OSM: #CCCCCC, #D0D0D0 (industrial)
    if (s < 0.15 && l > 0.5 && l < 0.9) {
      // Ненасыщенный светлый - городская застройка
      scores[CreatureHabitat.city] = 0.9;
      scores[CreatureHabitat.home] = 0.2;
    }

    // === ЗДАНИЯ (розоватый, коричневатый) ===
    // OSM: #D99079, #CC7E6D, #D48D6D (buildings)
    if (h >= 0 && h <= 40 && s > 0.2 && l > 0.4 && l < 0.7) {
      scores[CreatureHabitat.city] = 0.8;
      scores[CreatureHabitat.home] = 0.4;
    }

    // === ДОМА (более насыщенные розовые/коричневые) ===
    if (h >= 10 && h <= 35 && s > 0.3 && l > 0.45 && l < 0.65) {
      scores[CreatureHabitat.home] = 0.7;
      scores[CreatureHabitat.city] = 0.5;
    }

    // === ПЕСЧАНЫЕ / ПУСТЫННЫЕ (жёлтый, бежевый) ===
    // OSM: #E8D8A0, #E0D090 (sand, beach)
    if (h >= 35 && h <= 60 && s > 0.1 && s < 0.4 && l > 0.6) {
      scores[CreatureHabitat.field] = 0.6;
      scores[CreatureHabitat.mountain] = 0.2;
    }

    // === ГОРЫ (серый, коричневатый серый) ===
    // OSM: #C0C0C0, #B0A090 (bare_rock, scree)
    if (s < 0.15 && l > 0.35 && l < 0.65) {
      if ((scores[CreatureHabitat.city] ?? 0) < 0.5) {
        scores[CreatureHabitat.mountain] = 0.3;
      }
    }

    // Если ничего не определилось - город по умолчанию
    if (scores.isEmpty) {
      scores[CreatureHabitat.city] = 0.7;
      scores[CreatureHabitat.anywhere] = 0.3;
    }

    // Нормализуем scores
    final maxScore = scores.values.fold(0.0, (max, v) => v > max ? v : max);
    if (maxScore > 0) {
      scores.updateAll((key, value) => value / maxScore);
    }

    return scores;
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

  /// Конвертация lat/lng в позицию пикселя внутри тайла
  _PixelPos _latLngToPixelInTile(double lat, double lng, int zoom) {
    final n = math.pow(2, zoom).toDouble();

    // Дробные координаты тайла
    final tileX = (lng + 180) / 360 * n;
    final tileY = (1 - math.log(math.tan(lat * math.pi / 180) +
                1 / math.cos(lat * math.pi / 180)) /
            math.pi) /
        2 *
        n;

    // Позиция пикселя внутри тайла
    final pixelX = ((tileX - tileX.floor()) * _tileSize).round();
    final pixelY = ((tileY - tileY.floor()) * _tileSize).round();

    return _PixelPos(
      x: pixelX.clamp(0, _tileSize - 1),
      y: pixelY.clamp(0, _tileSize - 1),
    );
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

  /// Вычислить простой geohash
  String _computeGeohash(double lat, double lng, int precision) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    final result = StringBuffer();

    double minLat = -90, maxLat = 90;
    double minLng = -180, maxLng = 180;

    int bit = 0;
    int ch = 0;

    while (result.length < precision) {
      if (bit % 2 == 0) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          ch |= (1 << (4 - bit % 5));
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          ch |= (1 << (4 - bit % 5));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      bit++;
      if (bit % 5 == 0) {
        result.write(base32[ch]);
        ch = 0;
      }
    }

    return result.toString();
  }

  /// Очистить кэш
  void clearCache() {
    _cache.clear();
  }
}

/// Вспомогательные классы
class _TileCoords {
  final int x;
  final int y;
  const _TileCoords({required this.x, required this.y});
}

class _PixelPos {
  final int x;
  final int y;
  const _PixelPos({required this.x, required this.y});
}

class _AvgColor {
  final int r;
  final int g;
  final int b;
  const _AvgColor({required this.r, required this.g, required this.b});
}

class _HSL {
  final double hue;
  final double saturation;
  final double lightness;
  const _HSL({required this.hue, required this.saturation, required this.lightness});
}
