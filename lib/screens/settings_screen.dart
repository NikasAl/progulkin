import 'package:flutter/material.dart';
import '../services/location_service.dart';

/// Экран настроек приложения
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocationService _locationService = LocationService();
  
  late double _maxSpeed;
  late double _maxAccuracy;
  late bool _enableSmoothing;

  @override
  void initState() {
    super.initState();
    _maxSpeed = _locationService.maxWalkingSpeedKmh;
    _maxAccuracy = _locationService.maxAccuracyMeters;
    _enableSmoothing = _locationService.enableSmoothing;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Секция фильтрации GPS
          _buildSectionHeader('Фильтрация GPS'),
          
          _buildSliderTile(
            title: 'Макс. скорость ходьбы',
            subtitle: 'Точки с большей скоростью будут отфильтрованы',
            value: _maxSpeed,
            min: 5,
            max: 20,
            unit: ' км/ч',
            onChanged: (value) {
              setState(() {
                _maxSpeed = value;
                _locationService.updateSettings(maxSpeed: value);
              });
            },
          ),
          
          _buildSliderTile(
            title: 'Макс. погрешность GPS',
            subtitle: 'Точки с большей погрешностью будут отфильтрованы',
            value: _maxAccuracy,
            min: 10,
            max: 100,
            unit: ' м',
            onChanged: (value) {
              setState(() {
                _maxAccuracy = value;
                _locationService.updateSettings(maxAccuracy: value);
              });
            },
          ),
          
          SwitchListTile(
            title: const Text('Сглаживание маршрута'),
            subtitle: const Text('Усреднение координат для плавности'),
            value: _enableSmoothing,
            onChanged: (value) {
              setState(() {
                _enableSmoothing = value;
                _locationService.updateSettings(smoothing: value);
              });
            },
          ),
          
          const Divider(height: 32),
          
          // Информация
          _buildSectionHeader('Информация'),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            subtitle: const Text('Прогулкин v1.0.0\nТрекинг прогулок с OpenStreetMap'),
          ),
          
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Исходный код'),
            subtitle: const Text('github.com/NikasAl/progulkin'),
            onTap: () {
              // Можно добавить открытие ссылки
            },
          ),
          
          const Divider(height: 32),
          
          // Советы
          _buildSectionHeader('Советы для точного трекинга'),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Дождитесь стабилизации GPS (10-30 сек) перед началом'),
                SizedBox(height: 8),
                Text('• Находитесь на открытом пространстве для лучшего сигнала'),
                SizedBox(height: 8),
                Text('• Разрешите приложению работать в фоне'),
                SizedBox(height: 8),
                Text('• При низкой точности точки фильтруются автоматически'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: ((max - min) / 5).round(),
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${value.toStringAsFixed(0)}$unit',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
