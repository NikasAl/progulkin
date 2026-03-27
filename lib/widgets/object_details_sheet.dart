import 'package:flutter/material.dart';
import '../models/map_objects/map_objects.dart';

/// Единый виджет для отображения деталей объекта в BottomSheet
///
/// Используется как в HomeScreen так и в других местах где нужно
/// показать информацию об объекте карты.
class ObjectDetailsSheet extends StatelessWidget {
  final MapObject object;
  final String userId;
  final double? distance;
  final bool isWalking;
  final VoidCallback? onConfirm;
  final VoidCallback? onDeny;
  final VoidCallback? onAction;
  final String? actionHint;

  const ObjectDetailsSheet({
    super.key,
    required this.object,
    required this.userId,
    required this.isWalking,
    this.distance,
    this.onConfirm,
    this.onDeny,
    this.onAction,
    this.actionHint,
  });

  @override
  Widget build(BuildContext context) {
    // Определяем метку и иконку для кнопки действия
    String actionLabel;
    IconData actionIcon;
    switch (object.type) {
      case MapObjectType.trashMonster:
        actionLabel = 'Убрано!';
        actionIcon = Icons.cleaning_services;
        break;
      case MapObjectType.secretMessage:
        actionLabel = 'Прочитать';
        actionIcon = Icons.lock_open;
        break;
      case MapObjectType.creature:
        actionLabel = 'Поймать!';
        actionIcon = Icons.pets;
        break;
      default:
        actionLabel = 'Действие';
        actionIcon = Icons.check;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          _buildHeader(context),

          const SizedBox(height: 20),

          // Информация об объекте
          _buildInfoSection(context),

          const SizedBox(height: 16),

          // Статистика
          _buildStatsRow(context),

          const SizedBox(height: 20),

          // Кнопки подтверждения/опровержения
          _buildConfirmationButtons(context),

          // Кнопка действия или подсказка
          _buildActionSection(context, actionLabel, actionIcon),
        ],
      ),
    );
  }

  /// Заголовок с эмодзи и названием
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          object.type.emoji,
          style: const TextStyle(fontSize: 40),
        ),
        const SizedBox(width: 16),
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
    );
  }

  /// Получить заголовок в зависимости от типа объекта
  String _getTitle() {
    switch (object.type) {
      case MapObjectType.trashMonster:
        final monster = object as TrashMonster;
        return '${monster.trashType.emoji} ${monster.trashType.name}';
      case MapObjectType.secretMessage:
        final secret = object as SecretMessage;
        return '📜 ${secret.title}';
      case MapObjectType.creature:
        final creature = object as Creature;
        return '${creature.rarity.badge} ${creature.creatureType.name}';
      default:
        return object.type.name;
    }
  }

  /// Секция с информацией об объекте
  Widget _buildInfoSection(BuildContext context) {
    final items = <Widget>[];

    switch (object.type) {
      case MapObjectType.trashMonster:
        items.addAll(_buildTrashMonsterInfo(context));
        break;

      case MapObjectType.secretMessage:
        items.addAll(_buildSecretMessageInfo(context));
        break;

      case MapObjectType.creature:
        items.addAll(_buildCreatureInfo(context));
        break;

      default:
        break;
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(children: items);
  }

  /// Информация о мусорном монстре
  List<Widget> _buildTrashMonsterInfo(BuildContext context) {
    final monster = object as TrashMonster;
    return [
      _buildInfoRow(
        context,
        icon: Icons.layers,
        label: 'Класс',
        value: '${monster.monsterClass.badge} ${monster.monsterClass.name}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.cleaning_services,
        label: 'Количество',
        value: monster.quantity.name,
      ),
      _buildInfoRow(
        context,
        icon: Icons.star,
        label: 'Очки за уборку',
        value: '${monster.cleaningPoints}',
      ),
      if (monster.description.isNotEmpty)
        _buildInfoRow(
          context,
          icon: Icons.description,
          label: 'Описание',
          value: monster.description,
        ),
      if (monster.isCleaned) ...[
        const SizedBox(height: 8),
        _buildCleanedBadge(monster),
      ],
    ];
  }

  /// Бейдж "Убрано"
  Widget _buildCleanedBadge(TrashMonster monster) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
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

  /// Информация о секретном сообщении
  List<Widget> _buildSecretMessageInfo(BuildContext context) {
    final secret = object as SecretMessage;
    return [
      _buildInfoRow(
        context,
        icon: Icons.lock,
        label: 'Тип',
        value: secret.secretType.name,
      ),
      _buildInfoRow(
        context,
        icon: Icons.location_on,
        label: 'Радиус разблокировки',
        value: '${secret.unlockRadius.toInt()} м',
      ),
      _buildInfoRow(
        context,
        icon: Icons.visibility,
        label: 'Прочитано раз',
        value: '${secret.currentReads}',
      ),
      if (secret.isOneTime)
        _buildInfoRow(
          context,
          icon: Icons.timer,
          label: 'Одноразовое',
          value: 'Да',
        ),
    ];
  }

  /// Информация о существе
  List<Widget> _buildCreatureInfo(BuildContext context) {
    final creature = object as Creature;
    return [
      _buildInfoRow(
        context,
        icon: Icons.auto_awesome,
        label: 'Редкость',
        value: '${creature.rarity.badge} ${creature.rarity.name}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.terrain,
        label: 'Среда обитания',
        value: creature.habitat.name,
      ),
      _buildInfoRow(
        context,
        icon: Icons.favorite,
        label: 'HP',
        value: '${creature.currentHealth}/${creature.maxHealth}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.flash_on,
        label: 'Атака',
        value: '${creature.attack}',
      ),
      _buildInfoRow(
        context,
        icon: Icons.shield,
        label: 'Защита',
        value: '${creature.defense}',
      ),
      if (!creature.isWild)
        _buildInfoRow(
          context,
          icon: Icons.person,
          label: 'Владелец',
          value: creature.ownerName,
        ),
    ];
  }

  /// Строка информации
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Строка статистики
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
        const Icon(Icons.thumb_up, size: 16, color: Colors.green),
        const SizedBox(width: 4),
        Text('${object.confirms}'),
        const SizedBox(width: 12),
        const Icon(Icons.thumb_down, size: 16, color: Colors.red),
        const SizedBox(width: 4),
        Text('${object.denies}'),
        const SizedBox(width: 12),
        Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text('${object.views}'),
        if (object.isTrusted) ...[
          const SizedBox(width: 12),
          const Icon(Icons.verified, size: 16, color: Colors.green),
        ],
      ],
    );
  }

  /// Кнопки подтверждения/опровержения
  Widget _buildConfirmationButtons(BuildContext context) {
    if (onConfirm == null && onDeny == null) {
      return const SizedBox.shrink();
    }

    return Row(
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
    );
  }

  /// Секция с кнопкой действия или подсказкой
  Widget _buildActionSection(
    BuildContext context,
    String actionLabel,
    IconData actionIcon,
  ) {
    if (onAction != null) {
      return Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    if (actionHint != null) {
      return Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    actionHint!,
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
