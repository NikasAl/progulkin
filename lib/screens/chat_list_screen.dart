import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/p2p_message.dart' as model;
import '../providers/chat_provider.dart';
import '../services/user_id_service.dart';
import 'chat_screen.dart';

/// Экран списка чатов
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final UserIdService _userIdService = UserIdService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userInfo = await _userIdService.getUserInfo();
    if (mounted) {
      setState(() {
        _userId = userInfo.id;
      });
      context.read<ChatProvider>().init(_userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения'),
        actions: [
          // Количество непрочитанных
          Consumer<ChatProvider>(
            builder: (context, provider, child) {
              final unread = provider.totalUnreadCount;
              if (unread == 0) return const SizedBox.shrink();
              
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$unread',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.chats.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () => provider.init(_userId!),
          child: ListView.builder(
            itemCount: provider.chats.length,
            itemBuilder: (context, index) {
              return _ChatTile(
                chat: provider.chats[index],
                onTap: () => _openChat(provider.chats[index]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'Нет сообщений',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Здесь будут отображаться ваши диалоги с другими пользователями. '
              'Нажмите "Интересно" на заметке, чтобы начать общение.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(model.Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chat.chatId,
          otherUserId: chat.otherUserId,
          otherUserName: chat.otherUserName,
        ),
      ),
    );
  }
}

/// Элемент списка чатов
class _ChatTile extends StatelessWidget {
  final model.Chat chat;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(context),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.otherUserName ?? 'Пользователь',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: chat.unreadCount > 0 ? FontWeight.bold : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.lastMessageTime != null)
            Text(
              _formatTime(chat.lastMessageTime!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessageContent ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: chat.unreadCount > 0 ? null : Colors.grey[600],
                fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${chat.unreadCount}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        (chat.otherUserName ?? '?')[0].toUpperCase(),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      // Сегодня - показываем время
      return DateFormat.Hm().format(time);
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      // День недели
      final weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return weekdays[time.weekday - 1];
    } else {
      // Дата
      return DateFormat('dd.MM').format(time);
    }
  }
}
