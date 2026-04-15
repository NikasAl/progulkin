import 'package:flutter/material.dart';
import '../../../models/map_objects/map_objects.dart';
import 'info_row.dart';

/// Детали напоминания
class ReminderDetails extends StatelessWidget {
  final ReminderCharacter reminder;
  final String userId;
  final VoidCallback? onToggle;
  final void Function(Duration duration)? onSnooze;

  const ReminderDetails({
    super.key,
    required this.reminder,
    required this.userId,
    this.onToggle,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = reminder.ownerId == userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
          icon: Icons.face,
          label: 'Персонаж',
          value: '${reminder.characterType.emoji} ${reminder.characterType.name}',
        ),
        InfoRow(
          icon: Icons.location_on,
          label: 'Радиус срабатывания',
          value: '${reminder.triggerRadius.toInt()} м',
        ),
        InfoRow(
          icon: Icons.notifications,
          label: 'Срабатываний',
          value: '${reminder.triggeredCount}',
        ),
        // Статус
        _buildStatus(),
        // Текст напоминания
        if (reminder.reminderText.isNotEmpty) _buildReminderText(),
        // Кнопки управления (только для владельца)
        if (isOwner) ...[
          const SizedBox(height: 12),
          _buildControls(context),
        ],
      ],
    );
  }

  Widget _buildStatus() {
    String status;
    Color color;
    IconData icon;

    if (!reminder.isActive) {
      status = 'Отключено';
      color = Colors.grey;
      icon = Icons.pause_circle;
    } else if (reminder.snoozedUntil != null &&
        DateTime.now().isBefore(reminder.snoozedUntil!)) {
      status = 'Отложено до ${_formatTime(reminder.snoozedUntil!)}';
      color = Colors.orange;
      icon = Icons.schedule;
    } else {
      status = 'Активно';
      color = Colors.green;
      icon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReminderText() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(reminder.characterType.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '"${reminder.reminderText}"',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onToggle,
            icon: Icon(reminder.isActive ? Icons.pause : Icons.play_arrow),
            label: Text(reminder.isActive ? 'Отключить' : 'Включить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: reminder.isActive ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (reminder.isActive && onSnooze != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showSnoozeDialog(context),
              icon: const Icon(Icons.schedule),
              label: const Text('Отложить'),
            ),
          ),
        ],
      ],
    );
  }

  void _showSnoozeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отложить напоминание'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('На 5 минут'),
              onTap: () {
                Navigator.pop(context);
                onSnooze?.call(const Duration(minutes: 5));
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('На 30 минут'),
              onTap: () {
                Navigator.pop(context);
                onSnooze?.call(const Duration(minutes: 30));
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('На 1 час'),
              onTap: () {
                Navigator.pop(context);
                onSnooze?.call(const Duration(hours: 1));
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('До завтра'),
              onTap: () {
                Navigator.pop(context);
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                onSnooze?.call(Duration(
                  hours: tomorrow.hour,
                  minutes: tomorrow.minute,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
