import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_objects/map_objects.dart';
import '../config/constants.dart';

/// Виджет слоя объектов на карте
class MapObjectsLayer extends StatelessWidget {
  final List<MapObject> objects;
  final Function(MapObject)? onObjectTap;
  final Function(MapObject)? onObjectLongPress;
  final LatLng? userLocation;
  final double interactionRadius;

  const MapObjectsLayer({
    super.key,
    required this.objects,
    this.onObjectTap,
    this.onObjectLongPress,
    this.userLocation,
    this.interactionRadius = AppConstants.cleaningRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (objects.isEmpty) return const SizedBox.shrink();

    // Используем RepaintBoundary для изоляции перерисовок маркеров
    return RepaintBoundary(
      child: MarkerLayer(
        markers: objects.map((obj) => _buildMarker(context, obj)).toList(),
      ),
    );
  }

  Marker _buildMarker(BuildContext context, MapObject obj) {
    final isInInteractionRange = _isObjectInRange(obj);

    return Marker(
      key: ValueKey('marker_${obj.id}'),
      point: LatLng(obj.latitude, obj.longitude),
      width: _getMarkerSize(obj),
      height: _getMarkerSize(obj),
      child: GestureDetector(
        onTap: onObjectTap != null ? () => onObjectTap!(obj) : null,
        onLongPress: onObjectLongPress != null ? () => onObjectLongPress!(obj) : null,
        child: _MarkerWidget(
          key: ValueKey('marker_widget_${obj.id}'),
          object: obj,
          highlight: isInInteractionRange,
        ),
      ),
    );
  }

  /// Проверить, находится ли объект в радиусе действия
  bool _isObjectInRange(MapObject obj) {
    if (userLocation == null) return false;

    final distance = calculateDistance(
      userLocation!.latitude,
      userLocation!.longitude,
      obj.latitude,
      obj.longitude,
    );

    // Для разных типов объектов - разный радиус
    double radius = interactionRadius;
    if (obj.type == MapObjectType.creature) {
      radius = AppConstants.catchingRadius;
    } else if (obj.type == MapObjectType.secretMessage) {
      final secret = obj as SecretMessage;
      radius = secret.unlockRadius;
    }

    return distance <= radius;
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
class _MarkerWidget extends StatefulWidget {
  final MapObject object;
  final bool highlight;

  const _MarkerWidget({
    super.key,
    required this.object,
    this.highlight = false,
  });

  @override
  State<_MarkerWidget> createState() => _MarkerWidgetState();
}

class _MarkerWidgetState extends State<_MarkerWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  bool _isAnimating = false;
  
  // Кэш для предотвращения частых переключений анимации
  bool? _cachedHighlight;
  static const double _highlightHysteresis = 5.0; // метров гистерезис для предотвращения мерцания

  @override
  void initState() {
    super.initState();
    _cachedHighlight = widget.highlight;
    if (widget.highlight) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(_MarkerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Используем кэшированное значение для предотвращения частых переключений
    // Запускаем/останавливаем анимацию только при реальном изменении highlight
    if (widget.highlight && !_isAnimating) {
      _startAnimation();
    } else if (!widget.highlight && _isAnimating) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    if (_isAnimating) return;
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    
    _pulseController!.repeat(reverse: true);
    _isAnimating = true;
  }

  void _stopAnimation() {
    if (!_isAnimating) return;
    
    _pulseController?.stop();
    _pulseController?.dispose();
    _pulseController = null;
    _pulseAnimation = null;
    _isAnimating = false;
  }

  @override
  void dispose() {
    _stopAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    
    // Используем ScaleTransition вместо AnimatedBuilder + Transform.scale
    // Добавляем RepaintBoundary для изоляции анимированной области
    if (_pulseAnimation != null && _pulseController != null) {
      return RepaintBoundary(
        child: ScaleTransition(
          scale: _pulseAnimation!,
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildContent() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Внешнее кольцо (индикатор репутации)
        if (widget.object.isTrusted)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),

        // Кольцо выделения для объектов в радиусе действия
        if (widget.highlight)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.yellow.withValues(alpha: 0.8),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

        // Основной маркер
        Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.highlight
                    ? Colors.yellow.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: widget.highlight ? 8 : 4,
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
            child: _StatusBadge(object: widget.object),
          ),
      ],
    );
  }

  /// Построение содержимого маркера (эмодзи или картинка)
  Widget _buildMarkerContent() {
    // Для мусорных монстров используем картинки
    if (widget.object.type == MapObjectType.trashMonster) {
      final monster = widget.object as TrashMonster;
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

    // Для мест сбора используем картинки
    if (widget.object.type == MapObjectType.foragingSpot) {
      final spot = widget.object as ForagingSpot;
      return ClipOval(
        child: Image.asset(
          spot.itemTypeAssetPath,
          width: _getEmojiSize() * 1.5,
          height: _getEmojiSize() * 1.5,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback на эмодзи если картинка не загрузилась
            return Text(
              spot.itemTypeEmoji,
              style: TextStyle(fontSize: _getEmojiSize()),
            );
          },
        ),
      );
    }

    // Для существ тоже можно добавить картинки позже
    if (widget.object.type == MapObjectType.creature) {
      final creature = widget.object as Creature;
      return Text(
        creature.creatureType.emoji,
        style: TextStyle(fontSize: _getEmojiSize()),
      );
    }

    // Для заметок об интересных местах используем эмодзи категории
    if (widget.object.type == MapObjectType.interestNote) {
      final note = widget.object as InterestNote;
      return Text(
        note.category.emoji,
        style: TextStyle(fontSize: _getEmojiSize()),
      );
    }

    // Для напоминалок используем эмодзи персонажа
    if (widget.object.type == MapObjectType.reminderCharacter) {
      final reminder = widget.object as ReminderCharacter;
      return Text(
        reminder.characterType.emoji,
        style: TextStyle(fontSize: _getEmojiSize()),
      );
    }

    // Для остальных типов - эмодзи
    return Text(
      widget.object.type.emoji,
      style: TextStyle(fontSize: _getEmojiSize()),
    );
  }

  Color _getBackgroundColor() {
    if (widget.object.status == MapObjectStatus.hidden) {
      return Colors.grey.withValues(alpha: 0.7);
    }

    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        final monster = widget.object as TrashMonster;
        if (monster.isCleaned) {
          return Colors.green.withValues(alpha: 0.8);
        }
        return Colors.orange.withValues(alpha: 0.8);

      case MapObjectType.secretMessage:
        return Colors.purple.withValues(alpha: 0.8);

      case MapObjectType.creature:
        final creature = widget.object as Creature;
        if (!creature.isWild) {
          return Colors.blue.withValues(alpha: 0.8);
        }
        return _getRarityColor(creature.rarity);

      case MapObjectType.interestNote:
        final note = widget.object as InterestNote;
        return _getCategoryColor(note.category);

      case MapObjectType.reminderCharacter:
        return Colors.cyan.withValues(alpha: 0.8);

      case MapObjectType.foragingSpot:
        final spot = widget.object as ForagingSpot;
        // Цвет в зависимости от сезона
        if (spot.isInSeason) {
          return Colors.green.withValues(alpha: 0.8);
        }
        return Colors.brown.withValues(alpha: 0.8);

      default:
        return Colors.blue.withValues(alpha: 0.8);
    }
  }

  Color _getRarityColor(CreatureRarity rarity) {
    switch (rarity) {
      case CreatureRarity.common:
        return Colors.grey.withValues(alpha: 0.8);
      case CreatureRarity.uncommon:
        return Colors.green.withValues(alpha: 0.8);
      case CreatureRarity.rare:
        return Colors.blue.withValues(alpha: 0.8);
      case CreatureRarity.epic:
        return Colors.purple.withValues(alpha: 0.8);
      case CreatureRarity.legendary:
        return Colors.amber.withValues(alpha: 0.8);
      case CreatureRarity.mythical:
        return Colors.red.withValues(alpha: 0.8);
    }
  }

  /// Цвет для категории заметки
  Color _getCategoryColor(InterestCategory category) {
    switch (category) {
      case InterestCategory.nature:
        return Colors.green.withValues(alpha: 0.8);
      case InterestCategory.culture:
        return Colors.indigo.withValues(alpha: 0.8);
      case InterestCategory.sport:
        return Colors.orange.withValues(alpha: 0.8);
      case InterestCategory.food:
        return Colors.brown.withValues(alpha: 0.8);
      case InterestCategory.photo:
        return Colors.pink.withValues(alpha: 0.8);
      case InterestCategory.art:
        return Colors.purple.withValues(alpha: 0.8);
      case InterestCategory.games:
        return Colors.red.withValues(alpha: 0.8);
      case InterestCategory.tip:
        return Colors.amber.withValues(alpha: 0.8);
      case InterestCategory.other:
        return Colors.blue.withValues(alpha: 0.8);
    }
  }

  double _getEmojiSize() {
    if (widget.object.type == MapObjectType.creature) {
      final creature = widget.object as Creature;
      return 20.0 + creature.rarity.level * 2;
    }
    return 22.0;
  }

  bool _hasStatusIndicator() {
    if (widget.object.type == MapObjectType.trashMonster) {
      return (widget.object as TrashMonster).isCleaned;
    }
    if (widget.object.type == MapObjectType.creature) {
      return !(widget.object as Creature).isWild;
    }
    // Для заметок показываем индикатор если есть фото
    if (widget.object.type == MapObjectType.interestNote) {
      return (widget.object as InterestNote).photoIds.isNotEmpty;
    }
    // Для напоминаний показываем статус
    if (widget.object.type == MapObjectType.reminderCharacter) {
      return true;
    }
    // Для мест сбора показываем если есть фото или верифицировано
    if (widget.object.type == MapObjectType.foragingSpot) {
      final spot = widget.object as ForagingSpot;
      return spot.photoIds.isNotEmpty || spot.isVerified;
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
    } else if (object.type == MapObjectType.foragingSpot) {
      final spot = object as ForagingSpot;
      if (spot.isVerified && spot.photoIds.isNotEmpty) {
        icon = Icons.verified;
        color = Colors.green;
      } else if (spot.isVerified) {
        icon = Icons.verified;
        color = Colors.green;
      } else if (spot.photoIds.isNotEmpty) {
        icon = Icons.photo_camera;
        color = Colors.blue;
      } else {
        return const SizedBox.shrink();
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
            color: Colors.black.withValues(alpha: 0.2),
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
