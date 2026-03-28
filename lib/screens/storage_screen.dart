import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/map_objects/map_objects.dart';
import '../providers/map_object_provider.dart';
import '../services/p2p/map_object_storage.dart';

/// Экран хранилища объектов
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _dbSize = 'Расчёт...';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final provider = context.read<MapObjectProvider>();
    
    // Получаем статистику по объектам
    final objectCounts = provider.objectCounts;
    final total = objectCounts.values.fold(0, (sum, count) => sum + count);
    
    // Получаем размер базы данных
    final dbSize = await _getDatabaseSize();
    
    // Получаем статистику по фото
    final photoStats = await _getPhotoStats();
    
    setState(() {
      _stats = {
        'total': total,
        'counts': objectCounts,
        'dbSize': dbSize,
        'photos': photoStats,
      };
      _dbSize = _formatBytes(dbSize);
      _isLoading = false;
    });
  }

  Future<int> _getDatabaseSize() async {
    try {
      final db = await MapObjectStorage().database;
      final path = db.path;
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('Error getting DB size: $e');
    }
    return 0;
  }

  Future<Map<String, dynamic>> _getPhotoStats() async {
    try {
      final db = await MapObjectStorage().database;
      final results = await db.rawQuery('SELECT COUNT(*) as count, SUM(length(webp_data)) as size FROM photos');
      if (results.isNotEmpty) {
        return {
          'count': results.first['count'] as int? ?? 0,
          'size': results.first['size'] as int? ?? 0,
        };
      }
    } catch (e) {
      debugPrint('Error getting photo stats: $e');
    }
    return {'count': 0, 'size': 0};
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Хранилище объектов'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Общая статистика
                  _buildSummaryCard(),
                  const SizedBox(height: 24),

                  // Статистика по типам
                  _buildTypeStatsCard(),
                  const SizedBox(height: 24),

                  // Фото
                  _buildPhotoStatsCard(),
                  const SizedBox(height: 24),

                  // Экспорт/Импорт
                  _buildExportImportCard(),
                  const SizedBox(height: 24),

                  // Очистка
                  _buildCleanupCard(),
                ],
              ),
            ),
    );
  }

  /// Карточка общей статистики
  Widget _buildSummaryCard() {
    final total = _stats['total'] as int? ?? 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Общая статистика',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.place,
                    label: 'Всего объектов',
                    value: '$total',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.sd_storage,
                    label: 'Размер БД',
                    value: _dbSize,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Элемент статистики
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Карточка статистики по типам
  Widget _buildTypeStatsCard() {
    final counts = _stats['counts'] as Map<MapObjectType, int>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'По типам объектов',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...MapObjectType.values.map((type) {
              final count = counts[type] ?? 0;
              return _buildTypeRow(type, count);
            }),
          ],
        ),
      ),
    );
  }

  /// Строка типа объекта
  Widget _buildTypeRow(MapObjectType type, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTypeColor(type).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(type.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTypeName(type),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _getTypeDescription(type),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: count > 0 ? Colors.blue : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(MapObjectType type) {
    switch (type) {
      case MapObjectType.trashMonster:
        return Colors.orange;
      case MapObjectType.secretMessage:
        return Colors.purple;
      case MapObjectType.creature:
        return Colors.green;
      case MapObjectType.interestNote:
        return Colors.blue;
      case MapObjectType.reminderCharacter:
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  String _getTypeName(MapObjectType type) {
    switch (type) {
      case MapObjectType.trashMonster:
        return 'Мусорные монстры';
      case MapObjectType.secretMessage:
        return 'Секретные сообщения';
      case MapObjectType.creature:
        return 'Существа';
      case MapObjectType.interestNote:
        return 'Заметки о местах';
      case MapObjectType.reminderCharacter:
        return 'Напоминалки';
      default:
        return type.name;
    }
  }

  String _getTypeDescription(MapObjectType type) {
    switch (type) {
      case MapObjectType.trashMonster:
        return 'Мусор, который нужно убрать';
      case MapObjectType.secretMessage:
        return 'Скрытые сообщения';
      case MapObjectType.creature:
        return 'Существа для поимки';
      case MapObjectType.interestNote:
        return 'Интересные места';
      case MapObjectType.reminderCharacter:
        return 'Гео-напоминания';
      default:
        return '';
    }
  }

  /// Карточка статистики фото
  Widget _buildPhotoStatsCard() {
    final photoStats = _stats['photos'] as Map<String, dynamic>? ?? {};
    final count = photoStats['count'] as int? ?? 0;
    final size = photoStats['size'] as int? ?? 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Фотографии',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.image,
                    label: 'Фото',
                    value: '$count',
                    color: Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.compress,
                    label: 'Размер (WebP)',
                    value: _formatBytes(size),
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Фото сжимаются до 800×600px в формате JPEG/WebP (макс 100 КБ)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка экспорта/импорта
  Widget _buildExportImportCard() {
    return Consumer<MapObjectProvider>(
      builder: (context, provider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sync, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Резервное копирование',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Сохраняйте объекты в файл для резервного копирования или переноса на другое устройство.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.allObjects.isEmpty
                            ? null
                            : () => _exportObjects(provider),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Экспорт'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _importObjects(provider),
                        icon: const Icon(Icons.download),
                        label: const Text('Импорт'),
                      ),
                    ),
                  ],
                ),
                if (provider.allObjects.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _shareObjects(provider),
                      icon: const Icon(Icons.share),
                      label: const Text('Поделиться файлом'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Карточка очистки
  Widget _buildCleanupCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delete_sweep, color: Colors.red[400]),
                const SizedBox(width: 8),
                Text(
                  'Управление данными',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cleaning_services, color: Colors.orange),
              ),
              title: const Text('Удалить убранные монстры'),
              subtitle: const Text('Очистить историю убранных объектов'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCleanupDialog('cleaned'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_forever, color: Colors.red),
              ),
              title: const Text('Очистить все данные'),
              subtitle: const Text('Удалить все объекты и фото'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCleanupDialog('all'),
            ),
          ],
        ),
      ),
    );
  }

  /// Показать диалог очистки
  void _showCleanupDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'all' ? 'Очистить все данные?' : 'Удалить убранные монстры?'),
        content: Text(
          type == 'all'
              ? 'Это действие удалит все объекты карты и фотографии. Его нельзя отменить.'
              : 'Удалить историю убранных мусорных монстров из хранилища?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performCleanup(type);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  /// Выполнить очистку
  Future<void> _performCleanup(String type) async {
    final provider = context.read<MapObjectProvider>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (type == 'all') {
        await provider.clearAll();
      } else {
        // TODO: Добавить метод очистки убранных монстров
        final storage = provider.storage;
        final db = await storage.database;
        await db.delete(
          'map_objects',
          where: 'type = ? AND json_extract(data, "$.isCleaned") = ?',
          whereArgs: ['trash_monster', 1],
        );
      }

      if (mounted) {
        Navigator.pop(context);
        await _loadStats();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Данные очищены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Экспорт объектов
  Future<void> _exportObjects(MapObjectProvider provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await provider.exportObjects();

      if (!mounted) return;
      Navigator.pop(context);

      if (result.success) {
        _showExportResultDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Показать результат экспорта
  void _showExportResultDialog(ExportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Экспорт завершён'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Файл: ${result.fileName}'),
            const SizedBox(height: 8),
            Text('Объектов: ${result.objectCount}'),
            if (result.filePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Путь: ${result.filePath}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Поделиться файлом
  Future<void> _shareObjects(MapObjectProvider provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await provider.exportAndShareObjects();

      if (!mounted) return;
      Navigator.pop(context);

      if (!result.success && result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${result.error}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Импорт объектов
  Future<void> _importObjects(MapObjectProvider provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await provider.importObjects();

      if (!mounted) return;
      Navigator.pop(context);

      _showImportResultDialog(result);
      await _loadStats();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Показать результат импорта
  void _showImportResultDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.warning,
              color: result.success ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(result.success ? 'Импорт завершён' : 'Импорт'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.summary),
              if (result.importedObjects.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Импортированные объекты:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...result.importedObjects.take(10).map(
                  (obj) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(obj),
                  ),
                ),
                if (result.importedObjects.length > 10)
                  Text(
                    '... и ещё ${result.importedObjects.length - 10}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
