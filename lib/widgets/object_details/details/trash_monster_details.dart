import 'package:flutter/material.dart';
import '../../../models/map_objects/map_objects.dart';
import 'info_row.dart';

/// Детали мусорного монстра
class TrashMonsterDetails extends StatelessWidget {
  final TrashMonster monster;
  final String userId;

  const TrashMonsterDetails({
    super.key,
    required this.monster,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
          icon: Icons.layers,
          label: 'Класс',
          value: '${monster.monsterClass.badge} ${monster.monsterClass.name}',
        ),
        InfoRow(
          icon: Icons.cleaning_services,
          label: 'Количество',
          value: monster.quantity.name,
        ),
        InfoRow(
          icon: Icons.star,
          label: 'Очки за уборку',
          value: '${monster.cleaningPoints}',
        ),
        if (monster.description.isNotEmpty)
          InfoRow(
            icon: Icons.description,
            label: 'Описание',
            value: monster.description,
          ),
        if (monster.isCleaned) ...[
          const SizedBox(height: 8),
          _buildCleanedBadge(),
        ],
      ],
    );
  }

  Widget _buildCleanedBadge() {
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
            'Убрано ${monster.cleanedBy == userId ? "вами" : ""}',
            style: const TextStyle(color: Colors.green),
          ),
        ],
      ),
    );
  }
}
