import 'map_object.dart';

/// Тип персонажа-напоминалки (в стиле Смешариков)
enum ReminderCharacterType {
  kopatych('kopatych', 'Копатыч', '🐻', 'Медведь-хозяйственник'),
  krosh('krosh', 'Крош', '🐰', 'Кролик-весельчак'),
  yozhik('yozhik', 'Ёжик', '🦔', 'Ёжик-философ'),
  nyusha('nyusha', 'Нюша', '🐷', 'Свинка-мечтательница'),
  karych('karych', 'Кар-Карыч', '🦉', 'Ворон-мудрец'),
  losyash('losyash', 'Лосяш', '🦌', 'Лось-учёный'),
  pin('pin', 'Пин', '🐧', 'Пингвин-изобретатель'),
  sovunya('sovunya', 'Совунья', '🦉', 'Сова-целительница'),
  ;

  final String code;
  final String name;
  final String emoji;
  final String description;

  const ReminderCharacterType(this.code, this.name, this.emoji, this.description);

  static ReminderCharacterType fromCode(String code) {
    return ReminderCharacterType.values.firstWhere(
      (c) => c.code == code,
      orElse: () => ReminderCharacterType.kopatych,
    );
  }
}

/// Смешарик-напоминалка
/// Напоминает о чём-либо когда пользователь подходит к заданному месту
class ReminderCharacter extends MapObject {
  final ReminderCharacterType characterType;
  final String reminderText;
  final double triggerRadius; // Радиус срабатывания в метрах
  final bool isActive;
  final DateTime? snoozedUntil; // Отложено до
  final int triggeredCount; // Сколько раз сработало

  ReminderCharacter({
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
    required this.characterType,
    required this.reminderText,
    this.triggerRadius = 50,
    this.isActive = true,
    this.snoozedUntil,
    this.triggeredCount = 0,
    super.status,
    super.confirms,
    super.denies,
    super.views,
    super.version,
  }) : super(type: MapObjectType.reminderCharacter);

  @override
  String get shortDescription {
    return '${characterType.emoji} $reminderText';
  }

  /// Проверить, находится ли точка в радиусе срабатывания
  bool isInRange(double lat, double lng) {
    return canInteractAt(lat, lng, radiusMeters: triggerRadius);
  }

  /// Проверить, нужно ли сработать (в радиусе, активно, не отложено)
  bool shouldTrigger(double lat, double lng) {
    if (!isActive) return false;
    if (snoozedUntil != null && DateTime.now().isBefore(snoozedUntil!)) {
      return false;
    }
    return isInRange(lat, lng);
  }

  /// Отметить срабатывание
  ReminderCharacter markTriggered() {
    return ReminderCharacter(
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
      characterType: characterType,
      reminderText: reminderText,
      triggerRadius: triggerRadius,
      isActive: isActive,
      snoozedUntil: snoozedUntil,
      triggeredCount: triggeredCount + 1,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Отложить напоминание на указанное время
  ReminderCharacter snooze(Duration duration) {
    return ReminderCharacter(
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
      characterType: characterType,
      reminderText: reminderText,
      triggerRadius: triggerRadius,
      isActive: isActive,
      snoozedUntil: DateTime.now().add(duration),
      triggeredCount: triggeredCount,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Активировать напоминание
  ReminderCharacter activate() {
    return ReminderCharacter(
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
      characterType: characterType,
      reminderText: reminderText,
      triggerRadius: triggerRadius,
      isActive: true,
      snoozedUntil: null,
      triggeredCount: triggeredCount,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Деактивировать напоминание
  ReminderCharacter deactivate() {
    return ReminderCharacter(
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
      characterType: characterType,
      reminderText: reminderText,
      triggerRadius: triggerRadius,
      isActive: false,
      snoozedUntil: snoozedUntil,
      triggeredCount: triggeredCount,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Обновить текст напоминания
  ReminderCharacter updateText(String newText) {
    return ReminderCharacter(
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
      characterType: characterType,
      reminderText: newText,
      triggerRadius: triggerRadius,
      isActive: isActive,
      snoozedUntil: snoozedUntil,
      triggeredCount: triggeredCount,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views,
      version: version + 1,
    );
  }

  /// Обновить радиус срабатывания
  ReminderCharacter updateRadius(double newRadius) {
    return ReminderCharacter(
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
      characterType: characterType,
      reminderText: reminderText,
      triggerRadius: newRadius,
      isActive: isActive,
      snoozedUntil: snoozedUntil,
      triggeredCount: triggeredCount,
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
      'characterType': characterType.code,
      'reminderText': reminderText,
      'triggerRadius': triggerRadius,
      'isActive': isActive,
      'snoozedUntil': snoozedUntil?.toIso8601String(),
      'triggeredCount': triggeredCount,
    };
  }

  factory ReminderCharacter.fromSyncJson(Map<String, dynamic> json) {
    return ReminderCharacter(
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
      characterType: ReminderCharacterType.fromCode(
          json['characterType'] as String? ?? 'kopatych'),
      reminderText: json['reminderText'] as String? ?? '',
      triggerRadius: (json['triggerRadius'] as num?)?.toDouble() ?? 50,
      isActive: json['isActive'] as bool? ?? true,
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'] as String)
          : null,
      triggeredCount: json['triggeredCount'] as int? ?? 0,
      status: MapObjectStatus.fromCode(json['status'] as String? ?? 'active'),
      confirms: json['confirms'] as int? ?? 0,
      denies: json['denies'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }
}
