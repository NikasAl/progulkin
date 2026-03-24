import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/walk_provider.dart';
import '../models/walk.dart';
import 'walk_detail_screen.dart';

/// Экран истории прогулок
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История прогулок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClearHistory(context),
            tooltip: 'Очистить историю',
          ),
        ],
      ),
      body: Consumer<WalkProvider>(
        builder: (context, walkProvider, child) {
          final walks = walkProvider.walksHistory;

          if (walkProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (walks.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // Статистика
              _buildStatisticsCard(context, walkProvider),
              
              // Список прогулок
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: walks.length,
                  itemBuilder: (context, index) {
                    return _buildWalkCard(context, walks[index], walkProvider);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Пустое состояние
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_walk_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет записанных прогулок',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите "Начать прогулку" на главном экране',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Карточка статистики
  Widget _buildStatisticsCard(BuildContext context, WalkProvider walkProvider) {
    return FutureBuilder<Map<String, dynamic>>(
      future: walkProvider.getStatistics(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Общая статистика',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    context,
                    label: 'Прогулок',
                    value: '${stats['totalWalks'] ?? 0}',
                  ),
                  _buildStatColumn(
                    context,
                    label: 'Километров',
                    value: _formatDistance(stats['totalDistance'] ?? 0),
                  ),
                  _buildStatColumn(
                    context,
                    label: 'Шагов',
                    value: _formatNumber(stats['totalSteps'] ?? 0),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  /// Карточка прогулки
  Widget _buildWalkCard(
    BuildContext context,
    Walk walk,
    WalkProvider walkProvider,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy', 'ru_RU');
    final timeFormat = DateFormat('HH:mm', 'ru_RU');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openWalkDetail(context, walk),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Дата и время
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(walk.startTime),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${timeFormat.format(walk.startTime)} - ${walk.endTime != null ? timeFormat.format(walk.endTime!) : '...'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Статистика прогулки
              Row(
                children: [
                  Expanded(
                    child: _buildWalkStat(
                      context,
                      icon: Icons.route,
                      label: 'Расстояние',
                      value: walk.formattedDistance,
                    ),
                  ),
                  Expanded(
                    child: _buildWalkStat(
                      context,
                      icon: Icons.timer,
                      label: 'Время',
                      value: walk.formattedDuration,
                    ),
                  ),
                  Expanded(
                    child: _buildWalkStat(
                      context,
                      icon: Icons.directions_walk,
                      label: 'Шаги',
                      value: '${walk.steps}',
                    ),
                  ),
                ],
              ),
              
              // Кнопка удаления
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(context, walk.id, walkProvider),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Удалить'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Статистика прогулки
  Widget _buildWalkStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

  /// Форматирование расстояния
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} км';
    }
    return '${meters.toStringAsFixed(0)} м';
  }

  /// Форматирование числа
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}М';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}К';
    }
    return '$number';
  }

  /// Открыть детали прогулки
  void _openWalkDetail(BuildContext context, Walk walk) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkDetailScreen(walk: walk),
      ),
    );
  }

  /// Подтверждение удаления
  void _confirmDelete(
    BuildContext context,
    String walkId,
    WalkProvider walkProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить прогулку?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              walkProvider.deleteWalk(walkId);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  /// Подтверждение очистки истории
  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все прогулки будут удалены. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement clear all
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}
