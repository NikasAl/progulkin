import 'map_object.dart';

/// Тип существа (русская мифология)
enum CreatureType {
  domovoy('domovoy', 'Домовой', '🏠', 'Хранитель дома'),
  leshy('leshy', 'Леший', '🌲', 'Дух леса'),
  vodyanoy('vodyanoy', 'Водяной', '🌊', 'Дух воды'),
  kikimora('kikimora', 'Кикимора', '🌿', 'Болотный дух'),
  rusalka('rusalka', 'Русалка', '🧜‍♀️', 'Дух воды'),
  babaYaga('baba_yaga', 'Баба Яга', '🧙‍♀️', 'Лесная ведьма'),
  zmeiGorynych('zmei_gorynych', 'Змей Горыныч', '🐉', 'Трёхголовый дракон'),
  koschei('koschei', 'Кощей', '💀', 'Бессмертный злодей'),
  sirin('sirin', 'Сирин', '🦅', 'Птица-дева'),
  alkonost('alkonost', 'Алконост', '🐦', 'Птица счастья'),
  firebird('firebird', 'Жар-птица', '🔥', 'Волшебная птица'),
  goldfish('goldfish', 'Золотая рыбка', '🐠', 'Исполняет желания'),
  ;

  final String code;
  final String name;
  final String emoji;
  final String description;

  const CreatureType(this.code, this.name, this.emoji, this.description);

  static CreatureType fromCode(String code) {
    return CreatureType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => CreatureType.domovoy,
    );
  }
}

/// Редкость существа
enum CreatureRarity {
  common('common', 'Обычный', '⚪', 1),
  uncommon('uncommon', 'Необычный', '🟢', 2),
  rare('rare', 'Редкий', '🔵', 3),
  epic('epic', 'Эпический', '🟣', 4),
  legendary('legendary', 'Легендарный', '🟡', 5),
  mythical('mythical', 'Мифический', '🔴', 6),
  ;

  final String code;
  final String name;
  final String badge;
  final int level;

  const CreatureRarity(this.code, this.name, this.badge, this.level);

  static CreatureRarity fromLevel(int level) {
    return CreatureRarity.values.firstWhere(
      (r) => r.level == level,
      orElse: () => CreatureRarity.common,
    );
  }

  static CreatureRarity fromCode(String code) {
    return CreatureRarity.values.firstWhere(
      (r) => r.code == code,
      orElse: () => CreatureRarity.common,
    );
  }
}

/// Среда обитания
enum CreatureHabitat {
  forest('forest', 'Лес', '🌲'),
  water('water', 'Вода', '💧'),
  swamp('swamp', 'Болото', '🌿'),
  mountain('mountain', 'Горы', '⛰️'),
  field('field', 'Поле', '🌾'),
  city('city', 'Город', '🏙️'),
  home('home', 'Дом', '🏠'),
  anywhere('anywhere', 'Везде', '🌍'),
  ;

  final String code;
  final String name;
  final String emoji;

  const CreatureHabitat(this.code, this.name, this.emoji);

  static CreatureHabitat fromCode(String code) {
    return CreatureHabitat.values.firstWhere(
      (h) => h.code == code,
      orElse: () => CreatureHabitat.anywhere,
    );
  }
}

/// Существо (как покемоны, но русская мифология)
class Creature extends MapObject {
  final CreatureType creatureType;
  final CreatureRarity rarity;
  final CreatureHabitat habitat;
  final String name;            // Кастомное имя (опционально)
  final int level;              // Уровень существа
  final int maxHealth;
  final int currentHealth;
  final int attack;
  final int defense;
  final List<String> abilities;
  final bool isWild;            // Дикое или приручённое
  final String? caughtBy;       // Кто поймал
  final DateTime? caughtAt;
  final DateTime spawnTime;     // Когда появилось
  final int lifetimeMinutes;    // Время жизни в минутах (0 = бессмертно)

  Creature({
    required super.id,
    required super.latitude,
    required super.longitude,
    required super.ownerId,
    super.ownerName,
    super.ownerReputation,
    required this.creatureType,
    required this.rarity,
    required this.habitat,
    this.name = '',
    this.level = 1,
    int? maxHealth,
    int? currentHealth,
    int? attack,
    int? defense,
    List<String>? abilities,
    this.isWild = true,
    this.caughtBy,
    this.caughtAt,
    DateTime? spawnTime,
    this.lifetimeMinutes = 60,
    super.status,
    super.confirms,
    super.denies,
    super.views,
    super.version,
  })  : maxHealth = maxHealth ?? _calculateMaxHealth(rarity, level),
        currentHealth = currentHealth ?? maxHealth ?? _calculateMaxHealth(rarity, level),
        attack = attack ?? _calculateStat(rarity, level, 10),
        defense = defense ?? _calculateStat(rarity, level, 5),
        abilities = abilities ?? _getDefaultAbilities(creatureType),
        spawnTime = spawnTime ?? DateTime.now(),
        super(type: MapObjectType.creature);

  static int _calculateMaxHealth(CreatureRarity rarity, int level) {
    return 50 + rarity.level * 20 + level * 5;
  }

  static int _calculateStat(CreatureRarity rarity, int level, int base) {
    return base + rarity.level * 3 + level;
  }

  static List<String> _getDefaultAbilities(CreatureType type) {
    switch (type) {
      case CreatureType.domovoy:
        return ['Прятки', 'Тепло дома', 'Защита'];
      case CreatureType.leshy:
        return ['Лесное зрение', 'Морока', 'Прохлада'];
      case CreatureType.vodyanoy:
        return ['Водяной плеск', 'Глубина', 'Холод'];
      case CreatureType.kikimora:
        return ['Болотный туман', 'Пугание', 'Исцеление'];
      case CreatureType.rusalka:
        return ['Чары', 'Плен', 'Красота'];
      case CreatureType.babaYaga:
        return ['Избушка', 'Мётла', 'Снадобья'];
      case CreatureType.zmeiGorynych:
        return ['Огненное дыхание', 'Три головы', 'Полёт'];
      case CreatureType.koschei:
        return ['Бессмертие', 'Меч', 'Яйцо'];
      case CreatureType.sirin:
        return ['Песнь печали', 'Пророчество', 'Полёт'];
      case CreatureType.alkonost:
        return ['Песнь радости', 'Весна', 'Полёт'];
      case CreatureType.firebird:
        return ['Пламя', 'Сияние', 'Перо удачи'];
      case CreatureType.goldfish:
        return ['Желание', 'Всплеск', 'Золото'];
    }
  }

  /// Фабрика для создания дикого существа
  factory Creature.spawnWild({
    required String id,
    required double latitude,
    required double longitude,
    required CreatureType creatureType,
    required CreatureRarity rarity,
    required CreatureHabitat habitat,
    int lifetimeMinutes = 60,
  }) {
    return Creature(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: 'system',
      ownerName: 'Природа',
      creatureType: creatureType,
      rarity: rarity,
      habitat: habitat,
      isWild: true,
      lifetimeMinutes: lifetimeMinutes,
    );
  }

  @override
  bool get isExpired {
    if (lifetimeMinutes <= 0) return false;
    return DateTime.now().difference(spawnTime).inMinutes > lifetimeMinutes;
  }

  /// Оставшееся время жизни
  Duration? get remainingTime {
    if (lifetimeMinutes <= 0) return null;
    final elapsed = DateTime.now().difference(spawnTime).inMinutes;
    final remaining = lifetimeMinutes - elapsed;
    return remaining > 0 ? Duration(minutes: remaining) : Duration.zero;
  }

  @override
  String get shortDescription {
    final rarityBadge = rarity.badge;
    final wildIcon = isWild ? '🌿' : '💝';
    return '${creatureType.emoji} ${creatureType.name} $rarityBadge $wildIcon';
  }

  /// Поймать существо
  Creature catchCreature(String userId, String userName) {
    return Creature(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: userId,
      ownerName: userName,
      creatureType: creatureType,
      rarity: rarity,
      habitat: habitat,
      name: name,
      level: level,
      maxHealth: maxHealth,
      currentHealth: currentHealth,
      attack: attack,
      defense: defense,
      abilities: abilities,
      isWild: false,
      caughtBy: userId,
      caughtAt: DateTime.now(),
      spawnTime: spawnTime,
      lifetimeMinutes: 0, // Пойманное существо бессмертно
      status: MapObjectStatus.confirmed,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Нанести урон
  Creature takeDamage(int damage) {
    final newHealth = (currentHealth - damage).clamp(0, maxHealth);
    return Creature(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      creatureType: creatureType,
      rarity: rarity,
      habitat: habitat,
      name: name,
      level: level,
      maxHealth: maxHealth,
      currentHealth: newHealth,
      attack: attack,
      defense: defense,
      abilities: abilities,
      isWild: isWild,
      caughtBy: caughtBy,
      caughtAt: caughtAt,
      spawnTime: spawnTime,
      lifetimeMinutes: lifetimeMinutes,
      status: newHealth <= 0 ? MapObjectStatus.hidden : status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Очки за поимку
  int get catchPoints {
    return rarity.level * 100 + level * 10;
  }

  /// Живо ли существо
  bool get isAlive => currentHealth > 0 && !isExpired;

  /// Расстояние до точки (для UI)
  double distanceTo(double lat, double lng) {
    return calculateDistance(latitude, longitude, lat, lng);
  }

  @override
  Map<String, dynamic> toSyncJson() {
    return {
      ...super.toSyncJson(),
      'creatureType': creatureType.code,
      'rarity': rarity.level,
      'habitat': habitat.code,
      'name': name,
      'level': level,
      'maxHealth': maxHealth,
      'currentHealth': currentHealth,
      'attack': attack,
      'defense': defense,
      'abilities': abilities,
      'isWild': isWild,
      'caughtBy': caughtBy,
      'caughtAt': caughtAt?.toIso8601String(),
      'spawnTime': spawnTime.toIso8601String(),
      'lifetimeMinutes': lifetimeMinutes,
    };
  }

  factory Creature.fromSyncJson(Map<String, dynamic> json) {
    return Creature(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String? ?? 'Природа',
      ownerReputation: json['ownerReputation'] as int? ?? 0,
      creatureType: CreatureType.fromCode(json['creatureType'] as String? ?? 'domovoy'),
      rarity: CreatureRarity.fromLevel(json['rarity'] as int? ?? 1),
      habitat: CreatureHabitat.fromCode(json['habitat'] as String? ?? 'anywhere'),
      name: json['name'] as String? ?? '',
      level: json['level'] as int? ?? 1,
      maxHealth: json['maxHealth'] as int?,
      currentHealth: json['currentHealth'] as int?,
      attack: json['attack'] as int?,
      defense: json['defense'] as int?,
      abilities: (json['abilities'] as List?)?.map((e) => e as String).toList(),
      isWild: json['isWild'] as bool? ?? true,
      caughtBy: json['caughtBy'] as String?,
      caughtAt: json['caughtAt'] != null
          ? DateTime.parse(json['caughtAt'] as String)
          : null,
      spawnTime: json['spawnTime'] != null
          ? DateTime.parse(json['spawnTime'] as String)
          : null,
      lifetimeMinutes: json['lifetimeMinutes'] as int? ?? 60,
      status: MapObjectStatus.fromCode(json['status'] as String? ?? 'active'),
      confirms: json['confirms'] as int? ?? 0,
      denies: json['denies'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }
}
