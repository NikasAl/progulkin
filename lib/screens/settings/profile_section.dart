import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_id_service.dart';
import '../profile_screen.dart';

/// Секция профиля пользователя в настройках
class ProfileSection extends StatelessWidget {
  final UserIdService userIdService;
  final VoidCallback onUpdate;

  const ProfileSection({
    super.key,
    required this.userIdService,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserInfo>(
      future: userIdService.getUserInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final user = snapshot.data!;
        final isDefaultName = user.name == 'Прогульщик';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Профиль',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAvatarAndName(context, user, isDefaultName),
                const SizedBox(height: 16),
                _buildUserIdSection(context, user),
                if (isDefaultName) _buildDefaultNameHint(context),
                const SizedBox(height: 16),
                _buildProfileButton(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarAndName(BuildContext context, UserInfo user, bool isDefaultName) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDefaultName) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'По умолчанию',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Репутация: ${user.reputation}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showEditNameDialog(context, user),
          tooltip: 'Изменить имя',
        ),
      ],
    );
  }

  Widget _buildUserIdSection(BuildContext context, UserInfo user) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.fingerprint, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID пользователя',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  user.id.substring(0, 8).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: user.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID скопирован')),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Копировать'),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultNameHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Установите своё имя, чтобы другие пользователи могли узнать вас',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      icon: const Icon(Icons.contact_page),
      label: const Text('Профиль для контактов'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, UserInfo user) {
    final controller = TextEditingController(text: user.name == 'Прогульщик' ? '' : user.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ваше имя'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Введите ваше имя',
                border: OutlineInputBorder(),
              ),
              maxLength: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Это имя будет отображаться рядом с вашими объектами на карте',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Имя не может быть пустым')),
                );
                return;
              }

              await userIdService.setUserName(newName);
              if (context.mounted) {
                Navigator.pop(context);
                onUpdate();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Имя сохранено'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
