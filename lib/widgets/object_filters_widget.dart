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
                color: Colors.black.withOpacity(0.1),
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
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
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
              : Colors.grey.withOpacity(0.1),
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

  const FilterToggleButton({
    super.key,
    required this.onTap,
    this.activeFilters = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Icon(
              Icons.tune,
              color: Theme.of(context).colorScheme.primary,
            ),
            if (activeFilters > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeFilters',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
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
