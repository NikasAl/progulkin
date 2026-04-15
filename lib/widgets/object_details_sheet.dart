import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/map_objects/map_objects.dart';
import '../services/p2p/map_object_storage.dart';
import 'object_details/object_details.dart';

/// Единый виджет для отображения деталей объекта в BottomSheet
///
/// Используется как в HomeScreen так и в других местах где нужно
/// показать информацию об объекте карты.
class ObjectDetailsSheet extends StatefulWidget {
  final MapObject object;
  final String userId;
  final double? distance;
  final bool isWalking;
  final VoidCallback? onConfirm;
  final VoidCallback? onDeny;
  final VoidCallback? onAction;
  final String? actionHint;
  final void Function(String noteId, String userId)? onInterestToggle;
  final void Function(InterestNote note)? onContactAuthor;
  // Управление напоминаниями
  final void Function(String reminderId)? onReminderToggle;
  final void Function(String reminderId, Duration duration)? onReminderSnooze;
  // Модерация фото
  final void Function(String photoId, String userId, bool isConfirm)? onPhotoVote;

  const ObjectDetailsSheet({
    super.key,
    required this.object,
    required this.userId,
    required this.isWalking,
    this.distance,
    this.onConfirm,
    this.onDeny,
    this.onAction,
    this.actionHint,
    this.onInterestToggle,
    this.onContactAuthor,
    this.onReminderToggle,
    this.onReminderSnooze,
    this.onPhotoVote,
  });

  @override
  State<ObjectDetailsSheet> createState() => _ObjectDetailsSheetState();
}

class _ObjectDetailsSheetState extends State<ObjectDetailsSheet> {
  final MapObjectStorage _storage = MapObjectStorage();
  List<Uint8List> _photos = [];
  List<String> _photoIds = [];
  List<String> _photoStatuses = [];
  List<Map<String, int>> _photoVoteStats = [];
  List<int?> _userPhotoVotes = [];
  bool _isLoadingPhotos = false;
  bool _isInterested = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.object.type == MapObjectType.interestNote ||
        widget.object.type == MapObjectType.trashMonster) {
      List<String> photoIds = [];
      
      if (widget.object.type == MapObjectType.interestNote) {
        final note = widget.object as InterestNote;
        photoIds = note.photoIds;
      } else if (widget.object.type == MapObjectType.trashMonster) {
        final monster = widget.object as TrashMonster;
        photoIds = monster.photoIds;
      }
      
      if (photoIds.isNotEmpty) {
        setState(() => _isLoadingPhotos = true);

        // Загружаем фото и статистику модерации
        final photos = <Uint8List>[];
        final photoStatuses = <String>[];
        final photoVoteStats = <Map<String, int>>[];
        final userPhotoVotes = <int?>[];

        for (final photoId in photoIds) {
          final photoData = await _storage.getPhoto(photoId);
          if (photoData != null && photoData['webp_data'] != null) {
            photos.add(photoData['webp_data'] as Uint8List);
            photoStatuses.add(photoData['status'] as String? ?? 'pending');
            
            // Загружаем статистику голосов
            final stats = await _storage.getPhotoVoteStats(photoId);
            photoVoteStats.add(stats);
            
            // Загружаем голос пользователя
            final userVote = await _storage.getUserPhotoVote(photoId, widget.userId);
            userPhotoVotes.add(userVote);
          }
        }

        setState(() {
          _photos = photos;
          _photoIds = photoIds;
          _photoStatuses = photoStatuses;
          _photoVoteStats = photoVoteStats;
          _userPhotoVotes = userPhotoVotes;
          _isLoadingPhotos = false;
        });
      }
      
      // Проверяем, поставил ли пользователь "Интересно" для InterestNote
      if (widget.object.type == MapObjectType.interestNote) {
        final note = widget.object as InterestNote;
        final hasInterest = await _storage.hasInterest(note.id, widget.userId);
        setState(() => _isInterested = hasInterest);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Определяем метку и иконку для кнопки действия
    String actionLabel;
    IconData actionIcon;
    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        actionLabel = 'Убрано!';
        actionIcon = Icons.cleaning_services;
        break;
      case MapObjectType.secretMessage:
        actionLabel = 'Прочитать';
        actionIcon = Icons.lock_open;
        break;
      case MapObjectType.creature:
        actionLabel = 'Поймать!';
        actionIcon = Icons.pets;
        break;
      default:
        actionLabel = 'Действие';
        actionIcon = Icons.check;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          _buildHeader(context),

          const SizedBox(height: 20),

          // Информация об объекте
          _buildInfoSection(context),

          const SizedBox(height: 16),

          // Фото-галерея для InterestNote и TrashMonster
          if (widget.object.type == MapObjectType.interestNote ||
              widget.object.type == MapObjectType.trashMonster)
            _buildPhotoGallery(context),

          // Статистика
          _buildStatsRow(context),

          const SizedBox(height: 20),

          // Кнопки для InterestNote
          if (widget.object.type == MapObjectType.interestNote)
            _buildInterestNoteButtons(context),

          // Кнопки подтверждения/опровержения
          _buildConfirmationButtons(context),

          // Кнопка действия или подсказка
          _buildActionSection(context, actionLabel, actionIcon),
        ],
      ),
    );
  }

  /// Заголовок с эмодзи и названием
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          widget.object.type.emoji,
          style: const TextStyle(fontSize: 40),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTitle(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                widget.object.shortDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Получить заголовок в зависимости от типа объекта
  String _getTitle() {
    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        final monster = widget.object as TrashMonster;
        return '${monster.trashType.emoji} ${monster.trashType.name}';
      case MapObjectType.secretMessage:
        final secret = widget.object as SecretMessage;
        return '📜 ${secret.title}';
      case MapObjectType.creature:
        final creature = widget.object as Creature;
        return '${creature.rarity.badge} ${creature.creatureType.name}';
      case MapObjectType.interestNote:
        final note = widget.object as InterestNote;
        return '${note.category.emoji} ${note.title}';
      case MapObjectType.reminderCharacter:
        final reminder = widget.object as ReminderCharacter;
        return '${reminder.characterType.emoji} Напоминание';
      default:
        return widget.object.type.name;
    }
  }

  /// Секция с информацией об объекте
  Widget _buildInfoSection(BuildContext context) {
    final items = <Widget>[];

    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        items.addAll(_buildTrashMonsterInfo(context));
        break;

      case MapObjectType.secretMessage:
        items.addAll(_buildSecretMessageInfo(context));
        break;

      case MapObjectType.creature:
        items.addAll(_buildCreatureInfo(context));
        break;

      case MapObjectType.interestNote:
        items.addAll(_buildInterestNoteInfo(context));
        break;

      case MapObjectType.reminderCharacter:
        items.addAll(_buildReminderCharacterInfo(context));
        break;

      default:
        break;
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(children: items);
  }

  /// Информация о мусорном монстре
  List<Widget> _buildTrashMonsterInfo(BuildContext context) {
    final monster = widget.object as TrashMonster;
    return [
      _buildInfoRow(
        context,
        icon: Icons.layers,
        label: 'Класс',
        value: '${monster.monsterClass.badge} ${monster.monsterClass.name}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.cleaning_services,
        label: 'Количество',
        value: monster.quantity.name,
      ),
      _buildInfoRow(
        context,
        icon: Icons.star,
        label: 'Очки за уборку',
        value: '${monster.cleaningPoints}',
      ),
      if (monster.description.isNotEmpty)
        _buildInfoRow(
          context,
          icon: Icons.description,
          label: 'Описание',
          value: monster.description,
        ),
      if (monster.isCleaned) ...[
        const SizedBox(height: 8),
        _buildCleanedBadge(monster),
      ],
    ];
  }

  /// Бейдж "Убрано"
  Widget _buildCleanedBadge(TrashMonster monster) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            'Убрано ${monster.cleanedBy == widget.userId ? "вами" : ""}',
            style: const TextStyle(color: Colors.green),
          ),
        ],
      ),
    );
  }

  /// Информация о секретном сообщении
  List<Widget> _buildSecretMessageInfo(BuildContext context) {
    final secret = widget.object as SecretMessage;
    return [
      _buildInfoRow(
        context,
        icon: Icons.lock,
        label: 'Тип',
        value: secret.secretType.name,
      ),
      _buildInfoRow(
        context,
        icon: Icons.location_on,
        label: 'Радиус разблокировки',
        value: '${secret.unlockRadius.toInt()} м',
      ),
      _buildInfoRow(
        context,
        icon: Icons.visibility,
        label: 'Прочитано раз',
        value: '${secret.currentReads}',
      ),
      if (secret.isOneTime)
        _buildInfoRow(
          context,
          icon: Icons.timer,
          label: 'Одноразовое',
          value: 'Да',
        ),
    ];
  }

  /// Информация о существе
  List<Widget> _buildCreatureInfo(BuildContext context) {
    final creature = widget.object as Creature;
    return [
      _buildInfoRow(
        context,
        icon: Icons.auto_awesome,
        label: 'Редкость',
        value: '${creature.rarity.badge} ${creature.rarity.name}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.terrain,
        label: 'Среда обитания',
        value: creature.habitat.name,
      ),
      _buildInfoRow(
        context,
        icon: Icons.favorite,
        label: 'HP',
        value: '${creature.currentHealth}/${creature.maxHealth}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.flash_on,
        label: 'Атака',
        value: '${creature.attack}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.shield,
        label: 'Защита',
        value: '${creature.defense}',
      ),
      if (!creature.isWild)
        _buildInfoRow(
          context,
          icon: Icons.person,
          label: 'Владелец',
          value: creature.ownerName,
        ),
    ];
  }

  /// Строка информации
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Информация о заметке об интересном месте
  List<Widget> _buildInterestNoteInfo(BuildContext context) {
    final note = widget.object as InterestNote;
    return [
      _buildInfoRow(
        context,
        icon: Icons.category,
        label: 'Категория',
        value: '${note.category.emoji} ${note.category.name}',
      ),
      if (note.description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            note.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      _buildInfoRow(
        context,
        icon: Icons.favorite,
        label: 'Интересуются',
        value: '${note.interestCount} человек',
      ),
    ];
  }

  /// Информация о напоминалке
  List<Widget> _buildReminderCharacterInfo(BuildContext context) {
    final reminder = widget.object as ReminderCharacter;
    final isOwner = reminder.ownerId == widget.userId;

    return [
      _buildInfoRow(
        context,
        icon: Icons.face,
        label: 'Персонаж',
        value: '${reminder.characterType.emoji} ${reminder.characterType.name}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.location_on,
        label: 'Радиус срабатывания',
        value: '${reminder.triggerRadius.toInt()} м',
      ),
      _buildInfoRow(
        context,
        icon: Icons.notifications,
        label: 'Срабатываний',
        value: '${reminder.triggeredCount}',
      ),
      // Статус
      _buildReminderStatus(reminder),
      // Текст напоминания
      if (reminder.reminderText.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(reminder.characterType.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"${reminder.reminderText}"',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      // Кнопки управления (только для владельца)
      if (isOwner) ...[
        const SizedBox(height: 12),
        _buildReminderControls(reminder),
      ],
    ];
  }

  /// Статус напоминания
  Widget _buildReminderStatus(ReminderCharacter reminder) {
    String status;
    Color color;
    IconData icon;

    if (!reminder.isActive) {
      status = 'Отключено';
      color = Colors.grey;
      icon = Icons.pause_circle;
    } else if (reminder.snoozedUntil != null && DateTime.now().isBefore(reminder.snoozedUntil!)) {
      final remaining = reminder.snoozedUntil!.difference(DateTime.now());
      status = 'Отложено на ${_formatDuration(remaining)}';
      color = Colors.orange;
      icon = Icons.schedule;
    } else {
      status = 'Активно';
      color = Colors.green;
      icon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Кнопки управления напоминанием
  Widget _buildReminderControls(ReminderCharacter reminder) {
    return Column(
      children: [
        Row(
          children: [
            // Включить/Выключить
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onReminderToggle != null
                    ? () => widget.onReminderToggle!(reminder.id)
                    : null,
                icon: Icon(reminder.isActive ? Icons.pause : Icons.play_arrow),
                label: Text(reminder.isActive ? 'Откл.' : 'Вкл.'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: reminder.isActive ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Отложить
            Expanded(
              child: OutlinedButton.icon(
                onPressed: reminder.isActive && widget.onReminderSnooze != null
                    ? () => _showSnoozeDialog(reminder.id)
                    : null,
                icon: const Icon(Icons.schedule),
                label: const Text('Отложить'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Диалог выбора времени откладывания
  void _showSnoozeDialog(String reminderId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Отложить напоминание',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('15 минут'),
              onTap: () {
                Navigator.pop(context);
                widget.onReminderSnooze?.call(reminderId, const Duration(minutes: 15));
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('30 минут'),
              onTap: () {
                Navigator.pop(context);
                widget.onReminderSnooze?.call(reminderId, const Duration(minutes: 30));
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('1 час'),
              onTap: () {
                Navigator.pop(context);
                widget.onReminderSnooze?.call(reminderId, const Duration(hours: 1));
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('2 часа'),
              onTap: () {
                Navigator.pop(context);
                widget.onReminderSnooze?.call(reminderId, const Duration(hours: 2));
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('До завтра'),
              onTap: () {
                Navigator.pop(context);
                widget.onReminderSnooze?.call(reminderId, const Duration(hours: 24));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Форматирование длительности
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}ч ${duration.inMinutes % 60}мин';
    }
    return '${duration.inMinutes} мин';
  }

  /// Фото-галерея с модерацией
  Widget _buildPhotoGallery(BuildContext context) {
    return PhotoGallery(
      photos: _photos,
      photoIds: _photoIds,
      photoStatuses: _photoStatuses,
      photoVoteStats: _photoVoteStats,
      userPhotoVotes: _userPhotoVotes,
      userId: widget.userId,
      objectOwnerId: widget.object.ownerId,
      onPhotoVote: widget.onPhotoVote,
      isLoading: _isLoadingPhotos,
    );
  }

  /// Карточка фото с кнопками модерации
  Widget _buildPhotoCard(BuildContext context, int index) {
    final status = _photoStatuses.length > index ? _photoStatuses[index] : 'pending';
    final stats = _photoVoteStats.length > index ? _photoVoteStats[index] : {'confirms': 0, 'complaints': 0};
    final userVote = _userPhotoVotes.length > index ? _userPhotoVotes[index] : null;
    final photoId = _photoIds.length > index ? _photoIds[index] : '';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.verified;
        statusText = 'Проверено';
        break;
      case 'hidden':
        statusColor = Colors.red;
        statusIcon = Icons.hide_source;
        statusText = 'Скрыто';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'На проверке';
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 140,
      child: Column(
        children: [
          // Фото
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _showFullScreenPhoto(context, index),
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: status == 'hidden' ? Colors.red.withValues(alpha: 0.5) : Colors.grey[300]!,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: status == 'hidden'
                          ? Container(
                              color: Colors.grey[300],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.hide_source, size: 32, color: Colors.grey[500]),
                                  Text('Скрыто', style: TextStyle(color: Colors.grey[500])),
                                ],
                              ),
                            )
                          : Image.memory(
                              _photos[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                    ),
                  ),
                ),
                // Статус модерации
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 10, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          statusText,
                          style: const TextStyle(color: Colors.white, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Кнопки модерации (только для pending фото и если не автор)
          if (status == 'pending' && widget.object.ownerId != widget.userId) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Подтвердить
                _buildVoteButton(
                  icon: Icons.thumb_up,
                  label: '${stats['confirms'] ?? 0}',
                  isActive: userVote != null && userVote > 0,
                  color: Colors.green,
                  onTap: widget.onPhotoVote != null
                      ? () => widget.onPhotoVote!(photoId, widget.userId, true)
                      : null,
                ),
                // Пожаловаться
                _buildVoteButton(
                  icon: Icons.thumb_down,
                  label: '${stats['complaints'] ?? 0}',
                  isActive: userVote != null && userVote < 0,
                  color: Colors.red,
                  onTap: widget.onPhotoVote != null
                      ? () => _showComplaintDialog(photoId)
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Кнопка голосования
  Widget _buildVoteButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: isActive ? 0.5 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  /// Диалог жалобы на фото
  void _showComplaintDialog(String photoId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Пожаловаться на фото?'),
        content: const Text(
          'Если фото не соответствует содержимому или нарушает правила, '
          'мы его скроем после проверки.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onPhotoVote?.call(photoId, widget.userId, false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Пожаловаться'),
          ),
        ],
      ),
    );
  }

  /// Полноэкранный просмотр фото
  void _showFullScreenPhoto(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenPhotoView(
          photos: _photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  /// Кнопки для InterestNote
  Widget _buildInterestNoteButtons(BuildContext context) {
    final note = widget.object as InterestNote;
    final isOwner = note.ownerId == widget.userId;

    return Column(
      children: [
        // Кнопка "Интересно"
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onInterestToggle != null
                ? () => widget.onInterestToggle!(note.id, widget.userId)
                : null,
            icon: Icon(_isInterested ? Icons.favorite : Icons.favorite_border),
            label: Text(_isInterested ? 'Интересно! ✓' : 'Мне интересно'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInterested ? Colors.pink[100] : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: _isInterested ? Colors.pink[800] : Theme.of(context).colorScheme.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Кнопка "Связаться" (не для своих заметок)
        if (!isOwner && note.contactVisible) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onContactAuthor != null
                  ? () => widget.onContactAuthor!(note)
                  : null,
              icon: const Icon(Icons.message),
              label: const Text('Связаться с автором'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
      ],
    );
  }

  /// Строка статистики
  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.person, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          widget.object.ownerName,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 16),
        const Icon(Icons.thumb_up, size: 16, color: Colors.green),
        const SizedBox(width: 4),
        Text('${widget.object.confirms}'),
        const SizedBox(width: 12),
        const Icon(Icons.thumb_down, size: 16, color: Colors.red),
        const SizedBox(width: 4),
        Text('${widget.object.denies}'),
        const SizedBox(width: 12),
        Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text('${widget.object.views}'),
        if (widget.object.isTrusted) ...[
          const SizedBox(width: 12),
          const Icon(Icons.verified, size: 16, color: Colors.green),
        ],
      ],
    );
  }

  /// Кнопки подтверждения/опровержения
  Widget _buildConfirmationButtons(BuildContext context) {
    if (widget.onConfirm == null && widget.onDeny == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (widget.onConfirm != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onConfirm,
              icon: const Icon(Icons.thumb_up, size: 18),
              label: const Text('Подтвердить'),
            ),
          ),
        if (widget.onConfirm != null && widget.onDeny != null)
          const SizedBox(width: 8),
        if (widget.onDeny != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onDeny,
              icon: const Icon(Icons.thumb_down, size: 18),
              label: const Text('Опровергнуть'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  /// Секция с кнопкой действия или подсказкой
  Widget _buildActionSection(
    BuildContext context,
    String actionLabel,
    IconData actionIcon,
  ) {
    if (widget.onAction != null) {
      return Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.actionHint != null) {
      return Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.actionHint!,
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

/// Полноэкранный просмотр фото
class _FullScreenPhotoView extends StatefulWidget {
  final List<Uint8List> photos;
  final int initialIndex;

  const _FullScreenPhotoView({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullScreenPhotoView> createState() => _FullScreenPhotoViewState();
}

class _FullScreenPhotoViewState extends State<_FullScreenPhotoView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                widget.photos[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
