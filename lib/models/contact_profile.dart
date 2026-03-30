/// Профиль для контакта
/// Позволяет пользователям указать как с ними связаться
class ContactProfile {
  final String userId;
  final String about;
  final String? vkLink;
  final String? maxLink;
  final ContactVisibility visibility;
  final bool acceptP2PMessages;

  const ContactProfile({
    required this.userId,
    this.about = '',
    this.vkLink,
    this.maxLink,
    this.visibility = ContactVisibility.afterApproval,
    this.acceptP2PMessages = true,
  });

  /// Есть ли какие-либо контактные данные
  bool get hasAnyContact =>
      vkLink != null || maxLink != null || acceptP2PMessages;

  /// Есть ли внешние мессенджеры
  bool get hasExternalMessengers => vkLink != null || maxLink != null;

  /// Можно ли показать контакт данному пользователю
  bool canShowContact({
    required bool isOwner,
    required bool hasInterest,
    required bool isApproved,
  }) {
    if (isOwner) return true;

    switch (visibility) {
      case ContactVisibility.afterApproval:
        return isApproved;
      case ContactVisibility.afterInterest:
        return hasInterest;
      case ContactVisibility.nobody:
        return false;
    }
  }

  /// Копировать с изменениями
  ContactProfile copyWith({
    String? about,
    String? vkLink,
    String? maxLink,
    ContactVisibility? visibility,
    bool? acceptP2PMessages,
    bool clearVkLink = false,
    bool clearMaxLink = false,
  }) {
    return ContactProfile(
      userId: userId,
      about: about ?? this.about,
      vkLink: clearVkLink ? null : (vkLink ?? this.vkLink),
      maxLink: clearMaxLink ? null : (maxLink ?? this.maxLink),
      visibility: visibility ?? this.visibility,
      acceptP2PMessages: acceptP2PMessages ?? this.acceptP2PMessages,
    );
  }

  /// Сериализация в JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'about': about,
      'vkLink': vkLink,
      'maxLink': maxLink,
      'visibility': visibility.code,
      'acceptP2PMessages': acceptP2PMessages,
    };
  }

  /// Десериализация из JSON
  factory ContactProfile.fromJson(Map<String, dynamic> json) {
    return ContactProfile(
      userId: json['userId'] as String,
      about: json['about'] as String? ?? '',
      vkLink: json['vkLink'] as String?,
      maxLink: json['maxLink'] as String?,
      visibility: ContactVisibility.fromCode(
          json['visibility'] as String? ?? 'after_approval'),
      acceptP2PMessages: json['acceptP2PMessages'] as bool? ?? true,
    );
  }
}

/// Видимость контакта
enum ContactVisibility {
  afterApproval('after_approval', 'После одобрения'),
  afterInterest('after_interest', 'После "Интересно"'),
  nobody('nobody', 'Никто'),
  ;

  final String code;
  final String name;

  const ContactVisibility(this.code, this.name);

  static ContactVisibility fromCode(String code) {
    return ContactVisibility.values.firstWhere(
      (v) => v.code == code,
      orElse: () => ContactVisibility.afterApproval,
    );
  }
}

/// Интерес к заметке
class NoteInterest {
  final String noteId;
  final String userId;
  final DateTime timestamp;
  final bool contactRequestSent;
  final bool contactApproved;

  const NoteInterest({
    required this.noteId,
    required this.userId,
    required this.timestamp,
    this.contactRequestSent = false,
    this.contactApproved = false,
  });

  /// Создать с текущим временем
  factory NoteInterest.create({
    required String noteId,
    required String userId,
  }) {
    return NoteInterest(
      noteId: noteId,
      userId: userId,
      timestamp: DateTime.now(),
    );
  }

  /// Отметить запрос на контакт
  NoteInterest withContactRequest() {
    return NoteInterest(
      noteId: noteId,
      userId: userId,
      timestamp: timestamp,
      contactRequestSent: true,
      contactApproved: contactApproved,
    );
  }

  /// Одобрить контакт
  NoteInterest withApproval() {
    return NoteInterest(
      noteId: noteId,
      userId: userId,
      timestamp: timestamp,
      contactRequestSent: contactRequestSent,
      contactApproved: true,
    );
  }

  /// Сериализация в JSON
  Map<String, dynamic> toJson() {
    return {
      'noteId': noteId,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'contactRequestSent': contactRequestSent,
      'contactApproved': contactApproved,
    };
  }

  /// Десериализация из JSON
  factory NoteInterest.fromJson(Map<String, dynamic> json) {
    return NoteInterest(
      noteId: json['noteId'] as String,
      userId: json['userId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      contactRequestSent: json['contactRequestSent'] as bool? ?? false,
      contactApproved: json['contactApproved'] as bool? ?? false,
    );
  }
}
