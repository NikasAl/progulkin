import 'package:flutter/material.dart';

/// Стиль отображения виджета статистики
enum StatsWidgetStyle {
  /// Стандартный стиль с фоном
  standard,
  /// Компактный стиль без фона
  compact,
  /// Карточный стиль с цветным фоном
  card,
  /// Inline стиль для использования в Row
  inline,
}

/// Виджет для отображения статистики
///
/// Поддерживает несколько стилей отображения:
/// - [StatsWidgetStyle.standard] - стандартный с фоном
/// - [StatsWidgetStyle.compact] - компактный без фона
/// - [StatsWidgetStyle.card] - карточный с цветным фоном
/// - [StatsWidgetStyle.inline] - inline для использования в Row
class StatsWidget extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final StatsWidgetStyle style;
  final bool expanded;
  final double iconSize;
  final double? valueFontSize;
  final double? labelFontSize;

  const StatsWidget({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.style = StatsWidgetStyle.standard,
    this.expanded = false,
    this.iconSize = 28,
    this.valueFontSize,
    this.labelFontSize,
  });

  /// Создать виджет в карточном стиле
  const StatsWidget.card({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  })  : style = StatsWidgetStyle.card,
        expanded = false,
        iconSize = 28,
        valueFontSize = null,
        labelFontSize = null;

  /// Создать виджет в компактном стиле
  const StatsWidget.compact({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.onTap,
    this.expanded = false,
  })  : style = StatsWidgetStyle.compact,
        backgroundColor = null,
        iconSize = 20,
        valueFontSize = null,
        labelFontSize = null;

  /// Создать inline виджет для Row с Expanded
  const StatsWidget.inline({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.onTap,
    this.iconSize = 18,
    this.valueFontSize,
    this.labelFontSize,
  })  : style = StatsWidgetStyle.inline,
        backgroundColor = null,
        expanded = true;

  @override
  Widget build(BuildContext context) {
    Widget content;

    switch (style) {
      case StatsWidgetStyle.card:
        content = _buildCardStyle(context);
        break;
      case StatsWidgetStyle.compact:
        content = _buildCompactStyle(context);
        break;
      case StatsWidgetStyle.inline:
        content = _buildInlineStyle(context);
        break;
      case StatsWidgetStyle.standard:
        content = _buildStandardStyle(context);
        break;
    }

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    if (expanded && style != StatsWidgetStyle.inline && style != StatsWidgetStyle.card) {
      content = Expanded(child: content);
    }

    return content;
  }

  Widget _buildStandardStyle(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: valueFontSize,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: labelFontSize,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStyle(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize ?? 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: labelFontSize ?? 12,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStyle(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: valueFontSize,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: labelFontSize,
              ),
        ),
      ],
    );
  }

  Widget _buildInlineStyle(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: valueFontSize ?? 13,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: labelFontSize ?? 10,
                ),
          ),
        ],
      ),
    );
  }
}

/// Компактный виджет статистики в виде строки
class CompactStatWidget extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final Color? color;

  const CompactStatWidget({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        if (label != null) ...[
          const SizedBox(width: 4),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ],
    );
  }
}
