import 'package:flutter/material.dart';

/// Общие декорации для панелей и контейнеров
/// Унифицирует визуальный стиль UI-элементов

/// Стандартная декорация для верхней панели (статистика, информация)
BoxDecoration topPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// Стандартная декорация для нижней панели (управление, навигация)
BoxDecoration bottomPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 10,
        offset: const Offset(0, -4),
      ),
    ],
  );
}

/// Стандартная декорация для bottom sheet
BoxDecoration bottomSheetDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
  );
}

/// Декорация для карточки с тенью
BoxDecoration cardDecoration(BuildContext context, {Color? color}) {
  return BoxDecoration(
    color: color ?? Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// Вертикальный разделитель
Widget verticalDivider({double height = 40, Color? color}) {
  return Container(
    height: height,
    width: 1,
    color: color ?? Colors.grey[300],
  );
}

/// Горизонтальный разделитель
Widget horizontalDivider({double width = double.infinity, Color? color}) {
  return Container(
    width: width,
    height: 1,
    color: color ?? Colors.grey[300],
  );
}
