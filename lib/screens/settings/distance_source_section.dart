import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/walk.dart';
import '../../providers/walk_provider.dart';

/// Секция выбора источника расстояния
class DistanceSourceSelector extends StatelessWidget {
  final DistanceSource currentSource;
  final ValueChanged<DistanceSource> onChanged;

  const DistanceSourceSelector({
    super.key,
    required this.currentSource,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Источник расстояния',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...[
              DistanceSource.pedometer,
              DistanceSource.average,
              DistanceSource.gps
            ].map((source) => _buildSourceOption(context, source)),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(BuildContext context, DistanceSource source) {
    final isSelected = currentSource == source;
    final (title, description, icon) = _getSourceInfo(source);

    return InkWell(
      onTap: () => onChanged(source),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  (String, String, IconData) _getSourceInfo(DistanceSource source) {
    return switch (source) {
      DistanceSource.gps => (
          'Только GPS',
          'Расстояние только по GPS координатам',
          Icons.gps_fixed,
        ),
      DistanceSource.pedometer => (
          'Только шагомер',
          'Расстояние = шаги × длина шага (рекомендуется)',
          Icons.directions_walk,
        ),
      DistanceSource.average => (
          'Среднее',
          'Среднее значение между GPS и шагомером',
          Icons.calculate,
        ),
    };
  }
}

/// Виджет-обёртка для использования с WalkProvider
class DistanceSourceSection extends StatelessWidget {
  const DistanceSourceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final walkProvider = context.watch<WalkProvider>();

    return DistanceSourceSelector(
      currentSource: walkProvider.distanceSource,
      onChanged: (source) {
        context.read<WalkProvider>().saveSettings(distanceSource: source);
      },
    );
  }
}
