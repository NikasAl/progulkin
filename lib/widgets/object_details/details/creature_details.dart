import 'package:flutter/material.dart';
import '../../../models/map_objects/map_objects.dart';
import 'info_row.dart';

/// Детали существа
class CreatureDetails extends StatelessWidget {
  final Creature creature;

  const CreatureDetails({
    super.key,
    required this.creature,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
          icon: Icons.auto_awesome,
          label: 'Редкость',
          value: '${creature.rarity.badge} ${creature.rarity.name}',
        ),
        InfoRow(
          icon: Icons.terrain,
          label: 'Среда обитания',
          value: creature.habitat.name,
        ),
        InfoRow(
          icon: Icons.favorite,
          label: 'HP',
          value: '${creature.currentHealth}/${creature.maxHealth}',
        ),
        InfoRow(
          icon: Icons.flash_on,
          label: 'Атака',
          value: '${creature.attack}',
        ),
        InfoRow(
          icon: Icons.shield,
          label: 'Защита',
          value: '${creature.defense}',
        ),
        if (!creature.isWild)
          InfoRow(
            icon: Icons.person,
            label: 'Владелец',
            value: creature.ownerName,
          ),
      ],
    );
  }
}
