import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/walk.dart';

/// Сервис для хранения данных прогулок
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _walksKey = 'saved_walks';
  static const String _settingsKey = 'app_settings';
  
  SharedPreferences? _prefs;

  /// Инициализация
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Сохранение прогулки
  Future<bool> saveWalk(Walk walk) async {
    try {
      final walks = await getAllWalks();
      
      // Обновляем или добавляем прогулку
      final index = walks.indexWhere((w) => w.id == walk.id);
      if (index >= 0) {
        walks[index] = walk;
      } else {
        walks.insert(0, walk);
      }

      // Сериализуем в JSON
      final walksJson = walks.map((w) => w.toMap()).toList();
      final jsonString = jsonEncode(walksJson);
      
      return await _prefs!.setString(_walksKey, jsonString);
    } catch (e) {
      debugPrint('Ошибка сохранения прогулки: $e');
      return false;
    }
  }

  /// Получение всех прогулок
  Future<List<Walk>> getAllWalks() async {
    try {
      final jsonString = _prefs?.getString(_walksKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> walksJson = jsonDecode(jsonString);
      return walksJson
          .map((json) => Walk.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Ошибка загрузки прогулок: $e');
      return [];
    }
  }

  /// Получение прогулки по ID
  Future<Walk?> getWalkById(String id) async {
    final walks = await getAllWalks();
    try {
      return walks.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Удаление прогулки
  Future<bool> deleteWalk(String id) async {
    try {
      final walks = await getAllWalks();
      walks.removeWhere((w) => w.id == id);
      
      final walksJson = walks.map((w) => w.toMap()).toList();
      final jsonString = jsonEncode(walksJson);
      
      return await _prefs!.setString(_walksKey, jsonString);
    } catch (e) {
      debugPrint('Ошибка удаления прогулки: $e');
      return false;
    }
  }

  /// Удаление всех прогулок
  Future<bool> deleteAllWalks() async {
    return await _prefs!.remove(_walksKey);
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
      'units': 'metric', // metric / imperial
      'mapType': 'standard', // standard / satellite / hybrid
    };
  }

  /// Статистика
  Future<Map<String, dynamic>> getStatistics() async {
    final walks = await getAllWalks();
    
    double totalDistance = 0;
    int totalSteps = 0;
    Duration totalDuration = Duration.zero;
    
    for (final walk in walks) {
      totalDistance += walk.totalDistance;
      totalSteps += walk.steps;
      totalDuration += walk.duration;
    }

    // Недельная статистика
    final weekStats = await getWeekStatistics();

    return {
      'totalWalks': walks.length,
      'totalDistance': totalDistance,
      'totalSteps': totalSteps,
      'totalDuration': totalDuration,
      'averageDistance': walks.isNotEmpty ? totalDistance / walks.length : 0,
      'averageSteps': walks.isNotEmpty ? totalSteps / walks.length : 0,
      // Недельная статистика
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
    
    final walks = await getWalksByDateRange(startDate, endDate);
    
    double totalDistance = 0;
    int totalSteps = 0;
    Duration totalDuration = Duration.zero;
    
    // Группируем по дням
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
    
    for (final walk in walks) {
      totalDistance += walk.totalDistance;
      totalSteps += walk.steps;
      totalDuration += walk.duration;
      
      // Находим день прогулки
      final walkDay = DateTime(walk.startTime.year, walk.startTime.month, walk.startTime.day);
      if (dailyStats.containsKey(walkDay)) {
        dailyStats[walkDay]!['distance'] = (dailyStats[walkDay]!['distance'] as double) + walk.totalDistance;
        dailyStats[walkDay]!['steps'] = (dailyStats[walkDay]!['steps'] as int) + walk.steps;
        dailyStats[walkDay]!['walks'] = (dailyStats[walkDay]!['walks'] as int) + 1;
      }
    }
    
    return {
      'walks': walks.length,
      'distance': totalDistance,
      'steps': totalSteps,
      'duration': totalDuration,
      'dailyStats': dailyStats.values.toList(),
    };
  }

  /// Получение прогулок за период
  Future<List<Walk>> getWalksByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final walks = await getAllWalks();
    return walks.where((w) {
      return w.startTime.isAfter(start) && w.startTime.isBefore(end);
    }).toList();
  }

  /// Получение прогулок за сегодня
  Future<List<Walk>> getTodayWalks() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return getWalksByDateRange(startOfDay, endOfDay);
  }

  /// Получение прогулок за неделю
  Future<List<Walk>> getWeekWalks() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = start.add(const Duration(days: 7));
    
    return getWalksByDateRange(start, end);
  }

  /// Получение прогулок за месяц
  Future<List<Walk>> getMonthWalks() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    return getWalksByDateRange(startOfMonth, endOfMonth);
  }
}
