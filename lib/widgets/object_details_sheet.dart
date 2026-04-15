import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/map_objects/map_objects.dart';
import '../services/p2p/map_object_storage.dart';
import 'object_details/object_details.dart';
import 'object_details/details/details.dart';

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

        final photos = <Uint8List>[];
        final photoStatuses = <String>[];
        final photoVoteStats = <Map<String, int>>[];
        final userPhotoVotes = <int?>[];

        for (final photoId in photoIds) {
          final photoData = await _storage.getPhoto(photoId);
          if (photoData != null && photoData['webp_data'] != null) {
            photos.add(photoData['webp_data'] as Uint8List);
            photoStatuses.add(photoData['status'] as String? ?? 'pending');

            final stats = await _storage.getPhotoVoteStats(photoId);
            photoVoteStats.add(stats);

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

      if (widget.object.type == MapObjectType.interestNote) {
        final note = widget.object as InterestNote;
        final hasInterest = await _storage.hasInterest(note.id, widget.userId);
        setState(() => _isInterested = hasInterest);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (actionLabel, actionIcon) = _getActionInfo();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildInfoSection(context),
          const SizedBox(height: 12),
          _buildPhotoGallery(context),
          _buildActionSection(context, actionLabel, actionIcon),
          _buildTypeSpecificButtons(context),
          const Divider(height: 32),
          _buildStatsRow(context),
          const SizedBox(height: 12),
          _buildConfirmationButtons(context),
        ],
      ),
    );
  }

  (String, IconData) _getActionInfo() {
    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        return ('Убрано!', Icons.cleaning_services);
      case MapObjectType.secretMessage:
        return ('Прочитать', Icons.lock_open);
      case MapObjectType.creature:
        return ('Поймать!', Icons.pets);
      default:
        return ('Действие', Icons.check);
    }
  }

  Widget _buildHeader(BuildContext context) {
    String title;
    String emoji;

    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        final monster = widget.object as TrashMonster;
        title = monster.isCleaned ? 'Монстер убран' : 'Мусорный монстр';
        emoji = monster.isCleaned ? '✅' : '👹';
        break;
      case MapObjectType.secretMessage:
        title = 'Секретное сообщение';
        emoji = '📜';
        break;
      case MapObjectType.creature:
        final creature = widget.object as Creature;
        title = creature.isWild ? 'Дикое существо' : 'Существо';
        emoji = creature.creatureType.emoji;
        break;
      case MapObjectType.interestNote:
        final note = widget.object as InterestNote;
        title = note.title;
        emoji = note.category.emoji;
        break;
      case MapObjectType.reminderCharacter:
        final reminder = widget.object as ReminderCharacter;
        title = 'Напоминание';
        emoji = reminder.characterType.emoji;
        break;
      default:
        title = 'Объект';
        emoji = '📍';
    }

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.distance != null)
                Text(
                  '${widget.distance!.toStringAsFixed(0)} м от вас',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        return TrashMonsterDetails(
          monster: widget.object as TrashMonster,
          userId: widget.userId,
        );

      case MapObjectType.secretMessage:
        return SecretMessageDetails(
          secret: widget.object as SecretMessage,
        );

      case MapObjectType.creature:
        return CreatureDetails(
          creature: widget.object as Creature,
        );

      case MapObjectType.interestNote:
        return InterestNoteDetails(
          note: widget.object as InterestNote,
        );

      case MapObjectType.reminderCharacter:
        return ReminderDetails(
          reminder: widget.object as ReminderCharacter,
          userId: widget.userId,
          onToggle: widget.onReminderToggle != null
              ? () => widget.onReminderToggle!((widget.object as ReminderCharacter).id)
              : null,
          onSnooze: widget.onReminderSnooze != null
              ? (duration) => widget.onReminderSnooze!(
                    (widget.object as ReminderCharacter).id,
                    duration,
                  )
              : null,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Фото-галерея с модерацией
  Widget _buildPhotoGallery(BuildContext context) {
    if (_photos.isEmpty && !_isLoadingPhotos) {
      return const SizedBox.shrink();
    }

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

  Widget _buildTypeSpecificButtons(BuildContext context) {
    if (widget.object.type == MapObjectType.interestNote) {
      return _buildInterestNoteButtons(context);
    }
    return const SizedBox.shrink();
  }

  /// Кнопки для InterestNote
  Widget _buildInterestNoteButtons(BuildContext context) {
    final note = widget.object as InterestNote;
    final isOwner = note.ownerId == widget.userId;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onInterestToggle != null
                ? () => widget.onInterestToggle!(note.id, widget.userId)
                : null,
            icon: Icon(_isInterested ? Icons.favorite : Icons.favorite_border),
            label: Text(_isInterested ? 'Интересно! ✓' : 'Мне интересно'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInterested
                  ? Colors.pink[100]
                  : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: _isInterested
                  ? Colors.pink[800]
                  : Theme.of(context).colorScheme.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
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
