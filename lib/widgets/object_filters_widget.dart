import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/map_objects/map_objects.dart';
import '../providers/map_object_provider.dart';

/// Виджет фильтров объектов на карте
class ObjectFiltersWidget extends StatelessWidget {
  const ObjectFiltersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MapObjectProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Фильтры объектов',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Счётчик объектов
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${provider.objects.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Фильтры по типам
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTypeFilter(
                    context,
                    provider,
                    type: MapObjectType.trashMonster,
                    emoji: '👹',
                    label: 'Монстры',
                    count: provider.objectCounts[MapObjectType.trashMonster] ?? 0,
                  ),
                  _buildTypeFilter(
                    context,
                    provider,
                    type: MapObjectType.secretMessage,
                    emoji: '📜',
                    label: 'Секреты',
                    count: provider.objectCounts[MapObjectType.secretMessage] ?? 0,
                  ),
                  _buildTypeFilter(
                    context,
                    provider,
                    type: MapObjectType.creature,
                    emoji: '🦊',
                    label: 'Существа',
                    count: provider.objectCounts[MapObjectType.creature] ?? 0,
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Дополнительные фильтры
              Row(
                children: [
                  // Показывать убранные
                  Expanded(
                    child: InkWell(
                      onTap: () => provider.setShowCleaned(!provider.showCleaned),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              provider.showCleaned 
                                  ? Icons.check_box 
                                  : Icons.check_box_outline_blank,
                              size: 18,
                              color: provider.showCleaned 
                                  ? Colors.green 
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            const Text('Убранные', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // P2P статус
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: provider.isP2PRunning 
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider.isP2PRunning ? Icons.sync : Icons.sync_disabled,
                          size: 14,
                          color: provider.isP2PRunning ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.isP2PRunning ? 'P2P' : 'Офлайн',
                          style: TextStyle(
                            fontSize: 11,
                            color: provider.isP2PRunning ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeFilter(
    BuildContext context,
    MapObjectProvider provider, {
    required MapObjectType type,
    required String emoji,
    required String label,
    required int count,
  }) {
    final isEnabled = provider.enabledTypes.contains(type);
    
    return GestureDetector(
      onTap: () => provider.toggleObjectType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isEnabled 
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled 
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: TextStyle(
                fontSize: 20,
                color: isEnabled ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isEnabled 
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Colors.grey,
              ),
            ),
            if (count > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
                  color: isEnabled 
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Кнопка для открытия панели фильтров
class FilterToggleButton extends StatelessWidget {
  final VoidCallback onTap;
  final int activeFilters;
  final bool mini;

  const FilterToggleButton({
    super.key,
    required this.onTap,
    this.activeFilters = 0,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = mini ? 40.0 : 48.0;
    final iconSize = mini ? 20.0 : 24.0;
    final badgeSize = mini ? 14.0 : 18.0;
    final badgeTextSize = mini ? 7.0 : 8.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune,
              size: iconSize,
              color: Theme.of(context).colorScheme.primary,
            ),
            if (activeFilters > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$activeFilters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: badgeTextSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
