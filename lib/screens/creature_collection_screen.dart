import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../di/service_locator.dart';
import '../models/map_objects/creature.dart';
import '../providers/creature_provider.dart';
import '../services/user_id_service.dart';

/// Экран коллекции пойманных существ
class CreatureCollectionScreen extends StatefulWidget {
  const CreatureCollectionScreen({super.key});

  @override
  State<CreatureCollectionScreen> createState() => _CreatureCollectionScreenState();
}

class _CreatureCollectionScreenState extends State<CreatureCollectionScreen> {
  final UserIdService _userIdService = getIt<UserIdService>();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userInfo = await _userIdService.getUserInfo();
    if (mounted) {
      setState(() {
        _userId = userInfo.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('🦊 Коллекция существ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<CreatureProvider>(
      builder: (context, creatureProvider, child) {
        final collection = creatureProvider.getUserCreatureCollection(_userId!);
        final stats = creatureProvider.getCreatureCollectionStats(_userId!);

        return Scaffold(
          appBar: AppBar(
            title: const Text('🦊 Коллекция существ'),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showInfoDialog(context),
              ),
            ],
          ),
          body: collection.isEmpty
              ? _buildEmptyState(context)
              : _buildCollection(context, collection, stats),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🦊',
            style: TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 24),
          Text(
            'Ваша коллекция пуста',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Отправляйтесь на прогулку и ловите существ!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildRarityGuide(context),
        ],
      ),
    );
  }

  Widget _buildRarityGuide(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Редкость существ:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: CreatureRarity.values.map((rarity) {
              return _RarityBadge(rarity: rarity);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCollection(
    BuildContext context,
    List<Creature> collection,
    Map<String, dynamic> stats,
  ) {
    // Сортируем по редкости (редкие выше)
    final sorted = List<Creature>.from(collection)
      ..sort((a, b) => b.rarity.level.compareTo(a.rarity.level));

    return Column(
      children: [
        // Статистика
        _buildStatsCard(context, stats),

        // Список существ
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              return _CreatureCard(creature: sorted[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context, Map<String, dynamic> stats) {
    final byRarity = stats['byRarity'] as Map<CreatureRarity, int>;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.pets,
                label: 'Поймано',
                value: '${stats['total']}',
              ),
              _StatItem(
                icon: Icons.star,
                label: 'Очки',
                value: '${stats['totalPoints']}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Прогресс по редкости
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: CreatureRarity.values.map((rarity) {
              final count = byRarity[rarity] ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRarityColor(rarity).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rarity.badge} $count',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getRarityColor(rarity),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(CreatureRarity rarity) {
    switch (rarity) {
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
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('О существах'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🦊 Существа из русской мифологии появляются на карте во время прогулок.'),
              SizedBox(height: 12),
              Text('📍 Чем реже существо, тем сложнее его поймать.'),
              SizedBox(height: 12),
              Text('⏱️ Дикие существа исчезают через некоторое время.'),
              SizedBox(height: 12),
              Text('🎯 Подойдите ближе к существу, чтобы попытаться его поймать.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}

/// Карточка существа в коллекции
class _CreatureCard extends StatelessWidget {
  final Creature creature;

  const _CreatureCard({required this.creature});

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(creature.rarity);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: rarityColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Эмодзи существа
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  creature.creatureType.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Название
            Text(
              creature.creatureType.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Редкость
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${creature.rarity.badge} ${creature.rarity.name}',
                style: TextStyle(
                  fontSize: 11,
                  color: rarityColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Статистика
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MiniStat(label: 'Lvl', value: '${creature.level}'),
                _MiniStat(label: 'ATK', value: '${creature.attack}'),
                _MiniStat(label: 'DEF', value: '${creature.defense}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(CreatureRarity rarity) {
    switch (rarity) {
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
  }
}

/// Элемент статистики
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Мини-статистика
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Бейдж редкости
class _RarityBadge extends StatelessWidget {
  final CreatureRarity rarity;

  const _RarityBadge({required this.rarity});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (rarity) {
      case CreatureRarity.common:
        color = Colors.grey;
        break;
      case CreatureRarity.uncommon:
        color = Colors.green;
        break;
      case CreatureRarity.rare:
        color = Colors.blue;
        break;
      case CreatureRarity.epic:
        color = Colors.purple;
        break;
      case CreatureRarity.legendary:
        color = Colors.amber;
        break;
      case CreatureRarity.mythical:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${rarity.badge} ${rarity.name}',
        style: TextStyle(
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}
