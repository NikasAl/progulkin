import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/map_objects/map_objects.dart';
import '../../providers/map_object_provider.dart';

/// Bottom sheet с опциями объекта карты
class ObjectOptionsSheet extends StatelessWidget {
  final MapObject object;
  final String? userId;
  final VoidCallback onShowDetails;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const ObjectOptionsSheet({
    super.key,
    required this.object,
    this.userId,
    required this.onShowDetails,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = object.ownerId == userId;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Подробности'),
            onTap: () {
              Navigator.pop(context);
              onShowDetails();
            },
          ),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Удалить объект?'),
                    content: const Text('Это действие нельзя отменить.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  if (!context.mounted) return;
                  await context.read<MapObjectProvider>().deleteObject(
                        object.id,
                        userId ?? '',
                      );
                  if (context.mounted) {
                    Navigator.pop(context);
                    onDelete();
                  }
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.flag, color: Colors.orange),
            title: const Text('Пожаловаться'),
            onTap: () async {
              await context.read<MapObjectProvider>().denyObject(object.id);
              if (context.mounted) {
                Navigator.pop(context);
                onReport();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Показать опции объекта
void showObjectOptionsSheet({
  required BuildContext context,
  required MapObject object,
  String? userId,
  required VoidCallback onShowDetails,
  required VoidCallback onDelete,
  required VoidCallback onReport,
}) {
  showModalBottomSheet(
    context: context,
    builder: (context) => ObjectOptionsSheet(
      object: object,
      userId: userId,
      onShowDetails: onShowDetails,
      onDelete: onDelete,
      onReport: onReport,
    ),
  );
}
