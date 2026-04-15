import 'package:flutter/material.dart';

/// Helper-функции для показа SnackBar
/// Унифицирует отображение уведомлений по всему приложению

/// Показать информационное уведомление
void showInfoSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Показать уведомление об успехе
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Показать уведомление об ошибке
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Показать предупреждение
void showWarningSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Показать уведомление с действием
void showActionSnackBar(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  Color backgroundColor = Colors.green,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: actionLabel,
        textColor: Colors.white,
        onPressed: onAction,
      ),
    ),
  );
}

/// Extension для удобного доступа к SnackBar из BuildContext
extension SnackBarExtension on BuildContext {
  /// Показать информационное уведомление
  void showInfo(String message) => showInfoSnackBar(this, message);

  /// Показать уведомление об успехе
  void showSuccess(String message) => showSuccessSnackBar(this, message);

  /// Показать уведомление об ошибке
  void showError(String message) => showErrorSnackBar(this, message);

  /// Показать предупреждение
  void showWarning(String message) => showWarningSnackBar(this, message);

  /// Показать уведомление с действием
  void showWithAction({
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Color backgroundColor = Colors.green,
  }) {
    showActionSnackBar(
      this,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      backgroundColor: backgroundColor,
    );
  }
}
