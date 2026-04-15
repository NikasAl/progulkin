import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'full_screen_photo_view.dart';

/// Фото-галерея с модерацией
class PhotoGallery extends StatelessWidget {
  final List<Uint8List> photos;
  final List<String> photoIds;
  final List<String> photoStatuses;
  final List<Map<String, int>> photoVoteStats;
  final List<int?> userPhotoVotes;
  final String userId;
  final String? objectOwnerId;
  final void Function(String photoId, String userId, bool isConfirm)? onPhotoVote;
  final bool isLoading;

  const PhotoGallery({
    super.key,
    required this.photos,
    required this.photoIds,
    required this.photoStatuses,
    required this.photoVoteStats,
    required this.userPhotoVotes,
    required this.userId,
    this.objectOwnerId,
    this.onPhotoVote,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return _PhotoCard(
                photo: photos[index],
                photoId: photoIds.length > index ? photoIds[index] : '',
                status: photoStatuses.length > index ? photoStatuses[index] : 'pending',
                stats: photoVoteStats.length > index ? photoVoteStats[index] : {'confirms': 0, 'complaints': 0},
                userVote: userPhotoVotes.length > index ? userPhotoVotes[index] : null,
                userId: userId,
                isOwner: objectOwnerId == userId,
                onPhotoVote: onPhotoVote,
                onTap: () => _showFullScreenPhoto(context, index),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showFullScreenPhoto(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenPhotoView(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// Карточка фото с кнопками модерации
class _PhotoCard extends StatelessWidget {
  final Uint8List photo;
  final String photoId;
  final String status;
  final Map<String, int> stats;
  final int? userVote;
  final String userId;
  final bool isOwner;
  final VoidCallback onTap;
  final void Function(String photoId, String userId, bool isConfirm)? onPhotoVote;

  const _PhotoCard({
    required this.photo,
    required this.photoId,
    required this.status,
    required this.stats,
    required this.userVote,
    required this.userId,
    required this.isOwner,
    required this.onTap,
    this.onPhotoVote,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon, statusText) = _getStatusInfo();

    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 140,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: onTap,
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
                          ? _buildHiddenPlaceholder()
                          : Image.memory(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _buildStatusBadge(statusColor, statusIcon, statusText),
                ),
              ],
            ),
          ),
          if (status == 'pending' && !isOwner) ...[
            const SizedBox(height: 4),
            _buildVoteButtons(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHiddenPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hide_source, size: 32, color: Colors.grey[500]),
          Text('Скрыто', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 2),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildVoteButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _VoteButton(
          icon: Icons.thumb_up,
          label: '${stats['confirms'] ?? 0}',
          isActive: userVote != null && userVote! > 0,
          color: Colors.green,
          onTap: onPhotoVote != null ? () => onPhotoVote!(photoId, userId, true) : null,
        ),
        _VoteButton(
          icon: Icons.thumb_down,
          label: '${stats['complaints'] ?? 0}',
          isActive: userVote != null && userVote! < 0,
          color: Colors.red,
          onTap: onPhotoVote != null ? () => _showComplaintDialog(context) : null,
        ),
      ],
    );
  }

  void _showComplaintDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пожаловаться на фото?'),
        content: const Text(
          'Если фото не соответствует содержимому или нарушает правила, '
          'мы его скроем после проверки.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onPhotoVote?.call(photoId, userId, false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Пожаловаться'),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _getStatusInfo() {
    return switch (status) {
      'confirmed' => (Colors.green, Icons.verified, 'Проверено'),
      'hidden' => (Colors.red, Icons.hide_source, 'Скрыто'),
      _ => (Colors.orange, Icons.pending, 'На проверке'),
    };
  }
}

/// Кнопка голосования
class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback? onTap;

  const _VoteButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}
