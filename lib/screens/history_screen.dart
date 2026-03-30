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

          return SingleChildScrollView(
            child: Column(
              children: [
                // Расширенная статистика
                _buildExtendedStatisticsCard(context, walkProvider),
                
                // График по дням
                _buildWeeklyChart(context, walkProvider),
                
                // Список прогулок
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Прогулки',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${walks.length} записей',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Список прогулок (ограниченная высота для прокрутки)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: walks.length,
                  itemBuilder: (context, index) {
                    return _buildWalkCard(context, walks[index], walkProvider);
                  },
                ),
              ],
            ),
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

  /// Расширенная карточка статистики
  Widget _buildExtendedStatisticsCard(BuildContext context, WalkProvider walkProvider) {
    return FutureBuilder<Map<String, dynamic>>(
      future: walkProvider.getStatistics(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Заголовок
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insights, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Статистика',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Два ряда: неделя и всего
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // За неделю
                    _buildStatsRow(
                      context,
                      title: 'За неделю',
                      walks: stats['weekWalks'] ?? 0,
                      distance: stats['weekDistance'] ?? 0.0,
                      steps: stats['weekSteps'] ?? 0,
                      color: Colors.green,
                    ),
                    const Divider(height: 24),
                    // Всего
                    _buildStatsRow(
                      context,
                      title: 'Всего',
                      walks: stats['totalWalks'] ?? 0,
                      distance: stats['totalDistance'] ?? 0.0,
                      steps: stats['totalSteps'] ?? 0,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Ряд статистики
  Widget _buildStatsRow(
    BuildContext context, {
    required String title,
    required int walks,
    required double distance,
    required int steps,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.directions_walk,
                value: '$walks',
                label: 'Прогулок',
                color: color,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.route,
                value: _formatDistance(distance),
                label: 'Километров',
                color: color,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.directions_walk,
                value: _formatNumber(steps),
                label: 'Шагов',
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  /// Элемент статистики
  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

  /// График по дням за неделю
  Widget _buildWeeklyChart(BuildContext context, WalkProvider walkProvider) {
    return FutureBuilder<Map<String, dynamic>>(
      future: walkProvider.getStatistics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final dailyStats = snapshot.data!['dailyStats'] as List<dynamic>? ?? [];
        if (dailyStats.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return _WeeklyChartContainer(dailyStats: dailyStats);
      },
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

/// Контейнер графика с переключателем
class _WeeklyChartContainer extends StatefulWidget {
  final List<dynamic> dailyStats;
  
  const _WeeklyChartContainer({required this.dailyStats});
  
  @override
  State<_WeeklyChartContainer> createState() => _WeeklyChartContainerState();
}

class _WeeklyChartContainerState extends State<_WeeklyChartContainer> {
  /// true = показывать шаги, false = показывать расстояние
  bool _showSteps = false;
  
  @override
  Widget build(BuildContext context) {
    // Находим максимальные значения для масштабирования
    double maxDistance = 0;
    int maxSteps = 0;
    for (final day in widget.dailyStats) {
      final dist = (day['distance'] as num?)?.toDouble() ?? 0;
      final steps = (day['steps'] as int?) ?? 0;
      if (dist > maxDistance) maxDistance = dist;
      if (steps > maxSteps) maxSteps = steps;
    }
    
    final maxStepsDouble = maxSteps.toDouble();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с переключателем
          Row(
            children: [
              Icon(
                Icons.bar_chart,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Активность за неделю',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Переключатель
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  label: 'Километры',
                  isSelected: !_showSteps,
                  onTap: () => setState(() => _showSteps = false),
                ),
                _buildToggleButton(
                  label: 'Шаги',
                  isSelected: _showSteps,
                  onTap: () => setState(() => _showSteps = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // График
          SizedBox(
            height: 150,
            child: _WeeklyChart(
              dailyStats: widget.dailyStats,
              maxValue: _showSteps ? maxStepsDouble : maxDistance,
              showSteps: _showSteps,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Виджет графика за неделю
class _WeeklyChart extends StatelessWidget {
  final List<dynamic> dailyStats;
  final double maxValue;
  final bool showSteps;
  
  const _WeeklyChart({
    required this.dailyStats,
    required this.maxValue,
    required this.showSteps,
  });
  
  @override
  Widget build(BuildContext context) {
    final weekdayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: dailyStats.map((dayData) {
        final day = dayData as Map<String, dynamic>;
        final distance = (day['distance'] as num?)?.toDouble() ?? 0;
        final steps = (day['steps'] as int?) ?? 0;
        final date = day['date'] as DateTime?;
        
        // Определяем название дня
        String dayName = '';
        if (date != null) {
          final weekday = date.weekday; // 1 = понедельник
          dayName = weekdayNames[weekday - 1];
        }
        
        // Проверяем, является ли этот день сегодняшним
        final isToday = date != null && 
            date.year == todayDate.year && 
            date.month == todayDate.month && 
            date.day == todayDate.day;
        
        // Значение для отображения
        final value = showSteps ? steps.toDouble() : distance;
        final displayMaxValue = showSteps ? maxValue : (maxValue / 1000);
        final normalizedValue = showSteps ? value : (value / 1000);
        
        // Высота столбца
        final barHeight = displayMaxValue > 0 
            ? (normalizedValue / displayMaxValue * 100).clamp(4.0, 100.0) 
            : 4.0;
        
        return _DayColumn(
          dayName: dayName,
          value: value,
          barHeight: barHeight,
          isToday: isToday,
          showSteps: showSteps,
        );
      }).toList(),
    );
  }
}

/// Столбец дня на графике
class _DayColumn extends StatelessWidget {
  final String dayName;
  final double value;
  final double barHeight;
  final bool isToday;
  final bool showSteps;
  
  const _DayColumn({
    required this.dayName,
    required this.value,
    required this.barHeight,
    required this.isToday,
    required this.showSteps,
  });
  
  @override
  Widget build(BuildContext context) {
    // Форматируем значение для отображения
    String displayValue;
    if (showSteps) {
      final steps = value.toInt();
      if (steps >= 1000) {
        displayValue = '${(steps / 1000).toStringAsFixed(1)}К';
      } else if (steps > 0) {
        displayValue = '$steps';
      } else {
        displayValue = '';
      }
    } else {
      final km = value / 1000;
      if (km >= 1) {
        displayValue = '${km.toStringAsFixed(1)}';
      } else if (km > 0) {
        displayValue = km.toStringAsFixed(2);
      } else {
        displayValue = '';
      }
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Значение над столбцом
        if (value > 0)
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isToday ? Colors.blue : Colors.grey[600],
            ),
          )
        else
          const SizedBox(height: 12),
        
        const SizedBox(height: 4),
        
        // Столбец
        Container(
          width: 28,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: isToday
                ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.blue, Colors.blue.withValues(alpha: 0.7)],
                  )
                : null,
            color: isToday ? null : Colors.grey[300],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Название дня
        Text(
          dayName,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday ? Colors.blue : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
