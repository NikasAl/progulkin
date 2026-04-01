import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';
import '../services/merge_engine.dart';
import '../providers/map_object_provider.dart';

/// Диалог синхронизации карты
class SyncDialog extends StatefulWidget {
  const SyncDialog({super.key});

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  final SyncService _syncService = SyncService();
  bool _isLoading = false;
  String? _statusMessage;
  ZipExportResult? _exportResult;
  ZipImportResult? _importResult;
  Map<String, dynamic>? _exportStats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _syncService.getExportStats();
    if (mounted) {
      setState(() {
        _exportStats = stats;
      });
    }
  }

  Future<void> _export() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Экспорт данных...';
    });

    try {
      final result = await _syncService.exportAndShare();
      if (mounted) {
        setState(() {
          _exportResult = result;
          _statusMessage = result.success
              ? 'Экспорт завершён: ${result.objectsCount} объектов'
              : 'Ошибка: ${result.error}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _import() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Импорт данных...';
    });

    try {
      final result = await _syncService.importFromZip(
        strategy: MergeStrategy.newerWins,
      );

      if (mounted) {
        // Обновляем провайдер после успешного импорта
        if (result.success) {
          final provider = context.read<MapObjectProvider>();
          await provider.reload();
        }

        setState(() {
          _importResult = result;
          _statusMessage = result.success
              ? 'Импорт завершён: ${result.summary}'
              : 'Ошибка: ${result.error}';
        });

        // Если есть конфликты - показываем диалог
        if (result.hasConflicts) {
          _showConflictsDialog(result.conflicts!);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showConflictsDialog(List<MergeConflict> conflicts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Конфликты (${conflicts.length})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final conflict = conflicts[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    _getConflictIcon(conflict.type),
                    color: Colors.orange,
                  ),
                  title: Text(conflict.userDescription),
                  subtitle: Text(
                    'Локальная: ${conflict.localObject.updatedAt}\n'
                    'Удалённая: ${conflict.remoteObject.updatedAt}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<MergeStrategy>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (strategy) async {
                      await _syncService.resolveConflict(conflict, strategy);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Конфликт разрешён')),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: MergeStrategy.localWins,
                        child: ListTile(
                          leading: Icon(Icons.phone_android),
                          title: Text('Оставить локальную'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: MergeStrategy.remoteWins,
                        child: ListTile(
                          leading: Icon(Icons.cloud_download),
                          title: Text('Взять входящую'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: MergeStrategy.newerWins,
                        child: ListTile(
                          leading: Icon(Icons.access_time),
                          title: Text('Взять новее'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              // Разрешить все конфликты автоматически (новее выигрывает)
              for (final conflict in conflicts) {
                _syncService.resolveConflict(conflict, MergeStrategy.newerWins);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Все конфликты разрешены автоматически')),
              );
            },
            child: const Text('Разрешить все автоматически'),
          ),
        ],
      ),
    );
  }

  IconData _getConflictIcon(ConflictType type) {
    switch (type) {
      case ConflictType.bothModified:
        return Icons.edit;
      case ConflictType.localDeletedRemoteModified:
        return Icons.delete_outline;
      case ConflictType.localModifiedRemoteDeleted:
        return Icons.delete;
      case ConflictType.bothDeleted:
        return Icons.delete_forever;
      case ConflictType.versionMismatch:
        return Icons.merge_type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sync),
          const SizedBox(width: 8),
          Expanded(
            child: const Text('Синхронизация'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Статистика
            if (_exportStats != null) ...[
              Text(
                'Текущие данные:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text('Всего: ${_exportStats!['total']}'),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.blue.shade100,
                    labelStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Colors.blue.shade800,
                    ),
                  ),
                  Chip(
                    label: Text('Активных: ${_exportStats!['active']}'),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Colors.green.shade100,
                    labelStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Colors.green.shade800,
                    ),
                  ),
                  if (_exportStats!['deleted'] > 0)
                    Chip(
                      label: Text('Удалённых: ${_exportStats!['deleted']}'),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Статус
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _importResult?.success ?? _exportResult?.success ?? false
                            ? Icons.check_circle
                            : Icons.error,
                        color: _importResult?.success ?? _exportResult?.success ?? false
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Результаты экспорта
            if (_exportResult?.success == true) ...[
              Text(
                'Размер файла: ${_exportResult!.fileSizeFormatted}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Результаты импорта
            if (_importResult?.success == true) ...[
              Text(
                'Результат импорта:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _importResult!.summary,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _import,
          icon: const Icon(Icons.file_download),
          label: const Text('Импорт'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _export,
          icon: const Icon(Icons.share),
          label: const Text('Экспорт'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Показать диалог синхронизации
Future<void> showSyncDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const SyncDialog(),
  );
}
