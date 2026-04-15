import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

/// Карточка выбора темы
class ThemeSelectorCard extends StatelessWidget {
  const ThemeSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Card(
          child: ListTile(
            leading: Icon(themeProvider.themeModeIcon),
            title: const Text('Тема приложения'),
            subtitle: Text(themeProvider.themeModeName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeSelector(context, themeProvider),
          ),
        );
      },
    );
  }

  void _showThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Тема приложения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.system,
              Icons.brightness_auto,
              'Авто',
              'Следовать настройкам системы',
            ),
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.light,
              Icons.light_mode,
              'Светлая',
              'Всегда светлая тема',
            ),
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.dark,
              Icons.dark_mode,
              'Тёмная',
              'Всегда тёмная тема',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    ThemeMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = themeProvider.themeMode == mode;

    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: themeProvider.themeMode,
      onChanged: (value) {
        if (value != null) {
          themeProvider.setThemeMode(value);
        }
      },
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      subtitle: Text(subtitle),
      secondary: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
    );
  }
}
