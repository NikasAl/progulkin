import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/p2p_message.dart' as model;
import '../services/p2p/p2p.dart';
import '../di/service_locator.dart';

/// Провайдер для управления P2P чатами
class ChatProvider extends ChangeNotifier {
  final MapObjectStorage _storage = getIt<MapObjectStorage>();
  final Uuid _uuid = const Uuid();

  List<model.Chat> _chats = [];
  final Map<String, List<model.P2PMessage>> _messagesByChat = {};
  bool _isLoading = false;
  String? _error;

  // Геттеры
  List<model.Chat> get chats => _chats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Инициализация - загрузка чатов
  Future<void> init(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Загружаем список чатов
      await _loadChats(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ Ошибка загрузки чатов: $e');
      notifyListeners();
    }
  }

  /// Загрузить чаты пользователя
  Future<void> _loadChats(String userId) async {
    final chatData = await _storage.getChatList(userId);
    
    _chats = chatData.map((data) {
      return model.Chat(
        chatId: model.Chat.idFor(userId, data['other_user_id'] as String),
        otherUserId: data['other_user_id'] as String,
        otherUserName: data['other_user_name'] as String?,
        lastMessageContent: data['last_message'] as String?,
        lastMessageTime: data['last_message_time'] != null
            ? DateTime.parse(data['last_message_time'] as String)
            : null,
        unreadCount: data['unread_count'] as int? ?? 0,
      );
    }).toList();

    // Сортируем по времени последнего сообщения
    _chats.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
  }

  /// Загрузить сообщения чата
  Future<List<model.P2PMessage>> loadChatMessages(String chatId, String userId) async {
    // Определяем ID собеседника из chatId
    final parts = chatId.split('_');
    String otherUserId;
    if (parts[0] == userId) {
      otherUserId = parts[1];
    } else {
      otherUserId = parts[0];
    }

    final messagesData = await _storage.getChatMessages(userId, otherUserId);
    
    final messages = messagesData.map((data) {
      return model.P2PMessage.fromJson({
        'id': data['id'],
        'fromUserId': data['from_user_id'],
        'toUserId': data['to_user_id'],
        'content': data['content'],
        'timestamp': data['timestamp'],
        'delivered': data['delivered'] == 1,
        'read': data['read'] == 1,
      });
    }).toList();

    // Сортируем по времени
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Кэшируем
    _messagesByChat[chatId] = messages.cast<model.P2PMessage>();

    return messages.cast<model.P2PMessage>();
  }

  /// Отправить сообщение
  Future<model.P2PMessage> sendMessage({
    required String fromUserId,
    required String toUserId,
    required String content,
  }) async {
    final message = model.P2PMessage.create(
      id: _uuid.v4(),
      fromUserId: fromUserId,
      toUserId: toUserId,
      content: content,
    );

    // Сохраняем в базу
    await _storage.saveMessage(message.toJson());

    // Обновляем кэш
    final chatId = model.Chat.idFor(fromUserId, toUserId);
    if (_messagesByChat.containsKey(chatId)) {
      _messagesByChat[chatId]!.add(message);
    } else {
      _messagesByChat[chatId] = [message];
    }

    // Обновляем список чатов
    await _updateChatList(fromUserId);

    notifyListeners();
    return message;
  }

  /// Получить входящее сообщение от P2P
  Future<void> receiveMessage(Map<String, dynamic> messageData, String userId) async {
    // Сохраняем в базу
    await _storage.saveMessage(messageData);

    final message = model.P2PMessage.fromJson(messageData);
    final chatId = model.Chat.idFor(message.fromUserId, message.toUserId);

    // Обновляем кэш
    if (_messagesByChat.containsKey(chatId)) {
      _messagesByChat[chatId]!.add(message);
    } else {
      _messagesByChat[chatId] = [message];
    }

    // Обновляем список чатов
    await _loadChats(userId);

    notifyListeners();
  }

  /// Отметить сообщения как прочитанные
  Future<void> markAsRead(String chatId, String userId) async {
    final parts = chatId.split('_');
    String otherUserId;
    if (parts[0] == userId) {
      otherUserId = parts[1];
    } else {
      otherUserId = parts[0];
    }

    await _storage.markMessagesAsRead(otherUserId, userId);

    // Обновляем чат
    final chatIndex = _chats.indexWhere((c) => c.chatId == chatId);
    if (chatIndex >= 0) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
    }

    notifyListeners();
  }

  /// Обновить список чатов
  Future<void> _updateChatList(String userId) async {
    await _loadChats(userId);
  }

  /// Получить количество непрочитанных сообщений
  int get totalUnreadCount {
    return _chats.fold(0, (sum, chat) => sum + chat.unreadCount);
  }

  /// Получить чат по ID
  model.Chat? getChat(String chatId) {
    try {
      return _chats.firstWhere((c) => c.chatId == chatId);
    } catch (_) {
      return null;
    }
  }

  /// Получить сообщения чата из кэша
  List<model.P2PMessage>? getCachedMessages(String chatId) {
    return _messagesByChat[chatId];
  }

  /// Очистить кэш сообщений
  void clearCache() {
    _messagesByChat.clear();
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }
}
