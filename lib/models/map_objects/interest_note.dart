import 'map_object.dart';

/// Категория заметки об интересном месте
enum InterestCategory {
  nature('nature', 'Природа', '🐿️', 'Животные, растения, красивые места'),
  culture('culture', 'Культура', '📚', 'Библиотеки, музеи, книжные'),
  sport('sport', 'Спорт', '🏃', 'Турники, беговые маршруты, йога'),
  food('food', 'Еда', '☕', 'Кофейни, необычные места'),
  photo('photo', 'Фото', '📸', 'Лучшие точки съёмки'),
  art('art', 'Творчество', '🎨', 'Стрит-арт, мастерские'),
  games('games', 'Игры', '🎮', 'Покемоны, геокешинг'),
  tip('tip', 'Совет', '💡', 'Лайфхаки района'),
  other('other', 'Другое', '❓', 'Всё остальное'),
  ;

  final String code;
  final String name;
  final String emoji;
  final String description;

  const InterestCategory(this.code, this.name, this.emoji, this.description);

  static InterestCategory fromCode(String code) {
    return InterestCategory.values.firstWhere(
      (c) => c.code == code,
      orElse: () => InterestCategory.other,
    );
  }
}

/// Заметка об интересном месте
/// Позволяет отмечать интересные места и находить единомышленников
class InterestNote extends MapObject {
  final InterestCategory category;
  final String title;
  final String description;
  final List<String> photoIds; // ID фото в хранилище
  final int interestCount;
  final List<String> interestedUserIds;
  final bool contactVisible;

  InterestNote({
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
    required this.title,
    this.description = '',
    List<String>? photoIds,
    this.interestCount = 0,
    List<String>? interestedUserIds,
    this.contactVisible = false,
    super.status,
    super.confirms,
    super.denies,
    super.views,
    super.version,
  })  : photoIds = photoIds ?? [],
        interestedUserIds = interestedUserIds ?? [],
        super(type: MapObjectType.interestNote);

  @override
  String get shortDescription {
    return '${category.emoji} $title';
  }

  /// Добавить "Интересно" от пользователя
  InterestNote addInterest(String userId) {
    if (interestedUserIds.contains(userId)) return this;

    return InterestNote(
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
      title: title,
      description: description,
      photoIds: photoIds,
      interestCount: interestCount + 1,
      interestedUserIds: [...interestedUserIds, userId],
      contactVisible: contactVisible,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Убрать "Интересно" от пользователя
  InterestNote removeInterest(String userId) {
    if (!interestedUserIds.contains(userId)) return this;

    return InterestNote(
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
      title: title,
      description: description,
      photoIds: photoIds,
      interestCount: interestCount - 1,
      interestedUserIds: interestedUserIds.where((id) => id != userId).toList(),
      contactVisible: contactVisible,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Проверить, поставил ли пользователь "Интересно"
  bool hasInterestFrom(String userId) => interestedUserIds.contains(userId);

  /// Показать контакт автора
  InterestNote showContact() {
    return InterestNote(
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
      title: title,
      description: description,
      photoIds: photoIds,
      interestCount: interestCount,
      interestedUserIds: interestedUserIds,
      contactVisible: true,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Скрыть контакт автора
  InterestNote hideContact() {
    return InterestNote(
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
      title: title,
      description: description,
      photoIds: photoIds,
      interestCount: interestCount,
      interestedUserIds: interestedUserIds,
      contactVisible: false,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Добавить фото
  InterestNote addPhoto(String photoId) {
    return InterestNote(
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
      title: title,
      description: description,
      photoIds: [...photoIds, photoId],
      interestCount: interestCount,
      interestedUserIds: interestedUserIds,
      contactVisible: contactVisible,
      status: status,
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
      'title': title,
      'description': description,
      'photoIds': photoIds,
      'interestCount': interestCount,
      'interestedUserIds': interestedUserIds,
      'contactVisible': contactVisible,
    };
  }

  factory InterestNote.fromSyncJson(Map<String, dynamic> json) {
    return InterestNote(
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
      category: InterestCategory.fromCode(json['category'] as String? ?? 'other'),
      title: json['title'] as String? ?? 'Без названия',
      description: json['description'] as String? ?? '',
      photoIds: (json['photoIds'] as List?)?.map((e) => e as String).toList(),
      interestCount: json['interestCount'] as int? ?? 0,
      interestedUserIds:
          (json['interestedUserIds'] as List?)?.map((e) => e as String).toList(),
      contactVisible: json['contactVisible'] as bool? ?? false,
      status: MapObjectStatus.fromCode(json['status'] as String? ?? 'active'),
      confirms: json['confirms'] as int? ?? 0,
      denies: json['denies'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }
}
