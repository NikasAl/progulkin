import 'dart:async';
import 'package:flutter/material.dart';
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
    
    _startHideTimer();
  }
  
  @override
  void didUpdateWidget(NearbyObjectsNotifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если позиция изменилась значительно, показываем уведомление снова
    final distance = calculateDistance(
      oldWidget.currentLat, oldWidget.currentLng,
      widget.currentLat, widget.currentLng,
    );
    if (distance > 50) {
      // Больше 50 метров - показываем снова
      setState(() => _isVisible = true);
      _startHideTimer();
    }
  }
  
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    
    return Consumer<MapObjectProvider>(
      builder: (context, provider, child) {
        final nearbyObjects = provider.nearbyObjects.where((obj) {
          // Фильтруем по расстоянию
          final distance = calculateDistance(
            widget.currentLat,
            widget.currentLng,
            obj.latitude,
            obj.longitude,
          );
          return distance <= widget.alertRadius;
        }).toList();
        
        if (nearbyObjects.isEmpty) {
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

  Widget _buildNearbyIndicator(BuildContext context, List<MapObject> objects) {
    // Группируем по типам
    final trashCount = objects.where((o) => o.type == MapObjectType.trashMonster).length;
    final secretCount = objects.where((o) => o.type == MapObjectType.secretMessage).length;
    final creatureCount = objects.where((o) => o.type == MapObjectType.creature).length;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                Column(
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
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                    ),
                  ],
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
        );
      },
    );
  }

  String _buildObjectsText(int trash, int secrets, int creatures) {
    final parts = <String>[];
    if (trash > 0) parts.add('$trash монстр${_pluralize(trash, '', 'а', 'ов')}');
    if (secrets > 0) parts.add('$secrets секрет${_pluralize(secrets, '', 'а', 'ов')}');
    if (creatures > 0) parts.add('$creatures существо${_pluralize(creatures, '', 'а', '')}');
    
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) return '${parts[0]} и ${parts[1]}';
    return '${parts[0]}, ${parts[1]} и ${parts[2]}';
  }

  String _pluralize(int count, String one, String few, String many) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    
    if (mod100 >= 11 && mod100 <= 19) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
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
              color: color.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
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
                        color: Colors.white.withOpacity(0.2),
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
                              color: Colors.white.withOpacity(0.9),
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
