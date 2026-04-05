import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/map_objects/creature.dart';

/// Результат определения среды обитания
class HabitatDetectionResult {
  final CreatureHabitat primaryHabitat;
  final Map<CreatureHabitat, double> habitatScores;
  final bool fromCache;
  final DateTime detectedAt;

  const HabitatDetectionResult({
    required this.primaryHabitat,
    required this.habitatScores,
    this.fromCache = false,
    required this.detectedAt,
  });

  /// Получить все подходящие среды (сортированные по score)
  List<CreatureHabitat> get sortedHabitats {
    final entries = habitatScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// Проверить, подходит ли данная среда
  bool isHabitatSuitable(CreatureHabitat habitat) {
    return habitatScores[habitat] != null && habitatScores[habitat]! > 0;
  }
}

/// Сервис для определения среды обитания по координатам
/// Использует OpenStreetMap данные через Overpass API
class HabitatService {
  static final HabitatService _instance = HabitatService._internal();
  factory HabitatService() => _instance;
  HabitatService._internal();

  /// Кэш результатов по geohash (первые 6 символов ~ 1.2km x 0.6km)
  final Map<String, HabitatDetectionResult> _cache = {};

  /// Время жизни кэша (30 минут)
  static const Duration cacheLifetime = Duration(minutes: 30);

  /// Радиус поиска в метрах
  static const int searchRadius = 300;

  /// Overpass API endpoints (резервные)
  static const List<String> overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  int _currentEndpointIndex = 0;

  /// Определить среду обитания по координатам
  Future<HabitatDetectionResult> detectHabitat(
    double latitude,
    double longitude,
  ) async {
    // Проверяем кэш
    final geohash = _computeGeohash(latitude, longitude, 6);
    final cached = _cache[geohash];
    if (cached != null) {
      final age = DateTime.now().difference(cached.detectedAt);
      if (age < cacheLifetime) {
        return HabitatDetectionResult(
          primaryHabitat: cached.primaryHabitat,
          habitatScores: cached.habitatScores,
          fromCache: true,
          detectedAt: cached.detectedAt,
        );
      }
    }

    // Запрашиваем данные OSM
    try {
      final osmData = await _fetchOSMData(latitude, longitude);
      final result = _analyzeOSMData(osmData, latitude, longitude);

      // Сохраняем в кэш
      _cache[geohash] = result;

      return result;
    } catch (e) {
      debugPrint('⚠️ Ошибка определения среды: $e');
      // Fallback - возвращаем городскую среду как наиболее вероятную
      return _getFallbackResult(latitude, longitude);
    }
  }

  /// Получить данные OSM через Overpass API
  Future<List<Map<String, dynamic>>> _fetchOSMData(
    double latitude,
    double longitude,
  ) async {
    final query = '''
[out:json][timeout:10];
(
  way["natural"](around:$searchRadius,$latitude,$longitude);
  way["landuse"](around:$searchRadius,$latitude,$longitude);
  way["building"](around:$searchRadius,$latitude,$longitude);
  way["waterway"](around:$searchRadius,$latitude,$longitude);
  way["wetland"](around:$searchRadius,$latitude,$longitude);
  way["leisure"](around:$searchRadius,$latitude,$longitude);
  node["natural"="peak"](around:${searchRadius * 2},$latitude,$longitude);
  way["place"](around:$searchRadius,$latitude,$longitude);
);
out tags;
''';

    // Пробуем разные endpoints
    for (int i = 0; i < overpassEndpoints.length; i++) {
      final endpointIndex = (_currentEndpointIndex + i) % overpassEndpoints.length;
      final endpoint = overpassEndpoints[endpointIndex];

      try {
        final response = await http.post(
          Uri.parse(endpoint),
          body: {'data': query},
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _currentEndpointIndex = endpointIndex; // Запоминаем рабочий endpoint
          return List<Map<String, dynamic>>.from(data['elements'] ?? []);
        }
      } catch (e) {
        debugPrint('⚠️ Endpoint $endpoint failed: $e');
        continue;
      }
    }

    throw Exception('Все Overpass endpoints недоступны');
  }

  /// Анализировать данные OSM и определить среду
  HabitatDetectionResult _analyzeOSMData(
    List<Map<String, dynamic>> elements,
    double latitude,
    double longitude,
  ) {
    final scores = <CreatureHabitat, double>{};

    for (final element in elements) {
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final habitat = _mapTagsToHabitat(tags);
      if (habitat != null) {
        scores[habitat] = (scores[habitat] ?? 0) + 1;
      }
    }

    // Если данных мало - добавляем базовые очки для города
    // (предполагаем что если нет явных тегов природы - это городская среда)
    final totalScore = scores.values.fold(0.0, (sum, v) => sum + v);
    if (totalScore < 3) {
      scores[CreatureHabitat.city] = (scores[CreatureHabitat.city] ?? 0) + 2;
    }

    // Нормализуем scores
    final maxScore = scores.values.fold(0.0, (max, v) => v > max ? v : max);
    if (maxScore > 0) {
      scores.updateAll((key, value) => value / maxScore);
    }

    // Определяем основную среду
    CreatureHabitat primaryHabitat = CreatureHabitat.city;
    double maxFinalScore = 0;
    scores.forEach((habitat, score) {
      if (score > maxFinalScore) {
        maxFinalScore = score;
        primaryHabitat = habitat;
      }
    });

    return HabitatDetectionResult(
      primaryHabitat: primaryHabitat,
      habitatScores: scores,
      detectedAt: DateTime.now(),
    );
  }

  /// Маппинг тегов OSM на среды обитания
  CreatureHabitat? _mapTagsToHabitat(Map<String, dynamic> tags) {
    // Лес
    if (tags['natural'] == 'wood' ||
        tags['landuse'] == 'forest' ||
        tags['natural'] == 'tree_row' ||
        tags['landuse'] == 'orchard') {
      return CreatureHabitat.forest;
    }

    // Вода
    if (tags['natural'] == 'water' ||
        tags['water'] != null ||
        tags['waterway'] != null ||
        tags['natural'] == 'spring') {
      return CreatureHabitat.water;
    }

    // Болото
    if (tags['natural'] == 'wetland' ||
        tags['wetland'] != null ||
        tags['natural'] == 'mud') {
      return CreatureHabitat.swamp;
    }

    // Горы
    if (tags['natural'] == 'peak' ||
        tags['natural'] == 'cliff' ||
        tags['natural'] == 'scree' ||
        tags['natural'] == 'rock' ||
        tags['natural'] == 'bare_rock') {
      return CreatureHabitat.mountain;
    }

    // Поле/поляна
    if (tags['landuse'] == 'farmland' ||
        tags['landuse'] == 'meadow' ||
        tags['natural'] == 'grassland' ||
        tags['natural'] == 'heath' ||
        tags['landuse'] == 'grass') {
      return CreatureHabitat.field;
    }

    // Город
    if (tags['building'] != null ||
        tags['landuse'] == 'residential' ||
        tags['landuse'] == 'commercial' ||
        tags['landuse'] == 'industrial' ||
        tags['place'] != null ||
        tags['landuse'] == 'retail') {
      return CreatureHabitat.city;
    }

    // Парки и места отдыха (могут быть и в городе)
    if (tags['leisure'] == 'park' ||
        tags['leisure'] == 'garden' ||
        tags['landuse'] == 'recreation_ground') {
      return CreatureHabitat.city;
    }

    // Фермы/дачи (дом в пригороде)
    if (tags['landuse'] == 'farmyard' ||
        tags['building'] == 'farm' ||
        tags['building'] == 'house' ||
        tags['building'] == 'detached') {
      return CreatureHabitat.home;
    }

    return null;
  }

  /// Fallback результат при ошибке
  HabitatDetectionResult _getFallbackResult(double lat, double lng) {
    // Простая эвристика на основе координат
    // Городская среда по умолчанию (большинство игроков в городах)
    final scores = <CreatureHabitat, double>{
      CreatureHabitat.city: 0.7,
      CreatureHabitat.home: 0.2,
      CreatureHabitat.anywhere: 0.1,
    };

    return HabitatDetectionResult(
      primaryHabitat: CreatureHabitat.city,
      habitatScores: scores,
      detectedAt: DateTime.now(),
    );
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

  /// Очистить устаревшие записи кэша
  void cleanExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, value) {
      return now.difference(value.detectedAt) > cacheLifetime;
    });
  }
}
