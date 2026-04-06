import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_objects/creature.dart';
import 'package:uuid/uuid.dart';
import 'tile_color_habitat_service.dart';

/// Сервис для спавна и управления существами
class CreatureService {
  static final CreatureService _instance = CreatureService._internal();
  factory CreatureService() => _instance;
  CreatureService._internal();

  final _random = Random();
  final _uuid = const Uuid();
  final TileColorHabitatService _tileColorService = TileColorHabitatService();

  /// Кэшированный результат определения среды
  TileColorHabitatResult? _lastHabitatResult;

  /// Конфигурация спавна для каждого типа существа
  static const Map<CreatureType, CreatureSpawnConfig> _spawnConfigs = {
    // Обычные (white) - спавнятся часто, живут долго
    CreatureType.domovoy: CreatureSpawnConfig(
      rarity: CreatureRarity.common,
      habitats: [CreatureHabitat.home, CreatureHabitat.city, CreatureHabitat.anywhere],
      spawnChance: 0.3,
      lifetimeMinutes: 120,
      minLevel: 1,
      maxLevel: 3,
    ),
    CreatureType.goldfish: CreatureSpawnConfig(
      rarity: CreatureRarity.common,
      habitats: [CreatureHabitat.water],
      spawnChance: 0.25,
      lifetimeMinutes: 90,
      minLevel: 1,
      maxLevel: 3,
    ),

    // Необычные (green)
    CreatureType.kikimora: CreatureSpawnConfig(
      rarity: CreatureRarity.uncommon,
      habitats: [CreatureHabitat.swamp, CreatureHabitat.water],
      spawnChance: 0.15,
      lifetimeMinutes: 90,
      minLevel: 2,
      maxLevel: 5,
    ),
    CreatureType.rusalka: CreatureSpawnConfig(
      rarity: CreatureRarity.uncommon,
      habitats: [CreatureHabitat.water],
      spawnChance: 0.12,
      lifetimeMinutes: 75,
      minLevel: 2,
      maxLevel: 5,
    ),

    // Редкие (blue)
    CreatureType.leshy: CreatureSpawnConfig(
      rarity: CreatureRarity.rare,
      habitats: [CreatureHabitat.forest],
      spawnChance: 0.08,
      lifetimeMinutes: 60,
      minLevel: 3,
      maxLevel: 7,
    ),
    CreatureType.vodyanoy: CreatureSpawnConfig(
      rarity: CreatureRarity.rare,
      habitats: [CreatureHabitat.water, CreatureHabitat.swamp],
      spawnChance: 0.06,
      lifetimeMinutes: 60,
      minLevel: 3,
      maxLevel: 7,
    ),

    // Эпические (purple)
    CreatureType.babaYaga: CreatureSpawnConfig(
      rarity: CreatureRarity.epic,
      habitats: [CreatureHabitat.forest],
      spawnChance: 0.03,
      lifetimeMinutes: 45,
      minLevel: 5,
      maxLevel: 10,
    ),
    CreatureType.sirin: CreatureSpawnConfig(
      rarity: CreatureRarity.epic,
      habitats: [CreatureHabitat.field, CreatureHabitat.mountain],
      spawnChance: 0.025,
      lifetimeMinutes: 45,
      minLevel: 5,
      maxLevel: 10,
    ),
    CreatureType.alkonost: CreatureSpawnConfig(
      rarity: CreatureRarity.epic,
      habitats: [CreatureHabitat.water, CreatureHabitat.field],
      spawnChance: 0.025,
      lifetimeMinutes: 45,
      minLevel: 5,
      maxLevel: 10,
    ),

    // Легендарные (yellow)
    CreatureType.zmeiGorynych: CreatureSpawnConfig(
      rarity: CreatureRarity.legendary,
      habitats: [CreatureHabitat.mountain, CreatureHabitat.forest],
      spawnChance: 0.01,
      lifetimeMinutes: 30,
      minLevel: 8,
      maxLevel: 15,
    ),
    CreatureType.firebird: CreatureSpawnConfig(
      rarity: CreatureRarity.legendary,
      habitats: [CreatureHabitat.forest, CreatureHabitat.field],
      spawnChance: 0.008,
      lifetimeMinutes: 30,
      minLevel: 8,
      maxLevel: 15,
    ),

    // Мифические (red)
    CreatureType.koschei: CreatureSpawnConfig(
      rarity: CreatureRarity.mythical,
      habitats: [CreatureHabitat.city], // Руины/заброшенные места
      spawnChance: 0.003,
      lifetimeMinutes: 20,
      minLevel: 10,
      maxLevel: 20,
    ),
  };

  /// Определить среду обитания по координатам (через анализ цвета тайла)
  Future<TileColorHabitatResult?> detectHabitatAsync(
    double latitude,
    double longitude,
  ) async {
    final result = await _tileColorService.detectHabitat(latitude, longitude);
    if (result != null) {
      _lastHabitatResult = result;

      if (result.fromCache) {
        debugPrint('🌍 Среда (из кэша): ${result.primaryHabitat.name}');
      } else {
        debugPrint('🌍 Среда определена: ${result.primaryHabitat.name} '
            '(score: ${result.habitatScores[result.primaryHabitat]?.toStringAsFixed(2)})');
      }
    }

    return result;
  }

  /// Определить среду обитания синхронно (использует кэш или fallback)
  CreatureHabitat detectHabitat(double latitude, double longitude) {
    // Если есть кэшированный результат - используем его
    if (_lastHabitatResult != null) {
      return _lastHabitatResult!.primaryHabitat;
    }

    // Fallback - городская среда (наиболее вероятна)
    return CreatureHabitat.city;
  }

  /// Попытка заспавнить существо в заданной области (асинхронная версия)
  Future<Creature?> trySpawnCreatureAsync({
    required double centerLat,
    required double centerLng,
    double radiusKm = 1.0,
    CreatureHabitat? forceHabitat,
  }) async {
    // Определяем среду через анализ цвета тайла
    final habitatResult = forceHabitat != null
        ? TileColorHabitatResult(
            primaryHabitat: forceHabitat,
            habitatScores: {forceHabitat: 1.0},
            colorAnalysis: ColorAnalysis(
              red: 128,
              green: 128,
              blue: 128,
              hue: 0,
              saturation: 0,
              lightness: 0.5,
              colorName: 'unknown',
            ),
            detectedAt: DateTime.now(),
          )
        : await detectHabitatAsync(centerLat, centerLng);

    if (habitatResult == null) {
      debugPrint('⚠️ Не удалось определить среду обитания');
      return null;
    }

    // Находим существ, которые могут появиться в любой из подходящих сред
    final possibleCreatures = _getPossibleCreatures(habitatResult);

    if (possibleCreatures.isEmpty) {
      debugPrint('⚠️ Нет существ для среды: ${habitatResult.primaryHabitat.name}');
      return null;
    }

    // Сортируем по редкости (редкие в конце)
    possibleCreatures.sort((a, b) => a.value.rarity.level.compareTo(b.value.rarity.level));

    // Проверяем каждого кандидата от редкого к обычному
    for (int i = possibleCreatures.length - 1; i >= 0; i--) {
      final entry = possibleCreatures[i];
      final creatureType = entry.key;
      final config = entry.value;

      // Модификатор шанса на основе score среды
      final habitatScore = _getHabitatScore(config.habitats, habitatResult);
      final adjustedChance = config.spawnChance * habitatScore;

      // Бросок кубика на спавн
      if (_random.nextDouble() < adjustedChance) {
        // Выбираем наиболее подходящую среду для этого существа
        final bestHabitat = _selectBestHabitat(config.habitats, habitatResult);

        debugPrint('🦊 Спавн: ${creatureType.emoji} ${creatureType.name} '
            'в среде ${bestHabitat.name} (chance: ${(adjustedChance * 100).toStringAsFixed(1)}%)');

        return _createCreature(
          creatureType: creatureType,
          config: config,
          centerLat: centerLat,
          centerLng: centerLng,
          radiusKm: radiusKm,
          habitat: bestHabitat,
        );
      }
    }

    return null;
  }

  /// Попытка заспавнить существо (синхронная версия для обратной совместимости)
  Creature? trySpawnCreature({
    required double centerLat,
    required double centerLng,
    double radiusKm = 1.0,
    CreatureHabitat? forceHabitat,
  }) {
    final habitat = forceHabitat ?? detectHabitat(centerLat, centerLng);

    // Находим существ, которые могут появиться в этой среде
    final possibleCreatures = _spawnConfigs.entries
        .where((e) => e.value.habitats.contains(habitat))
        .toList();

    if (possibleCreatures.isEmpty) return null;

    // Сортируем по редкости (редкие в конце)
    possibleCreatures.sort((a, b) => a.value.rarity.level.compareTo(b.value.rarity.level));

    // Проверяем каждого кандидата от редкого к обычному
    for (int i = possibleCreatures.length - 1; i >= 0; i--) {
      final entry = possibleCreatures[i];
      final creatureType = entry.key;
      final config = entry.value;

      // Бросок кубика на спавн
      if (_random.nextDouble() < config.spawnChance) {
        return _createCreature(
          creatureType: creatureType,
          config: config,
          centerLat: centerLat,
          centerLng: centerLng,
          radiusKm: radiusKm,
          habitat: habitat,
        );
      }
    }

    return null;
  }

  /// Получить список возможных существ для всех подходящих сред
  List<MapEntry<CreatureType, CreatureSpawnConfig>> _getPossibleCreatures(
    TileColorHabitatResult habitatResult,
  ) {
    final result = <MapEntry<CreatureType, CreatureSpawnConfig>>[];
    final addedTypes = <CreatureType>{};

    // Сортируем habitats по score
    final sortedHabitats = habitatResult.habitatScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedHabitats) {
      final habitat = entry.key;
      final score = entry.value;
      if (score <= 0) continue;

      for (final configEntry in _spawnConfigs.entries) {
        if (configEntry.value.habitats.contains(habitat) && !addedTypes.contains(configEntry.key)) {
          result.add(configEntry);
          addedTypes.add(configEntry.key);
        }
      }
    }

    return result;
  }

  /// Получить score для существа на основе его сред обитания
  double _getHabitatScore(
    List<CreatureHabitat> creatureHabitats,
    TileColorHabitatResult habitatResult,
  ) {
    double maxScore = 0;
    for (final habitat in creatureHabitats) {
      final score = habitatResult.habitatScores[habitat] ?? 0;
      if (score > maxScore) maxScore = score;
    }
    // Минимальный шанс 0.3 даже если среда не идеально подходит
    return max(0.3, maxScore);
  }

  /// Выбрать лучшую среду для существа
  CreatureHabitat _selectBestHabitat(
    List<CreatureHabitat> creatureHabitats,
    TileColorHabitatResult habitatResult,
  ) {
    CreatureHabitat best = creatureHabitats.first;
    double bestScore = 0;

    for (final habitat in creatureHabitats) {
      final score = habitatResult.habitatScores[habitat] ?? 0;
      if (score > bestScore) {
        bestScore = score;
        best = habitat;
      }
    }

    return best;
  }

  /// Создать существо с заданными параметрами
  Creature _createCreature({
    required CreatureType creatureType,
    required CreatureSpawnConfig config,
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    required CreatureHabitat habitat,
  }) {
    // Случайная позиция в радиусе
    final offset = _randomOffset(centerLat, centerLng, radiusKm);

    // Случайный уровень
    final level = config.minLevel + _random.nextInt(config.maxLevel - config.minLevel + 1);

    return Creature.spawnWild(
      id: _uuid.v4(),
      latitude: offset.latitude,
      longitude: offset.longitude,
      creatureType: creatureType,
      rarity: config.rarity,
      habitat: habitat,
      lifetimeMinutes: config.lifetimeMinutes,
    ).copyWithLevel(level);
  }

  /// Случайное смещение от центра
  LatLng _randomOffset(double centerLat, double centerLng, double radiusKm) {
    // Преобразуем км в градусы (примерно)
    final latOffset = radiusKm / 111.0; // 1 градус широты ≈ 111 км
    final lngOffset = radiusKm / (111.0 * cos(centerLat * pi / 180));

    // Случайное направление и расстояние
    final angle = _random.nextDouble() * 2 * pi;
    final distance = _random.nextDouble();

    return LatLng(
      centerLat + latOffset * distance * sin(angle),
      centerLng + lngOffset * distance * cos(angle),
    );
  }

  /// Спавнить существ вокруг позиции игрока (асинхронная версия)
  Future<List<Creature>> spawnAroundPlayerAsync({
    required double playerLat,
    required double playerLng,
    int maxCreatures = 3,
    double radiusKm = 2.0,
  }) async {
    final spawned = <Creature>[];

    for (int i = 0; i < maxCreatures; i++) {
      final creature = await trySpawnCreatureAsync(
        centerLat: playerLat,
        centerLng: playerLng,
        radiusKm: radiusKm,
      );
      if (creature != null) {
        spawned.add(creature);
      }
    }

    return spawned;
  }

  /// Спавнить существ вокруг игрока (синхронная версия)
  List<Creature> spawnAroundPlayer({
    required double playerLat,
    required double playerLng,
    int maxCreatures = 3,
    double radiusKm = 2.0,
  }) {
    final spawned = <Creature>[];

    for (int i = 0; i < maxCreatures; i++) {
      final creature = trySpawnCreature(
        centerLat: playerLat,
        centerLng: playerLng,
        radiusKm: radiusKm,
      );
      if (creature != null) {
        spawned.add(creature);
      }
    }

    return spawned;
  }

  /// Получить список существ, которые могут появиться в данной среде
  List<CreatureType> getCreaturesForHabitat(CreatureHabitat habitat) {
    return _spawnConfigs.entries
        .where((e) => e.value.habitats.contains(habitat))
        .map((e) => e.key)
        .toList();
  }

  /// Получить конфигурацию спавна для типа существа
  CreatureSpawnConfig? getSpawnConfig(CreatureType type) {
    return _spawnConfigs[type];
  }

  /// Получить последнее определение среды
  TileColorHabitatResult? get lastHabitatResult => _lastHabitatResult;

  /// Рассчитать шанс поимки существа
  double calculateCatchChance(Creature creature, int playerLevel) {
    // Базовый шанс зависит от редкости и разницы уровней
    final rarityModifier = 1.0 - (creature.rarity.level - 1) * 0.12;
    final levelModifier = 1.0 - (creature.level - playerLevel) * 0.05;
    final healthModifier = creature.currentHealth / creature.maxHealth;

    return (rarityModifier * levelModifier * healthModifier).clamp(0.1, 0.95);
  }

  /// Попытка поимки существа
  CatchResult tryCatchCreature(Creature creature, int playerLevel) {
    final chance = calculateCatchChance(creature, playerLevel);
    final roll = _random.nextDouble();

    if (roll < chance) {
      return CatchResult.success(
        creature: creature,
        chance: chance,
        points: creature.catchPoints,
      );
    } else {
      // Существо могло сбежать или нанести урон
      final escaped = _random.nextDouble() < 0.3;
      return CatchResult.failed(
        creature: creature,
        chance: chance,
        escaped: escaped,
      );
    }
  }
}

/// Конфигурация спавна для типа существа
class CreatureSpawnConfig {
  final CreatureRarity rarity;
  final List<CreatureHabitat> habitats;
  final double spawnChance; // 0.0 - 1.0
  final int lifetimeMinutes;
  final int minLevel;
  final int maxLevel;

  const CreatureSpawnConfig({
    required this.rarity,
    required this.habitats,
    required this.spawnChance,
    required this.lifetimeMinutes,
    required this.minLevel,
    required this.maxLevel,
  });
}

/// Результат попытки поимки
class CatchResult {
  final bool isSuccess;
  final Creature creature;
  final double chance;
  final int? points;
  final bool escaped;
  final String message;

  const CatchResult._({
    required this.isSuccess,
    required this.creature,
    required this.chance,
    this.points,
    this.escaped = false,
    required this.message,
  });

  factory CatchResult.success({
    required Creature creature,
    required double chance,
    required int points,
  }) {
    return CatchResult._(
      isSuccess: true,
      creature: creature,
      chance: chance,
      points: points,
      message: '${creature.creatureType.emoji} ${creature.creatureType.name} пойман! +$points очков',
    );
  }

  factory CatchResult.failed({
    required Creature creature,
    required double chance,
    bool escaped = false,
  }) {
    final message = escaped
        ? '${creature.creatureType.emoji} ${creature.creatureType.name} убежал!'
        : 'Не удалось поймать ${creature.creatureType.name}...';
    return CatchResult._(
      isSuccess: false,
      creature: creature,
      chance: chance,
      escaped: escaped,
      message: message,
    );
  }
}

/// Расширение для Creature для копирования с изменением уровня
extension CreatureCopyWith on Creature {
  Creature copyWithLevel(int newLevel) {
    return Creature(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      deletedAt: deletedAt,
      creatureType: creatureType,
      rarity: rarity,
      habitat: habitat,
      name: name,
      level: newLevel,
      isWild: isWild,
      caughtBy: caughtBy,
      caughtAt: caughtAt,
      spawnTime: spawnTime,
      lifetimeMinutes: lifetimeMinutes,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version,
    );
  }
}
