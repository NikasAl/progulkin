/// P2P сообщение для мессенджера
class P2PMessage {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String content;
  final DateTime timestamp;
  final bool delivered;
  final bool read;

  const P2PMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.content,
    required this.timestamp,
    this.delivered = false,
    this.read = false,
  });

  /// Создать новое сообщение
  factory P2PMessage.create({
    required String id,
    required String fromUserId,
    required String toUserId,
    required String content,
  }) {
    return P2PMessage(
      id: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// ID чата (уникальный для пары пользователей)
  static String chatId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Получить ID чата для этого сообщения
  String get chatIdValue => chatId(fromUserId, toUserId);

  /// Является ли входящим для данного пользователя
  bool isIncomingFor(String userId) => toUserId == userId;

  /// Является ли исходящим для данного пользователя
  bool isOutgoingFor(String userId) => fromUserId == userId;

  /// Отметить как доставленное
  P2PMessage markDelivered() {
    return P2PMessage(
      id: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      content: content,
      timestamp: timestamp,
      delivered: true,
      read: read,
    );
  }

  /// Отметить как прочитанное
  P2PMessage markRead() {
    return P2PMessage(
      id: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      content: content,
      timestamp: timestamp,
      delivered: true,
      read: true,
    );
  }

  /// Сериализация для P2P синхронизации
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'delivered': delivered,
      'read': read,
    };
  }

  /// Десериализация
  factory P2PMessage.fromJson(Map<String, dynamic> json) {
    return P2PMessage(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      delivered: json['delivered'] as bool? ?? false,
      read: json['read'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'P2PMessage($id, $fromUserId -> $toUserId)';
}

/// Чат (диалог между двумя пользователями)
class Chat {
  final String chatId;
  final String otherUserId;
  final String? otherUserName;
  final String? lastMessageContent;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool otherUserOnline;

  const Chat({
    required this.chatId,
    required this.otherUserId,
    this.otherUserName,
    this.lastMessageContent,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.otherUserOnline = false,
  });

  /// Создать ID чата для пары пользователей
  static String idFor(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Копировать с обновлениями
  Chat copyWith({
    String? otherUserName,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? otherUserOnline,
  }) {
    return Chat(
      chatId: chatId,
      otherUserId: otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      otherUserOnline: otherUserOnline ?? this.otherUserOnline,
    );
  }
}
