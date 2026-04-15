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
    // Улучшенный запрос: ищем и way, и node, и relation
    // Увеличен радиус для более точного определения
    final query = '''
[out:json][timeout:15];
(
  // Природные объекты
  way["natural"](around:$searchRadius,$latitude,$longitude);
  node["natural"](around:$searchRadius,$latitude,$longitude);
  relation["natural"](around:$searchRadius,$latitude,$longitude);
  
  // Землепользование
  way["landuse"](around:$searchRadius,$latitude,$longitude);
  node["landuse"](around:$searchRadius,$latitude,$longitude);
  relation["landuse"](around:$searchRadius,$latitude,$longitude);
  
  // Здания
  way["building"](around:$searchRadius,$latitude,$longitude);
  node["building"](around:$searchRadius,$latitude,$longitude);
  
  // Водные объекты
  way["water"](around:$searchRadius,$latitude,$longitude);
  way["waterway"](around:$searchRadius,$latitude,$longitude);
  relation["water"](around:$searchRadius,$latitude,$longitude);
  node["natural"="spring"](around:$searchRadius,$latitude,$longitude);
  
  // Болота
  way["wetland"](around:$searchRadius,$latitude,$longitude);
  node["natural"="wetland"](around:$searchRadius,$latitude,$longitude);
  
  // Парки и зоны отдыха
  way["leisure"](around:$searchRadius,$latitude,$longitude);
  node["leisure"](around:$searchRadius,$latitude,$longitude);
  relation["leisure"](around:$searchRadius,$latitude,$longitude);
  
  // Горы и возвышенности
  node["natural"="peak"](around:${searchRadius * 3},$latitude,$longitude);
  way["natural"="cliff"](around:${searchRadius * 2},$latitude,$longitude);
  
  // Населённые пункты
  way["place"](around:${searchRadius * 2},$latitude,$longitude);
  node["place"](around:${searchRadius * 2},$latitude,$longitude);
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
    final debugTags = <String>[]; // Для отладки

    for (final element in elements) {
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final type = element['type'] as String? ?? '';
      
      final habitat = _mapTagsToHabitat(tags);
      if (habitat != null) {
        scores[habitat] = (scores[habitat] ?? 0) + 1;
      }
      
      // Собираем отладочную информацию
      if (tags.isNotEmpty) {
        final relevantTags = _getRelevantTags(tags);
        if (relevantTags.isNotEmpty) {
          debugTags.add('$type: $relevantTags');
        }
      }
    }

    // Логируем найденные теги для отладки
    debugPrint('🗺️ OSM data for ($latitude, $longitude):');
    debugPrint('   Found ${elements.length} elements');
    if (debugTags.isNotEmpty) {
      debugPrint('   Relevant tags: ${debugTags.take(10).join("; ")}');
    }

    // Если данных мало - добавляем базовые очки для города
    // (предполагаем что если нет явных тегов природы - это городская среда)
    final totalScore = scores.values.fold(0.0, (sum, v) => sum + v);
    if (totalScore < 3) {
      debugPrint('   ⚠️ Low data ($totalScore), adding city fallback');
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
      debugPrint('   ${habitat.emoji} ${habitat.name}: ${score.toStringAsFixed(2)}');
      if (score > maxFinalScore) {
        maxFinalScore = score;
        primaryHabitat = habitat;
      }
    });
    
    debugPrint('   ✅ Primary: ${primaryHabitat.emoji} ${primaryHabitat.name}');

    return HabitatDetectionResult(
      primaryHabitat: primaryHabitat,
      habitatScores: scores,
      detectedAt: DateTime.now(),
    );
  }

  /// Получить релевантные теги для отладки
  String _getRelevantTags(Map<String, dynamic> tags) {
    final relevantKeys = [
      'natural', 'landuse', 'leisure', 'water', 'waterway', 
      'building', 'place', 'wetland', 'amenity'
    ];
    final result = <String>[];
    for (final key in relevantKeys) {
      if (tags[key] != null) {
        result.add('$key=${tags[key]}');
      }
    }
    return result.join(', ');
  }

  /// Маппинг тегов OSM на среды обитания
  CreatureHabitat? _mapTagsToHabitat(Map<String, dynamic> tags) {
    // === ЛЕС ===
    if (tags['natural'] == 'wood' ||
        tags['landuse'] == 'forest' ||
        tags['natural'] == 'tree_row' ||
        tags['landuse'] == 'orchard' ||
        tags['landuse'] == 'vineyard' ||
        tags['natural'] == 'tree' ||
        tags['landuse'] == 'wood') {
      return CreatureHabitat.forest;
    }

    // === ВОДА ===
    // Озёра, пруды, реки, ручьи
    if (tags['natural'] == 'water' ||
        tags['natural'] == 'waterway' ||
        tags['water'] != null ||
        tags['waterway'] != null ||
        tags['natural'] == 'spring' ||
        tags['water'] == 'lake' ||
        tags['water'] == 'pond' ||
        tags['water'] == 'reservoir' ||
        tags['water'] == 'river' ||
        tags['water'] == 'stream' ||
        tags['water'] == 'canal' ||
        tags['landuse'] == 'reservoir' ||
        tags['landuse'] == 'basin' ||
        tags['natural'] == 'bay' ||
        tags['natural'] == 'strait') {
      return CreatureHabitat.water;
    }

    // === БОЛОТО ===
    if (tags['natural'] == 'wetland' ||
        tags['wetland'] != null ||
        tags['natural'] == 'mud' ||
        tags['wetland'] == 'swamp' ||
        tags['wetland'] == 'marsh' ||
        tags['wetland'] == 'bog') {
      return CreatureHabitat.swamp;
    }

    // === ГОРЫ ===
    if (tags['natural'] == 'peak' ||
        tags['natural'] == 'cliff' ||
        tags['natural'] == 'scree' ||
        tags['natural'] == 'rock' ||
        tags['natural'] == 'bare_rock' ||
        tags['natural'] == 'ridge' ||
        tags['natural'] == 'valley') {
      return CreatureHabitat.mountain;
    }

    // === ПОЛЕ / ОТКРЫТОЕ ПРОСТРАНСТВО ===
    // Парки, поля, луга, сады
    if (tags['landuse'] == 'farmland' ||
        tags['landuse'] == 'meadow' ||
        tags['landuse'] == 'grass' ||
        tags['landuse'] == 'greenfield' ||
        tags['landuse'] == 'village_green' ||
        tags['landuse'] == 'recreation_ground' ||
        tags['landuse'] == 'allotments' ||
        tags['natural'] == 'grassland' ||
        tags['natural'] == 'heath' ||
        tags['natural'] == 'scrub' ||
        tags['natural'] == 'sand' ||
        tags['natural'] == 'beach' ||
        // Парки и сады - как открытое пространство
        tags['leisure'] == 'park' ||
        tags['leisure'] == 'garden' ||
        tags['leisure'] == 'playground' ||
        tags['leisure'] == 'pitch' ||
        tags['leisure'] == 'sports_centre' ||
        tags['leisure'] == 'common' ||
        tags['leisure'] == 'nature_reserve' ||
        tags['boundary'] == 'national_park') {
      return CreatureHabitat.field;
    }

    // === ГОРОД ===
    // Здания и городская застройка
    if (tags['building'] != null ||
        tags['landuse'] == 'residential' ||
        tags['landuse'] == 'commercial' ||
        tags['landuse'] == 'industrial' ||
        tags['landuse'] == 'retail' ||
        tags['landuse'] == 'construction' ||
        tags['place'] != null ||
        tags['highway'] != null) {
      return CreatureHabitat.city;
    }

    // === ДОМ ===
    // Частные дома, дачи, фермы
    if (tags['landuse'] == 'farmyard' ||
        tags['building'] == 'farm' ||
        tags['building'] == 'house' ||
        tags['building'] == 'detached' ||
        tags['building'] == 'semidetached_house' ||
        tags['building'] == 'terrace' ||
        tags['building'] == 'cabin' ||
        tags['building'] == 'bungalow' ||
        tags['place'] == 'hamlet' ||
        tags['place'] == 'isolated_dwelling') {
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
