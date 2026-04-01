import 'map_object.dart';

/// Категоря находки (грибы или ягоды)
enum ForagingCategory {
  mushroom('mushroom', 'Грибы', '🍄'),
  berry('berry', 'Ягоды', '🫐'),
  nut('nut', 'Орехи', '🥜'),
  herb('herb', 'Травы', '🌿'),
  ;

  final String code;
  final String name;
  final String emoji;

  const ForagingCategory(this.code, this.name, this.emoji);

  static ForagingCategory fromCode(String code) {
    return ForagingCategory.values.firstWhere(
      (c) => c.code == code,
      orElse: () => ForagingCategory.mushroom,
    );
  }
}

/// Тип грибов
enum MushroomType {
  white('white', 'Белый гриб', '🍄', true),
  boletus('boletus', 'Подберёзовик', '🍄', true),
  orangeCap('orange_cap', 'Подосиновик', '🍄', true),
  chanterelle('chanterelle', 'Лисичка', '🧡', true),
  honeyFungus('honey_fungus', 'Опёнок', '🍄', true),
  russula('russula', 'Сыроежка', '🍄', true),
  milkMushroom('milk_mushroom', 'Груздь', '🍄', true),
  saffronMilkCap('saffron_milk_cap', 'Рыжик', '🧡', true),
  morel('morel', 'Сморчок', '🍄', true),
  oyster('oyster', 'Вешенка', '🍄', true),
  champignon('champignon', 'Шампиньон', '🍄', true),
  porcini('porcini', 'Боровик', '🍄', true),
  otherMushroom('other_mushroom', 'Другой гриб', '🍄', null),
  ;

  final String code;
  final String name;
  final String emoji;
  final bool? edible; // null = неизвестно

  const MushroomType(this.code, this.name, this.emoji, this.edible);

  static MushroomType fromCode(String code) {
    return MushroomType.values.firstWhere(
      (m) => m.code == code,
      orElse: () => MushroomType.otherMushroom,
    );
  }
}

/// Тип ягод
enum BerryType {
  blueberry('blueberry', 'Черника', '🫐', true),
  lingonberry('lingonberry', 'Брусника', '🔴', true),
  cranberry('cranberry', 'Клюква', '🔴', true),
  cloudberry('cloudberry', 'Морошка', '🟡', true),
  strawberry('strawberry', 'Земляника', '🍓', true),
  raspberry('raspberry', 'Малина', '🟥', true),
  currant('currant', 'Смородина', '⚫', true),
  gooseberry('gooseberry', 'Крыжовник', '🟢', true),
  rowan('rowan', 'Рябина', '🟠', true),
  rosehip('rosehip', 'Шиповник', '🔴', true),
  hawthorn('hawthorn', 'Боярышник', '🔴', true),
  juniper('juniper', 'Можжевельник', '🟤', true),
  otherBerry('other_berry', 'Другая ягода', '🫐', null),
  ;

  final String code;
  final String name;
  final String emoji;
  final bool? edible; // null = неизвестно

  const BerryType(this.code, this.name, this.emoji, this.edible);

  static BerryType fromCode(String code) {
    return BerryType.values.firstWhere(
      (b) => b.code == code,
      orElse: () => BerryType.otherBerry,
    );
  }
}

/// Тип орехов
enum NutType {
  hazelnut('hazelnut', 'Лещина (фундук)', '🥜', true),
  pineNut('pine_nut', 'Кедровый орех', '🥜', true),
  walnut('walnut', 'Грецкий орех', '🥜', true),
  acorn('acorn', 'Жёлудь', '🟤', false),
  otherNut('other_nut', 'Другой орех', '🥜', null),
  ;

  final String code;
  final String name;
  final String emoji;
  final bool? edible;

  const NutType(this.code, this.name, this.emoji, this.edible);

  static NutType fromCode(String code) {
    return NutType.values.firstWhere(
      (n) => n.code == code,
      orElse: () => NutType.otherNut,
    );
  }
}

/// Тип трав
enum HerbType {
  nettle('nettle', 'Крапива', '🌿', true),
  dandelion('dandelion', 'Одуванчик', '🌼', true),
  sorrel('sorrel', 'Щавель', '🌿', true),
  wildGarlic('wild_garlic', 'Черемша', '🌿', true),
  mint('mint', 'Мята', '🌿', true),
  chamomile('chamomile', 'Ромашка', '🌼', true),
  stJohnsWort('st_johns_wort', 'Зверобой', '🌿', true),
  thyme('thyme', 'Чабрец', '🌿', true),
  yarrow('yarrow', 'Тысячелистник', '🌿', true),
  plantain('plantain', 'Подорожник', '🌿', true),
  otherHerb('other_herb', 'Другая трава', '🌿', null),
  ;

  final String code;
  final String name;
  final String emoji;
  final bool? edible;

  const HerbType(this.code, this.name, this.emoji, this.edible);

  static HerbType fromCode(String code) {
    return HerbType.values.firstWhere(
      (h) => h.code == code,
      orElse: () => HerbType.otherHerb,
    );
  }
}

/// Количество находки
enum ForagingQuantity {
  few('few', 'Немного', '1-5', 1),
  some('some', 'Средне', '5-20', 2),
  many('many', 'Много', '20-50', 3),
  abundant('abundant', 'Очень много', '50+', 4),
  ;

  final String code;
  final String name;
  final String range;
  final int level;

  const ForagingQuantity(this.code, this.name, this.range, this.level);

  static ForagingQuantity fromCode(String code) {
    return ForagingQuantity.values.firstWhere(
      (q) => q.code == code,
      orElse: () => ForagingQuantity.some,
    );
  }
}

/// Сезон находки
enum ForagingSeason {
  spring('spring', 'Весна', '🌸', [3, 4, 5]),
  summer('summer', 'Лето', '☀️', [6, 7, 8]),
  autumn('autumn', 'Осень', '🍂', [9, 10, 11]),
  winter('winter', 'Зима', '❄️', [12, 1, 2]),
  allYear('all_year', 'Круглый год', '📅', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
  ;

  final String code;
  final String name;
  final String emoji;
  final List<int> months;

  const ForagingSeason(this.code, this.name, this.emoji, this.months);

  static ForagingSeason fromCode(String code) {
    return ForagingSeason.values.firstWhere(
      (s) => s.code == code,
      orElse: () => ForagingSeason.summer,
    );
  }

  static ForagingSeason currentSeason() {
    final month = DateTime.now().month;
    return values.firstWhere(
      (s) => s.months.contains(month),
      orElse: () => ForagingSeason.summer,
    );
  }

  bool get isCurrentSeason => months.contains(DateTime.now().month);
}

/// Место для сбора грибов, ягод, орехов, трав
class ForagingSpot extends MapObject {
  final ForagingCategory category;
  final String itemTypeCode; // Код конкретного типа (MushroomType, BerryType и т.д.)
  final ForagingQuantity quantity;
  final ForagingSeason season;
  final String notes;        // Заметки пользователя
  final bool isVerified;     // Подтверждено другими пользователями
  final int harvestCount;    // Сколько раз собирали здесь
  final DateTime? lastHarvest; // Последний сбор
  final double accessibility; // Доступность (0-1, насколько легко добраться)

  ForagingSpot({
    required super.id,
    required super.latitude,
    required super.longitude,
    required super.ownerId,
    super.ownerName,
    super.ownerReputation,
    super.createdAt,
    super.updatedAt,
    super.expiresAt,
    super.deletedAt,
    required this.category,
    required this.itemTypeCode,
    required this.quantity,
    this.season = ForagingSeason.summer,
    this.notes = '',
    this.isVerified = false,
    this.harvestCount = 0,
    this.lastHarvest,
    this.accessibility = 0.5,
    super.status,
    super.confirms,
    super.denies,
    super.views,
    super.version,
  }) : super(type: MapObjectType.foragingSpot);

  /// Получить название типа находки
  String get itemTypeName {
    switch (category) {
      case ForagingCategory.mushroom:
        return MushroomType.fromCode(itemTypeCode).name;
      case ForagingCategory.berry:
        return BerryType.fromCode(itemTypeCode).name;
      case ForagingCategory.nut:
        return NutType.fromCode(itemTypeCode).name;
      case ForagingCategory.herb:
        return HerbType.fromCode(itemTypeCode).name;
    }
  }

  /// Получить эмодзи типа находки
  String get itemTypeEmoji {
    switch (category) {
      case ForagingCategory.mushroom:
        return MushroomType.fromCode(itemTypeCode).emoji;
      case ForagingCategory.berry:
        return BerryType.fromCode(itemTypeCode).emoji;
      case ForagingCategory.nut:
        return NutType.fromCode(itemTypeCode).emoji;
      case ForagingCategory.herb:
        return HerbType.fromCode(itemTypeCode).emoji;
    }
  }

  /// Съедобно ли
  bool? get isEdible {
    switch (category) {
      case ForagingCategory.mushroom:
        return MushroomType.fromCode(itemTypeCode).edible;
      case ForagingCategory.berry:
        return BerryType.fromCode(itemTypeCode).edible;
      case ForagingCategory.nut:
        return NutType.fromCode(itemTypeCode).edible;
      case ForagingCategory.herb:
        return HerbType.fromCode(itemTypeCode).edible;
    }
  }

  /// Актуально ли сейчас (сезон)
  bool get isInSeason => season.isCurrentSeason;

  @override
  String get shortDescription {
    final verifiedIcon = isVerified ? '✅' : '';
    final seasonIcon = isInSeason ? '🌟' : '';
    return '$itemTypeEmoji $itemTypeName $verifiedIcon$seasonIcon';
  }

  /// Отметить сбор
  ForagingSpot markHarvest() {
    return ForagingSpot(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      expiresAt: expiresAt,
      deletedAt: deletedAt,
      category: category,
      itemTypeCode: itemTypeCode,
      quantity: quantity,
      season: season,
      notes: notes,
      isVerified: isVerified,
      harvestCount: harvestCount + 1,
      lastHarvest: DateTime.now(),
      accessibility: accessibility,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Подтвердить место
  ForagingSpot verify() {
    return ForagingSpot(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      expiresAt: expiresAt,
      deletedAt: deletedAt,
      category: category,
      itemTypeCode: itemTypeCode,
      quantity: quantity,
      season: season,
      notes: notes,
      isVerified: true,
      harvestCount: harvestCount,
      lastHarvest: lastHarvest,
      accessibility: accessibility,
      status: MapObjectStatus.confirmed,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  @override
  Map<String, dynamic> toSyncJson() {
    return {
      ...super.toSyncJson(),
      'category': category.code,
      'itemTypeCode': itemTypeCode,
      'quantity': quantity.code,
      'season': season.code,
      'notes': notes,
      'isVerified': isVerified,
      'harvestCount': harvestCount,
      'lastHarvest': lastHarvest?.toIso8601String(),
      'accessibility': accessibility,
    };
  }

  factory ForagingSpot.fromSyncJson(Map<String, dynamic> json) {
    return ForagingSpot(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String? ?? 'Аноним',
      ownerReputation: json['ownerReputation'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      category: ForagingCategory.fromCode(json['category'] as String? ?? 'mushroom'),
      itemTypeCode: json['itemTypeCode'] as String? ?? 'other_mushroom',
      quantity: ForagingQuantity.fromCode(json['quantity'] as String? ?? 'some'),
      season: ForagingSeason.fromCode(json['season'] as String? ?? 'summer'),
      notes: json['notes'] as String? ?? '',
      isVerified: json['isVerified'] as bool? ?? false,
      harvestCount: json['harvestCount'] as int? ?? 0,
      lastHarvest: json['lastHarvest'] != null
          ? DateTime.parse(json['lastHarvest'] as String)
          : null,
      accessibility: (json['accessibility'] as num?)?.toDouble() ?? 0.5,
      status: MapObjectStatus.fromCode(json['status'] as String? ?? 'active'),
      confirms: json['confirms'] as int? ?? 0,
      denies: json['denies'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }
}
