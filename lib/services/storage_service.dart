import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/walk.dart';
import '../models/walk_point.dart';

/// Лёгкие метаданные прогулки (без точек трека) - для списков
class WalkMetadata {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int steps;
  final String? name;
  final String? notes;
  final DistanceSource distanceSource;
  final double stepLength;
  final Duration totalPauseDuration;
  final WalkObjectStats objectStats;
  /// Кешированное расстояние (для быстрого отображения)
  final double cachedDistance;

  const WalkMetadata({
    required this.id,
    required this.startTime,
    this.endTime,
    this.steps = 0,
    this.name,
    this.notes,
    this.distanceSource = DistanceSource.pedometer,
    this.stepLength = 0.75,
    this.totalPauseDuration = Duration.zero,
    this.objectStats = const WalkObjectStats(),
    this.cachedDistance = 0,
  });

  /// Создание из Walk (без точек)
  factory WalkMetadata.fromWalk(Walk walk) {
    return WalkMetadata(
      id: walk.id,
      startTime: walk.startTime,
      endTime: walk.endTime,
      steps: walk.steps,
      name: walk.name,
      notes: walk.notes,
      distanceSource: walk.distanceSource,
      stepLength: walk.stepLength,
      totalPauseDuration: walk.totalPauseDuration,
      objectStats: walk.objectStats,
      cachedDistance: walk.totalDistance,
    );
  }

  /// Продолжительность
  Duration get duration {
    final total = endTime != null
        ? endTime!.difference(startTime)
        : DateTime.now().difference(startTime);
    return total - totalPauseDuration;
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '$hoursч $minutesмин';
    if (minutes > 0) return '$minutesмин $secondsсек';
    return '$secondsсек';
  }

  String get formattedDistance {
    if (cachedDistance >= 1000) {
      return '${(cachedDistance / 1000).toStringAsFixed(2)} км';
    }
    return '${cachedDistance.toStringAsFixed(0)} м';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'steps': steps,
    'name': name,
    'notes': notes,
    'distanceSource': distanceSource.index,
    'stepLength': stepLength,
    'totalPauseDuration': totalPauseDuration.inSeconds,
    'objectStats': objectStats.toMap(),
    'cachedDistance': cachedDistance,
  };

  factory WalkMetadata.fromMap(Map<String, dynamic> map) {
    return WalkMetadata(
      id: map['id'] as String,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      steps: map['steps'] as int? ?? 0,
      name: map['name'] as String?,
      notes: map['notes'] as String?,
      distanceSource: DistanceSource.values[map['distanceSource'] as int? ?? 1],
      stepLength: (map['stepLength'] as num?)?.toDouble() ?? 0.75,
      totalPauseDuration: Duration(seconds: map['totalPauseDuration'] as int? ?? 0),
      objectStats: map['objectStats'] != null
          ? WalkObjectStats.fromMap(map['objectStats'] as Map<String, dynamic>)
          : const WalkObjectStats(),
      cachedDistance: (map['cachedDistance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Сервис для хранения данных прогулок
/// 
/// Использует разделённое хранение:
/// - `walks_meta` - список метаданных (быстро, мало данных)
/// - `walk_points_{id}` - точки трека каждой прогулки отдельно
/// 
/// Это позволяет быстро загружать список прогулок без тяжёлых точек.
class StorageService {
  static const String _walksMetaKey = 'walks_meta';
  static const String _walkPointsPrefix = 'walk_points_';
  static const String _legacyWalksKey = 'saved_walks';  // Старый формат
  static const String _settingsKey = 'app_settings';
  static const String _migrationDoneKey = 'walks_migration_done';

  SharedPreferences? _prefs;

  /// Кэш метаданных в памяти (быстрый доступ)
  List<WalkMetadata>? _metaCache;

  /// Инициализация
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateIfNeeded();
  }

  /// Миграция со старого формата (один JSON blob) на новый (meta + points)
  Future<void> _migrateIfNeeded() async {
    final migrated = _prefs?.getBool(_migrationDoneKey) ?? false;
    if (migrated) return;

    final legacyJson = _prefs?.getString(_legacyWalksKey);
    if (legacyJson == null || legacyJson.isEmpty) {
      await _prefs?.setBool(_migrationDoneKey, true);
      return;
    }

    try {
      final List<dynamic> walksJson = jsonDecode(legacyJson);
      final metas = <WalkMetadata>[];

      for (final json in walksJson) {
        final walk = Walk.fromMap(json as Map<String, dynamic>);
        final meta = WalkMetadata.fromWalk(walk);
        metas.add(meta);

        // Сохраняем точки отдельно
        final pointsJson = walk.points.map((p) => p.toMap()).toList();
        await _prefs?.setString(
          '$_walkPointsPrefix${walk.id}',
          jsonEncode(pointsJson),
        );
      }

      // Сохраняем метаданные
      final metasJson = metas.map((m) => m.toMap()).toList();
      await _prefs?.setString(_walksMetaKey, jsonEncode(metasJson));

      // Удаляем старый ключ
      await _prefs?.remove(_legacyWalksKey);
      await _prefs?.setBool(_migrationDoneKey, true);

      debugPrint('StorageService: Миграция завершена, ${metas.length} прогулок');
    } catch (e) {
      debugPrint('StorageService: Ошибка миграции: $e');
      // Помечаем как выполненную, чтобы не повторять
      await _prefs?.setBool(_migrationDoneKey, true);
    }
  }

  /// Сохранение прогулки (метаданные + точки)
  Future<bool> saveWalk(Walk walk) async {
    try {
      final metas = await _getMetasInternal();
      
      final meta = WalkMetadata.fromWalk(walk);
      final index = metas.indexWhere((m) => m.id == walk.id);
      if (index >= 0) {
        metas[index] = meta;
      } else {
        metas.insert(0, meta);
      }

      // Сохраняем метаданные
      final metasJson = metas.map((m) => m.toMap()).toList();
      await _prefs!.setString(_walksMetaKey, jsonEncode(metasJson));

      // Сохраняем точки отдельно
      final pointsJson = walk.points.map((p) => p.toMap()).toList();
      await _prefs!.setString(
        '$_walkPointsPrefix${walk.id}',
        jsonEncode(pointsJson),
      );

      // Инвалидируем кэш
      _metaCache = null;

      return true;
    } catch (e) {
      debugPrint('Ошибка сохранения прогулки: $e');
      return false;
    }
  }

  /// Получить ВСЕ метаданные прогулок (быстро, без точек)
  Future<List<WalkMetadata>> getAllWalksMetadata() async {
    return _getMetasInternal();
  }

  /// Внутренний метод получения метаданных с кэшированием
  Future<List<WalkMetadata>> _getMetasInternal() async {
    if (_metaCache != null) return _metaCache!;

    try {
      final jsonString = _prefs?.getString(_walksMetaKey);
      if (jsonString == null || jsonString.isEmpty) {
        _metaCache = [];
        return _metaCache!;
      }

      final List<dynamic> metasJson = jsonDecode(jsonString);
      _metaCache = metasJson
          .map((json) => WalkMetadata.fromMap(json as Map<String, dynamic>))
          .toList();
      return _metaCache!;
    } catch (e) {
      debugPrint('Ошибка загрузки метаданных: $e');
      _metaCache = [];
      return _metaCache!;
    }
  }

  /// Получить метаданные с пагинацией
  /// 
  /// [limit] - количество записей
  /// [offset] - смещение (для пагинации)
  Future<List<WalkMetadata>> getWalksMetadataPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    final metas = await _getMetasInternal();
    if (offset >= metas.length) return [];
    final end = (offset + limit > metas.length) ? metas.length : offset + limit;
    return metas.sublist(offset, end);
  }

  /// Количество прогулок
  Future<int> getWalksCount() async {
    final metas = await _getMetasInternal();
    return metas.length;
  }

  /// Получить полный Walk (с точками) по ID
  Future<Walk?> getWalkById(String id) async {
    try {
      final metas = await _getMetasInternal();
      final meta = metas.firstWhere((m) => m.id == id);

      final pointsJson = _prefs?.getString('$_walkPointsPrefix$id');
      List<WalkPoint> points = [];
      if (pointsJson != null && pointsJson.isNotEmpty) {
        final List<dynamic> pointsList = jsonDecode(pointsJson);
        points = pointsList
            .map((p) => WalkPoint.fromMap(p as Map<String, dynamic>))
            .toList();
      }

      return Walk(
        id: meta.id,
        startTime: meta.startTime,
        endTime: meta.endTime,
        points: points,
        steps: meta.steps,
        name: meta.name,
        notes: meta.notes,
        distanceSource: meta.distanceSource,
        stepLength: meta.stepLength,
        totalPauseDuration: meta.totalPauseDuration,
        objectStats: meta.objectStats,
      );
    } catch (_) {
      return null;
    }
  }

  /// Получить метаданные прогулки по ID (быстро, без точек)
  Future<WalkMetadata?> getWalkMetadataById(String id) async {
    final metas = await _getMetasInternal();
    try {
      return metas.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Удаление прогулки
  Future<bool> deleteWalk(String id) async {
    try {
      final metas = await _getMetasInternal();
      metas.removeWhere((m) => m.id == id);

      final metasJson = metas.map((m) => m.toMap()).toList();
      await _prefs!.setString(_walksMetaKey, jsonEncode(metasJson));

      // Удаляем точки
      await _prefs!.remove('$_walkPointsPrefix$id');

      _metaCache = null;
      return true;
    } catch (e) {
      debugPrint('Ошибка удаления прогулки: $e');
      return false;
    }
  }

  /// Удаление всех прогулок
  Future<bool> deleteAllWalks() async {
    try {
      final metas = await _getMetasInternal();

      // Удаляем все точки
      for (final meta in metas) {
        await _prefs!.remove('$_walkPointsPrefix${meta.id}');
      }

      await _prefs!.remove(_walksMetaKey);
      _metaCache = null;
      return true;
    } catch (e) {
      debugPrint('Ошибка удаления всех прогулок: $e');
      return false;
    }
  }

  /// Сохранение настроек
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    try {
      final jsonString = jsonEncode(settings);
      return await _prefs!.setString(_settingsKey, jsonString);
    } catch (e) {
      debugPrint('Ошибка сохранения настроек: $e');
      return false;
    }
  }

  /// Получение настроек
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final jsonString = _prefs?.getString(_settingsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return _defaultSettings();
      }
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Ошибка загрузки настроек: $e');
      return _defaultSettings();
    }
  }

  Map<String, dynamic> _defaultSettings() {
    return {
      'autoPause': true,
      'voiceAnnouncements': false,
      'units': 'metric',
      'mapType': 'standard',
    };
  }

  /// Статистика (использует метаданные - быстро)
  Future<Map<String, dynamic>> getStatistics() async {
    final metas = await _getMetasInternal();

    double totalDistance = 0;
    int totalSteps = 0;
    Duration totalDuration = Duration.zero;

    for (final meta in metas) {
      totalDistance += meta.cachedDistance;
      totalSteps += meta.steps;
      totalDuration += meta.duration;
    }

    final weekStats = await getWeekStatistics();

    return {
      'totalWalks': metas.length,
      'totalDistance': totalDistance,
      'totalSteps': totalSteps,
      'totalDuration': totalDuration,
      'averageDistance': metas.isNotEmpty ? totalDistance / metas.length : 0,
      'averageSteps': metas.isNotEmpty ? totalSteps / metas.length : 0,
      'weekWalks': weekStats['walks'],
      'weekDistance': weekStats['distance'],
      'weekSteps': weekStats['steps'],
      'weekDuration': weekStats['duration'],
      'dailyStats': weekStats['dailyStats'],
    };
  }

  /// Статистика за последние 7 дней
  Future<Map<String, dynamic>> getWeekStatistics() async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final endDate = startDate.add(const Duration(days: 7));

    final metas = await getWalksMetadataByDateRange(startDate, endDate);

    double totalDistance = 0;
    int totalSteps = 0;
    Duration totalDuration = Duration.zero;

    final dailyStats = <DateTime, Map<String, dynamic>>{};

    for (int i = 0; i < 7; i++) {
      final day = startDate.add(Duration(days: i));
      dailyStats[day] = {
        'date': day,
        'distance': 0.0,
        'steps': 0,
        'walks': 0,
      };
    }

    for (final meta in metas) {
      totalDistance += meta.cachedDistance;
      totalSteps += meta.steps;
      totalDuration += meta.duration;

      final walkDay = DateTime(meta.startTime.year, meta.startTime.month, meta.startTime.day);
      if (dailyStats.containsKey(walkDay)) {
        dailyStats[walkDay]!['distance'] = (dailyStats[walkDay]!['distance'] as double) + meta.cachedDistance;
        dailyStats[walkDay]!['steps'] = (dailyStats[walkDay]!['steps'] as int) + meta.steps;
        dailyStats[walkDay]!['walks'] = (dailyStats[walkDay]!['walks'] as int) + 1;
      }
    }

    return {
      'walks': metas.length,
      'distance': totalDistance,
      'steps': totalSteps,
      'duration': totalDuration,
      'dailyStats': dailyStats.values.toList(),
    };
  }

  /// Получение метаданных за период
  Future<List<WalkMetadata>> getWalksMetadataByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final metas = await _getMetasInternal();
    return metas.where((m) {
      return m.startTime.isAfter(start) && m.startTime.isBefore(end);
    }).toList();
  }
}
