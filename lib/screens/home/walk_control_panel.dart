import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/walk_provider.dart';
import '../../providers/pedometer_provider.dart';

/// Нижняя панель управления прогулкой
/// Содержит кнопки навигации и главную кнопку управления прогулкой
class WalkControlPanel extends StatelessWidget {
  /// Callback при нажатии на кнопку истории
  final VoidCallback onHistoryTap;

  /// Callback при нажатии на кнопку настроек
  final VoidCallback onSettingsTap;

  /// Callback при нажатии на кнопку коллекции
  final VoidCallback onCollectionTap;

  /// Callback при нажатии на кнопку сообщений
  final VoidCallback onChatTap;

  /// Callback при нажатии на кнопку местоположения
  final VoidCallback onLocationTap;

  /// Callback при нажатии на кнопку "О приложении"
  final VoidCallback onAboutTap;

  /// Callback при начале прогулки
  final VoidCallback onStartWalk;

  /// Callback при паузе прогулки
  final VoidCallback onPauseWalk;

  /// Callback при продолжении прогулки
  final VoidCallback onResumeWalk;

  /// Callback при завершении прогулки
  final VoidCallback onStopWalk;

  const WalkControlPanel({
    super.key,
    required this.onHistoryTap,
    required this.onSettingsTap,
    required this.onCollectionTap,
    required this.onChatTap,
    required this.onLocationTap,
    required this.onAboutTap,
    required this.onStartWalk,
    required this.onPauseWalk,
    required this.onResumeWalk,
    required this.onStopWalk,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Consumer2<WalkProvider, PedometerProvider>(
            builder: (context, walkProvider, pedometerProvider, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Горизонтально прокручиваемые кнопки
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIconButton(
                          context: context,
                          icon: Icons.history,
                          tooltip: 'История',
                          onTap: onHistoryTap,
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          context: context,
                          icon: Icons.settings,
                          tooltip: 'Настройки',
                          onTap: onSettingsTap,
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          context: context,
                          icon: Icons.pets,
                          tooltip: 'Коллекция',
                          onTap: onCollectionTap,
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          context: context,
                          icon: Icons.chat,
                          tooltip: 'Сообщения',
                          onTap: onChatTap,
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          context: context,
                          icon: Icons.my_location,
                          tooltip: 'Моё местоположение',
                          onTap: onLocationTap,
                        ),
                        const SizedBox(width: 12),
                        _buildIconButton(
                          context: context,
                          icon: Icons.info_outline,
                          tooltip: 'О приложении',
                          onTap: onAboutTap,
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMainButton(context, walkProvider, pedometerProvider),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22, color: Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context,
    WalkProvider walkProvider,
    PedometerProvider pedometerProvider,
  ) {
    final hasWalk = walkProvider.hasCurrentWalk;

    if (hasWalk) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (walkProvider.isTracking) {
                  onPauseWalk();
                } else {
                  onResumeWalk();
                }
              },
              icon: Icon(
                walkProvider.isTracking ? Icons.pause : Icons.play_arrow,
              ),
              label: Text(walkProvider.isTracking ? 'Пауза' : 'Продолжить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onStopWalk,
              icon: const Icon(Icons.stop),
              label: const Text('Завершить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onStartWalk,
        icon: const Icon(Icons.play_arrow, size: 28),
        label: const Text(
          'Начать прогулку',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
