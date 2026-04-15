import 'package:flutter/material.dart';
import '../../models/map_objects/map_objects.dart';

/// Bottom sheet для связи с автором заметки
class ContactAuthorSheet extends StatelessWidget {
  final InterestNote note;

  const ContactAuthorSheet({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Text(note.category.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Связаться с автором',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        note.ownerName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Заметка
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (note.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(note.description),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Варианты связи
            const Text(
              'Способы связи:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // VK
            _buildContactOption(
              context: context,
              icon: Icons.language,
              iconColor: Colors.white,
              iconBackgroundColor: Colors.blue[700]!,
              title: 'ВКонтакте',
              subtitle: 'Написать сообщение',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Открытие VK... (в разработке)')),
                );
              },
            ),

            // Max
            _buildContactOption(
              context: context,
              icon: Icons.chat,
              iconColor: Colors.white,
              iconBackgroundColor: Colors.purple[600]!,
              title: 'Max Messenger',
              subtitle: 'Написать сообщение',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Открытие Max... (в разработке)')),
                );
              },
            ),

            // P2P
            _buildContactOption(
              context: context,
              icon: Icons.wifi,
              iconColor: Colors.white,
              iconBackgroundColor: Colors.green[600]!,
              title: 'P2P сообщение',
              subtitle: 'Написать напрямую через приложение',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('P2P чат в разработке')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBackgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Показать диалог связи с автором
void showContactAuthorSheet(BuildContext context, InterestNote note) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ContactAuthorSheet(note: note),
  );
}
