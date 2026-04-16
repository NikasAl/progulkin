import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/map_objects/map_objects.dart';
import '../providers/map_object_provider.dart';
import '../config/constants.dart';

/// Виджет уведомлений о близлежащих объектах
class NearbyObjectsNotifier extends StatefulWidget {
  final double alertRadius;
  final double currentLat;
  final double currentLng;

  const NearbyObjectsNotifier({
    super.key,
    this.alertRadius = AppConstants.nearbyAlertRadius,
    required this.currentLat,
    required this.currentLng,
  });

  @override
  State<NearbyObjectsNotifier> createState() => _NearbyObjectsNotifierState();
}

class _NearbyObjectsNotifierState extends State<NearbyObjectsNotifier>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Скрываем уведомление через некоторое время
  bool _isVisible = true;
  Timer? _hideTimer;
  
  // Отслеживаем предыдущее количество объектов
  int _lastObjectCount = -1;
  Set<String> _lastObjectIds = {};
  
  // Флаг что звук уже воспроизводился для текущего набора объектов
  bool _soundPlayedForCurrentSet = false;

  // Отслеживаем новые объекты для особых уведомлений
  final Set<String> _notifiedCreatureIds = {};
  bool _initialized = false;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: AppConstants.pulseAnimationDuration,
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void didUpdateWidget(NearbyObjectsNotifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Показываем уведомление только если изменился состав объектов рядом
    // Расчёт расстояния происходит в build()
  }
  
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }
  
  /// Воспроизвести звук и вибрацию при обнаружении существа
  void _alertNewCreature(Creature creature) {
    // Вибрация
    HapticFeedback.mediumImpact();
    
    // Звук
    SystemSound.play(SystemSoundType.alert);
    
    debugPrint('🦊 Обнаружено новое существо: ${creature.creatureType.emoji} ${creature.creatureType.name}');
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapObjectProvider>(
      builder: (context, provider, child) {
        // Фильтруем объекты по расстоянию напрямую, а не через provider.nearbyObjects
        // т.к. nearbyObjects может содержать устаревшие данные если позиция не обновилась
        final nearbyObjects = provider.objects.where((obj) {
          final distance = calculateDistance(
            widget.currentLat,
            widget.currentLng,
            obj.latitude,
            obj.longitude,
          );
          return distance <= widget.alertRadius;
        }).toList();
        
        // Проверяем, изменился ли состав объектов
        final currentIds = nearbyObjects.map((o) => o.id).toSet();
        final hasChanges = !_setEquals(currentIds, _lastObjectIds);
        
        // Проверяем, есть ли новые существа
        final nearbyCreatures = nearbyObjects
            .whereType<Creature>()
            .where((c) => c.isWild && c.isAlive)
            .toList();
        
        final newCreatureIds = nearbyCreatures
            .map((c) => c.id)
            .where((id) => !_notifiedCreatureIds.contains(id))
            .toSet();
        
        // Уведомляем о новых существах
        if (newCreatureIds.isNotEmpty && _initialized) {
          for (final creature in nearbyCreatures) {
            if (newCreatureIds.contains(creature.id)) {
              _alertNewCreature(creature);
              _notifiedCreatureIds.add(creature.id);
            }
          }
        }
        
        // Запоминаем все существа которые были рядом
        for (final creature in nearbyCreatures) {
          _notifiedCreatureIds.add(creature.id);
        }
        
        // Удаляем из памяти существ, которые больше не рядом
        _notifiedCreatureIds.removeWhere((id) => !currentIds.contains(id));
        
        // Обновляем состояние при изменении объектов
        if (hasChanges && currentIds.isNotEmpty) {
          // Отложенное обновление состояния
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && currentIds.isNotEmpty) {
              setState(() {
                _lastObjectIds = currentIds;
                _lastObjectCount = nearbyObjects.length;
                _isVisible = true;
                _initialized = true;
                _soundPlayedForCurrentSet = false; // Сбрасываем флаг для нового набора
              });
              _startHideTimer();
            }
          });
        }
        
        // Инициализация при первом построении
        if (_lastObjectCount == -1 && nearbyObjects.isNotEmpty) {
          _lastObjectIds = currentIds;
          _lastObjectCount = nearbyObjects.length;
          _initialized = true;
          _soundPlayedForCurrentSet = true; // Не воспроизводим звук при первом запуске
          // Не уведомляем о существах при первом запуске
          for (final creature in nearbyCreatures) {
            _notifiedCreatureIds.add(creature.id);
          }
        }
        
        if (nearbyObjects.isEmpty || !_isVisible) {
          return const SizedBox.shrink();
        }
        
        return Dismissible(
          key: const Key('nearby_notification'),
          direction: DismissDirection.up,
          onDismissed: (_) {
            setState(() => _isVisible = false);
          },
          child: _buildNearbyIndicator(context, nearbyObjects),
        );
      },
    );
  }
  
  /// Сравнение двух множеств
  bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  Widget _buildNearbyIndicator(BuildContext context, List<MapObject> objects) {
    // Группируем по типам
    final trashCount = objects.where((o) => o.type == MapObjectType.trashMonster).length;
    final secretCount = objects.where((o) => o.type == MapObjectType.secretMessage).length;
    final creatureCount = objects.where((o) => o.type == MapObjectType.creature).length;
    
    // Напоминания - фильтруем активные
    final reminders = objects
        .whereType<ReminderCharacter>()
        .where((r) => r.shouldTrigger(widget.currentLat, widget.currentLng))
        .toList();

    // Воспроизводим звук только один раз при появлении уведомления
    if (!_soundPlayedForCurrentSet) {
      _soundPlayedForCurrentSet = true;
      _playNotificationSound();
    }

    // Если есть активные напоминания, показываем специальное уведомление
    if (reminders.isNotEmpty) {
      return _buildReminderNotification(context, reminders);
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Ограничиваем ширину уведомления
            final maxWidth = constraints.maxWidth > 400 ? 400.0 : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: maxWidth,
                child: Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.secondaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Иконка
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.near_me,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Текст
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Рядом с вами!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                _buildObjectsText(trashCount, secretCount, creatureCount),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Эмодзи объектов
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (trashCount > 0) Text('👹', style: const TextStyle(fontSize: 18)),
                            if (secretCount > 0) Text('📜', style: const TextStyle(fontSize: 18)),
                            if (creatureCount > 0) Text('🦊', style: const TextStyle(fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Специальное уведомление для напоминаний
  Widget _buildReminderNotification(BuildContext context, List<ReminderCharacter> reminders) {
    final reminder = reminders.first;
    final distance = calculateDistance(
      widget.currentLat,
      widget.currentLng,
      reminder.latitude,
      reminder.longitude,
    );

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 400 ? 400.0 : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: maxWidth,
                child: Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade300,
                          Colors.orange.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Персонаж
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              reminder.characterType.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Текст напоминания
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${reminder.characterType.name} напоминает:',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reminder.reminderText.isNotEmpty 
                                    ? reminder.reminderText 
                                    : 'Напоминание',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Расстояние
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${distance.toInt()} м',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _buildObjectsText(int trash, int secrets, int creatures) {
    final parts = <String>[];
    if (trash > 0) parts.add(_pluralizeWord(trash, 'монстр', 'монстра', 'монстров'));
    if (secrets > 0) parts.add(_pluralizeWord(secrets, 'секрет', 'секрета', 'секретов'));
    if (creatures > 0) parts.add(_pluralizeWord(creatures, 'существо', 'существа', 'существ'));

    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) return '${parts[0]} и ${parts[1]}';
    return '${parts[0]}, ${parts[1]} и ${parts[2]}';
  }

  /// Правильное склонение слов с числительными
  String _pluralizeWord(int count, String one, String few, String many) {
    final mod10 = count % 10;
    final mod100 = count % 100;

    String word;
    if (mod100 >= 11 && mod100 <= 19) {
      word = many;
    } else if (mod10 == 1) {
      word = one;
    } else if (mod10 >= 2 && mod10 <= 4) {
      word = few;
    } else {
      word = many;
    }

    return '$count $word';
  }

  /// Воспроизвести звук уведомления
  void _playNotificationSound() {
    SystemSound.play(SystemSoundType.click);
  }
}

/// Расширенное уведомление с деталями (показывается при появлении нового объекта)
class NearbyObjectAlert extends StatefulWidget {
  final MapObject object;
  final double distance;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NearbyObjectAlert({
    super.key,
    required this.object,
    required this.distance,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<NearbyObjectAlert> createState() => _NearbyObjectAlertState();
}

class _NearbyObjectAlertState extends State<NearbyObjectAlert>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _slideController.forward();
    
    // Автоскрытие через 5 секунд
    Future.delayed(AppConstants.nearbyAlertDuration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    await _slideController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getObjectColor(context);
    
    return SlideTransition(
      position: _slideAnimation,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                _dismiss();
                widget.onTap();
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Эмодзи объекта
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          widget.object.type.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Информация
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getObjectTitle(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.distance.toInt()} м от вас',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Кнопка закрытия
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: _dismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getObjectColor(BuildContext context) {
    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        return Colors.orange;
      case MapObjectType.secretMessage:
        return Colors.purple;
      case MapObjectType.creature:
        final creature = widget.object as Creature;
        switch (creature.rarity) {
          case CreatureRarity.common:
            return Colors.grey;
          case CreatureRarity.uncommon:
            return Colors.green;
          case CreatureRarity.rare:
            return Colors.blue;
          case CreatureRarity.epic:
            return Colors.purple;
          case CreatureRarity.legendary:
            return Colors.amber;
          case CreatureRarity.mythical:
            return Colors.red;
        }
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getObjectTitle() {
    switch (widget.object.type) {
      case MapObjectType.trashMonster:
        final monster = widget.object as TrashMonster;
        if (monster.isCleaned) {
          return '✅ Мусор убран!';
        }
        return '👹 Мусорный монстр!';
      case MapObjectType.secretMessage:
        final secret = widget.object as SecretMessage;
        return '📜 ${secret.title}';
      case MapObjectType.creature:
        final creature = widget.object as Creature;
        if (!creature.isWild) {
          return '🏠 ${creature.creatureType.name} приручен';
        }
        return '🦊 ${creature.creatureType.name}!';
      default:
        return 'Объект рядом';
    }
  }
}

/// Оверлей для показа уведомлений
class NearbyAlertOverlay extends StatefulWidget {
  final Widget child;
  final double alertRadius;

  const NearbyAlertOverlay({
    super.key,
    required this.child,
    this.alertRadius = AppConstants.nearbyAlertRadius,
  });

  @override
  State<NearbyAlertOverlay> createState() => _NearbyAlertOverlayState();
}

class _NearbyAlertOverlayState extends State<NearbyAlertOverlay> {
  final List<MapObject> _alerts = [];
  double? _currentLat;
  double? _currentLng;

  void showNearbyAlert(MapObject object, double distance) {
    if (_alerts.any((a) => a.id == object.id)) return;
    
    setState(() {
      _alerts.add(object);
    });
  }

  void removeAlert(MapObject object) {
    setState(() {
      _alerts.removeWhere((a) => a.id == object.id);
    });
  }

  void updatePosition(double lat, double lng) {
    _currentLat = lat;
    _currentLng = lng;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Показываем уведомления сверху
        ..._alerts.asMap().entries.map((entry) {
          final index = entry.key;
          final object = entry.value;
          
          final distance = _currentLat != null
              ? calculateDistance(
                  _currentLat!, _currentLng!,
                  object.latitude, object.longitude,
                )
              : 0.0;
          
          return Positioned(
            top: 16.0 + (index * 100),
            left: 0,
            right: 0,
            child: NearbyObjectAlert(
              object: object,
              distance: distance,
              onTap: () {
                // Открыть детали объекта
              },
              onDismiss: () => removeAlert(object),
            ),
          );
        }),
      ],
    );
  }
}
