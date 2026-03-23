import 'map_object.dart';

/// Тип мусора
enum TrashType {
  bottles('bottles', 'Бутылки/банки', '🍺'),
  paper('paper', 'Бумага/картон', '🗞️'),
  tires('tires', 'Шины', '🛞'),
  furniture('furniture', 'Мебель', '🛋️'),
  construction('construction', 'Строймусор', '🏗️'),
  electronics('electronics', 'Электроника', '📺'),
  plastic('plastic', 'Пластик', '🥤'),
  organic('organic', 'Органика', '🍂'),
  mixed('mixed', 'Смешанный', '🗑️'),
  other('other', 'Другое', '❓'),
  ;

  final String code;
  final String name;
  final String emoji;

  const TrashType(this.code, this.name, this.emoji);

  static TrashType fromCode(String code) {
    return TrashType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => TrashType.other,
    );
  }
}

/// Количество мусора
enum TrashQuantity {
  single('single', '1 шт', 1),
  few('few', '2-5 шт', 3),
  several('several', '5-10 шт', 8),
  many('many', '10-20 шт', 15),
  heap('heap', '20+ шт', 25),
  ;

  final String code;
  final String name;
  final int estimatedCount;

  const TrashQuantity(this.code, this.name, this.estimatedCount);

  static TrashQuantity fromCode(String code) {
    return TrashQuantity.values.firstWhere(
      (t) => t.code == code,
      orElse: () => TrashQuantity.few,
    );
  }
}

/// Класс монстра (сложность уборки)
enum MonsterClass {
  easy('easy', 1, 'Лёгкий', '🟢', 10),
  medium('medium', 2, 'Средний', '🟡', 20),
  hard('hard', 3, 'Сложный', '🟠', 30),
  veryHard('very_hard', 4, 'Тяжёлый', '🔴', 40),
  boss('boss', 5, 'Босс', '💀', 50),
  ;

  final String code;
  final int level;
  final String name;
  final String badge;
  final int basePoints;

  const MonsterClass(this.code, this.level, this.name, this.badge, this.basePoints);

  static MonsterClass fromLevel(int level) {
    return MonsterClass.values.firstWhere(
      (c) => c.level == level,
      orElse: () => MonsterClass.medium,
    );
  }
}

/// Мусорный монстр
class TrashMonster extends MapObject {
  final TrashType trashType;
  final TrashQuantity quantity;
  final MonsterClass monsterClass;
  final String description;
  final bool isCleaned;
  final String? cleanedBy;
  final DateTime? cleanedAt;

  TrashMonster({
    required super.id,
    required super.latitude,
    required super.longitude,
    required super.ownerId,
    super.ownerName,
    super.ownerReputation,
    required this.trashType,
    required this.quantity,
    required this.monsterClass,
    this.description = '',
    this.isCleaned = false,
    this.cleanedBy,
    this.cleanedAt,
    super.status,
    super.confirms,
    super.denies,
    super.views,
    super.version,
    super.expiresAt,
  }) : super(type: MapObjectType.trashMonster);

  /// Автоматический расчёт класса на основе типа и количества
  factory TrashMonster.autoClass({
    required String id,
    required double latitude,
    required double longitude,
    required String ownerId,
    String ownerName = 'Аноним',
    int ownerReputation = 0,
    required TrashType trashType,
    required TrashQuantity quantity,
    String description = '',
  }) {
    // Расчёт класса на основе типа и количества
    int classLevel = 1;

    // Тип мусора влияет на сложность
    if (trashType == TrashType.tires ||
        trashType == TrashType.furniture ||
        trashType == TrashType.construction) {
      classLevel += 2;
    } else if (trashType == TrashType.electronics) {
      classLevel += 1;
    }

    // Количество влияет на класс
    if (quantity == TrashQuantity.many) {
      classLevel += 1;
    } else if (quantity == TrashQuantity.heap) {
      classLevel += 2;
    }

    // Ограничиваем 1-5
    classLevel = classLevel.clamp(1, 5);

    return TrashMonster(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      trashType: trashType,
      quantity: quantity,
      monsterClass: MonsterClass.fromLevel(classLevel),
      description: description,
    );
  }

  @override
  String get shortDescription {
    final typeStr = '${trashType.emoji} ${trashType.name}';
    final qtyStr = quantity.name;
    return '$typeStr ($qtyStr) ${monsterClass.badge}';
  }

  @override
  bool canInteractAt(double lat, double lng, {double radiusMeters = 100}) {
    final distance = calculateDistance(latitude, longitude, lat, lng);
    return distance <= radiusMeters;
  }

  /// Очки за уборку
  int get cleaningPoints {
    return monsterClass.basePoints * quantity.estimatedCount;
  }

  /// Отметить как убранный
  TrashMonster markAsCleaned(String userId) {
    return TrashMonster(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      trashType: trashType,
      quantity: quantity,
      monsterClass: monsterClass,
      description: description,
      isCleaned: true,
      cleanedBy: userId,
      cleanedAt: DateTime.now(),
      status: MapObjectStatus.cleaned,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  @override
  Map<String, dynamic> toSyncJson() {
    return {
      ...baseJson(),
      'trashType': trashType.code,
      'quantity': quantity.code,
      'monsterClass': monsterClass.level,
      'description': description,
      'isCleaned': isCleaned,
      'cleanedBy': cleanedBy,
      'cleanedAt': cleanedAt?.toIso8601String(),
    };
  }

  factory TrashMonster.fromSyncJson(Map<String, dynamic> json) {
    return TrashMonster(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String? ?? 'Аноним',
      ownerReputation: json['ownerReputation'] as int? ?? 0,
      trashType: TrashType.fromCode(json['trashType'] as String),
      quantity: TrashQuantity.fromCode(json['quantity'] as String),
      monsterClass: MonsterClass.fromLevel(json['monsterClass'] as int? ?? 2),
      description: json['description'] as String? ?? '',
      isCleaned: json['isCleaned'] as bool? ?? false,
      cleanedBy: json['cleanedBy'] as String?,
      cleanedAt: json['cleanedAt'] != null
          ? DateTime.parse(json['cleanedAt'] as String)
          : null,
      status: MapObjectStatus.fromCode(json['status'] as String? ?? 'active'),
      confirms: json['confirms'] as int? ?? 0,
      denies: json['denies'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }
}
