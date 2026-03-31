import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_objects/map_objects.dart';

/// Виджет слоя объектов на карте
class MapObjectsLayer extends StatelessWidget {
  final List<MapObject> objects;
  final Function(MapObject)? onObjectTap;
  final Function(MapObject)? onObjectLongPress;

  const MapObjectsLayer({
    super.key,
    required this.objects,
    this.onObjectTap,
    this.onObjectLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (objects.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: objects.map((obj) => _buildMarker(context, obj)).toList(),
    );
  }

  Marker _buildMarker(BuildContext context, MapObject obj) {
    return Marker(
      point: LatLng(obj.latitude, obj.longitude),
      width: _getMarkerSize(obj),
      height: _getMarkerSize(obj),
      child: GestureDetector(
        onTap: onObjectTap != null ? () => onObjectTap!(obj) : null,
        onLongPress: onObjectLongPress != null ? () => onObjectLongPress!(obj) : null,
        child: _MarkerWidget(object: obj),
      ),
    );
  }

  double _getMarkerSize(MapObject obj) {
    // Большие маркеры для редких объектов
    if (obj.type == MapObjectType.creature) {
      final creature = obj as Creature;
      return 40.0 + creature.rarity.level * 5;
    }
    
    // Большие маркеры для высоких классов мусора
    if (obj.type == MapObjectType.trashMonster) {
      final monster = obj as TrashMonster;
      return 35.0 + monster.monsterClass.level * 3;
    }
    
    return 40.0;
  }
}

/// Виджет маркера объекта
class _MarkerWidget extends StatelessWidget {
  final MapObject object;

  const _MarkerWidget({required this.object});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Внешнее кольцо (индикатор репутации)
        if (object.isTrusted)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
        
        // Основной маркер
        Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: _buildMarkerContent(),
          ),
        ),
        
        // Индикатор статуса
        if (_hasStatusIndicator())
          Positioned(
            bottom: 0,
            right: 0,
            child: _StatusBadge(object: object),
          ),
      ],
    );
  }

  /// Построение содержимого маркера (эмодзи или картинка)
  Widget _buildMarkerContent() {
    // Для мусорных монстров используем картинки
    if (object.type == MapObjectType.trashMonster) {
      final monster = object as TrashMonster;
      return ClipOval(
        child: Image.asset(
          monster.trashType.assetPath,
          width: _getEmojiSize() * 1.5,
          height: _getEmojiSize() * 1.5,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback на эмодзи если картинка не загрузилась
            return Text(
              monster.trashType.emoji,
              style: TextStyle(fontSize: _getEmojiSize()),
            );
          },
        ),
      );
    }

    // Для существ тоже можно добавить картинки позже
    if (object.type == MapObjectType.creature) {
      final creature = object as Creature;
      return Text(
        creature.creatureType.emoji,
        style: TextStyle(fontSize: _getEmojiSize()),
      );
    }

    // Для заметок об интересных местах используем эмодзи категории
    if (object.type == MapObjectType.interestNote) {
      final note = object as InterestNote;
      return Text(
        note.category.emoji,
        style: TextStyle(fontSize: _getEmojiSize()),
      );
    }

    // Для напоминалок используем эмодзи персонажа
    if (object.type == MapObjectType.reminderCharacter) {
      final reminder = object as ReminderCharacter;
      return Text(
        reminder.characterType.emoji,
        style: TextStyle(fontSize: _getEmojiSize()),
      );
    }

    // Для остальных типов - эмодзи
    return Text(
      object.type.emoji,
      style: TextStyle(fontSize: _getEmojiSize()),
    );
  }

  Color _getBackgroundColor() {
    if (object.status == MapObjectStatus.hidden) {
      return Colors.grey.withOpacity(0.7);
    }

    switch (object.type) {
      case MapObjectType.trashMonster:
        final monster = object as TrashMonster;
        if (monster.isCleaned) {
          return Colors.green.withOpacity(0.8);
        }
        return Colors.orange.withOpacity(0.8);

      case MapObjectType.secretMessage:
        return Colors.purple.withOpacity(0.8);

      case MapObjectType.creature:
        final creature = object as Creature;
        if (!creature.isWild) {
          return Colors.blue.withOpacity(0.8);
        }
        return _getRarityColor(creature.rarity);

      case MapObjectType.interestNote:
        final note = object as InterestNote;
        return _getCategoryColor(note.category);

      case MapObjectType.reminderCharacter:
        return Colors.cyan.withOpacity(0.8);

      default:
        return Colors.blue.withOpacity(0.8);
    }
  }

  Color _getRarityColor(CreatureRarity rarity) {
    switch (rarity) {
      case CreatureRarity.common:
        return Colors.grey.withOpacity(0.8);
      case CreatureRarity.uncommon:
        return Colors.green.withOpacity(0.8);
      case CreatureRarity.rare:
        return Colors.blue.withOpacity(0.8);
      case CreatureRarity.epic:
        return Colors.purple.withOpacity(0.8);
      case CreatureRarity.legendary:
        return Colors.amber.withOpacity(0.8);
      case CreatureRarity.mythical:
        return Colors.red.withOpacity(0.8);
    }
  }

  /// Цвет для категории заметки
  Color _getCategoryColor(InterestCategory category) {
    switch (category) {
      case InterestCategory.nature:
        return Colors.green.withOpacity(0.8);
      case InterestCategory.culture:
        return Colors.indigo.withOpacity(0.8);
      case InterestCategory.sport:
        return Colors.orange.withOpacity(0.8);
      case InterestCategory.food:
        return Colors.brown.withOpacity(0.8);
      case InterestCategory.photo:
        return Colors.pink.withOpacity(0.8);
      case InterestCategory.art:
        return Colors.purple.withOpacity(0.8);
      case InterestCategory.games:
        return Colors.red.withOpacity(0.8);
      case InterestCategory.tip:
        return Colors.amber.withOpacity(0.8);
      case InterestCategory.other:
        return Colors.blue.withOpacity(0.8);
    }
  }

  double _getEmojiSize() {
    if (object.type == MapObjectType.creature) {
      final creature = object as Creature;
      return 20.0 + creature.rarity.level * 2;
    }
    return 22.0;
  }

  bool _hasStatusIndicator() {
    if (object.type == MapObjectType.trashMonster) {
      return (object as TrashMonster).isCleaned;
    }
    if (object.type == MapObjectType.creature) {
      return !(object as Creature).isWild;
    }
    // Для заметок показываем индикатор если есть фото
    if (object.type == MapObjectType.interestNote) {
      return (object as InterestNote).photoIds.isNotEmpty;
    }
    // Для напоминаний показываем статус
    if (object.type == MapObjectType.reminderCharacter) {
      return true;
    }
    return false;
  }
}

/// Бейдж статуса объекта
class _StatusBadge extends StatelessWidget {
  final MapObject object;

  const _StatusBadge({required this.object});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    if (object.type == MapObjectType.trashMonster) {
      final monster = object as TrashMonster;
      if (monster.isCleaned) {
        icon = Icons.check_circle;
        color = Colors.green;
      } else {
        return const SizedBox.shrink();
      }
    } else if (object.type == MapObjectType.creature) {
      final creature = object as Creature;
      if (!creature.isWild) {
        icon = Icons.favorite;
        color = Colors.pink;
      } else {
        return const SizedBox.shrink();
      }
    } else if (object.type == MapObjectType.interestNote) {
      final note = object as InterestNote;
      if (note.photoIds.isNotEmpty) {
        icon = Icons.photo_camera;
        color = Colors.blue;
      } else {
        return const SizedBox.shrink();
      }
    } else if (object.type == MapObjectType.reminderCharacter) {
      final reminder = object as ReminderCharacter;
      if (!reminder.isActive) {
        icon = Icons.pause_circle;
        color = Colors.grey;
      } else if (reminder.snoozedUntil != null && DateTime.now().isBefore(reminder.snoozedUntil!)) {
        icon = Icons.schedule;
        color = Colors.orange;
      } else {
        icon = Icons.notifications_active;
        color = Colors.cyan;
      }
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

/// Виджет информации об объекте (для BottomSheet)
class MapObjectInfoWidget extends StatelessWidget {
  final MapObject object;
  final VoidCallback? onConfirm;
  final VoidCallback? onDeny;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData? actionIcon;

  const MapObjectInfoWidget({
    super.key,
    required this.object,
    this.onConfirm,
    this.onDeny,
    this.onAction,
    this.actionLabel,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            children: [
              Text(
                object.type.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitle(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      object.shortDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Информация
          _buildInfoGrid(context),
          
          const SizedBox(height: 16),
          
          // Статистика
          _buildStatsRow(context),
          
          const SizedBox(height: 16),
          
          // Кнопки действий
          Row(
            children: [
              if (onConfirm != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.thumb_up, size: 18),
                    label: const Text('Подтвердить'),
                  ),
                ),
              if (onConfirm != null && onDeny != null)
                const SizedBox(width: 8),
              if (onDeny != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDeny,
                    icon: const Icon(Icons.thumb_down, size: 18),
                    label: const Text('Опровергнуть'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          
          if (onAction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.check),
                label: Text(actionLabel ?? 'Действие'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTitle() {
    switch (object.type) {
      case MapObjectType.trashMonster:
        final monster = object as TrashMonster;
        return '${monster.trashType.name} (${monster.quantity.name})';
      case MapObjectType.secretMessage:
        final secret = object as SecretMessage;
        return secret.title;
      case MapObjectType.creature:
        final creature = object as Creature;
        return creature.creatureType.name;
      default:
        return object.type.name;
    }
  }

  Widget _buildInfoGrid(BuildContext context) {
    final items = <Widget>[];
    
    switch (object.type) {
      case MapObjectType.trashMonster:
        final monster = object as TrashMonster;
        items.addAll([
          _buildInfoItem(
            context,
            icon: Icons.layers,
            label: 'Класс',
            value: '${monster.monsterClass.badge} ${monster.monsterClass.name}',
          ),
          _buildInfoItem(
            context,
            icon: Icons.star,
            label: 'Очки',
            value: '${monster.cleaningPoints}',
          ),
          if (monster.description.isNotEmpty)
            _buildInfoItem(
              context,
              icon: Icons.description,
              label: 'Описание',
              value: monster.description,
            ),
        ]);
        break;
        
      case MapObjectType.secretMessage:
        final secret = object as SecretMessage;
        items.addAll([
          _buildInfoItem(
            context,
            icon: Icons.lock,
            label: 'Радиус',
            value: '${secret.unlockRadius.toInt()} м',
          ),
          _buildInfoItem(
            context,
            icon: Icons.visibility,
            label: 'Прочитано',
            value: '${secret.currentReads}',
          ),
        ]);
        break;
        
      case MapObjectType.creature:
        final creature = object as Creature;
        items.addAll([
          _buildInfoItem(
            context,
            icon: Icons.auto_awesome,
            label: 'Редкость',
            value: '${creature.rarity.badge} ${creature.rarity.name}',
          ),
          _buildInfoItem(
            context,
            icon: Icons.favorite,
            label: 'HP',
            value: '${creature.currentHealth}/${creature.maxHealth}',
          ),
          _buildInfoItem(
            context,
            icon: Icons.flash_on,
            label: 'Атака',
            value: '${creature.attack}',
          ),
          _buildInfoItem(
            context,
            icon: Icons.shield,
            label: 'Защита',
            value: '${creature.defense}',
          ),
        ]);
        break;
        
      default:
        break;
    }
    
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items,
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.person, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          object.ownerName,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 16),
        Icon(Icons.thumb_up, size: 16, color: Colors.green),
        const SizedBox(width: 4),
        Text('${object.confirms}'),
        const SizedBox(width: 12),
        Icon(Icons.thumb_down, size: 16, color: Colors.red),
        const SizedBox(width: 4),
        Text('${object.denies}'),
        const SizedBox(width: 12),
        Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text('${object.views}'),
      ],
    );
  }
}
