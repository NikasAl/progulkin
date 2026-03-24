import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/pedometer_service.dart';
import '../models/walk.dart';
import '../providers/walk_provider.dart';

/// Экран настроек приложения
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocationService _locationService = LocationService();
  final PedometerService _pedometerService = PedometerService();
  
  // Настройки GPS
  late double _maxSpeed;
  late double _maxAccuracy;
  late bool _enableSmoothing;
  
  // Настройки неподвижности
  late bool _enableStationaryDetection;
  late double _stationaryRadius;
  
  // Настройки педометра
  late double _pedometerSensitivity;
  late double _stepLength;
  
  // Источник расстояния
  late DistanceSource _distanceSource;

  @override
  void initState() {
    super.initState();
    _maxSpeed = _locationService.maxWalkingSpeedKmh;
    _maxAccuracy = _locationService.maxAccuracyMeters;
    _enableSmoothing = _locationService.enableSmoothing;
    _enableStationaryDetection = _locationService.enableStationaryDetection;
    _stationaryRadius = _locationService.stationaryRadiusMeters;
    _pedometerSensitivity = _pedometerService.sensitivity;
    _stepLength = _pedometerService.averageStepLength;
    _distanceSource = DistanceSource.pedometer;
    
    // Загружаем из WalkProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walkProvider = context.read<WalkProvider>();
      setState(() {
        _distanceSource = walkProvider.distanceSource;
        _stepLength = walkProvider.stepLength;
      });
    });
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
          // Секция приоритета расстояния
          _buildSectionHeader('Источник расстояния'),
          _buildInfoCard(
            'Педометр обычно точнее GPS для ходьбы. '
            'GPS может давать ошибки до 100м из-за особенностей сигнала. '
            'Рекомендуется: "Шагомер" или "Среднее".',
          ),
          _buildDistanceSourceSelector(),
          const Divider(height: 32),
          
          // Секция GPS
          _buildSectionHeader('Фильтрация GPS'),
          _buildInfoCard(
            'Настройки помогают отфильтровать неточные данные GPS. '
            'Если расстояние завышено - уменьшите скорость и точность.',
          ),
          _buildSliderTile(
            title: 'Макс. скорость ходьбы',
            subtitle: 'Точки с большей скоростью фильтруются',
            value: _maxSpeed,
            min: 5,
            max: 20,
            unit: ' км/ч',
            icon: Icons.speed,
            onChanged: (value) {
              setState(() {
                _maxSpeed = value;
                _locationService.updateSettings(maxSpeed: value);
              });
            },
          ),
          _buildSliderTile(
            title: 'Макс. погрешность GPS',
            subtitle: 'Точки с большей погрешностью фильтруются',
            value: _maxAccuracy,
            min: 10,
            max: 100,
            unit: ' м',
            icon: Icons.gps_fixed,
            onChanged: (value) {
              setState(() {
                _maxAccuracy = value;
                _locationService.updateSettings(maxAccuracy: value);
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.linear_scale),
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
          const Divider(height: 16),
          
          // Секция определения неподвижности
          _buildSectionHeader('Определение неподвижности'),
          _buildInfoCard(
            'Когда вы стоите на месте, GPS даёт разброс координат. '
            'Эта функция определяет неподвижность и не записывает лишние точки.',
          ),
          SwitchListTile(
            secondary: const Icon(Icons.pause_circle_outline),
            title: const Text('Определять неподвижность'),
            subtitle: const Text('Не записывать точки при остановке'),
            value: _enableStationaryDetection,
            onChanged: (value) {
              setState(() {
                _enableStationaryDetection = value;
                _locationService.updateSettings(stationaryDetection: value);
              });
            },
          ),
          if (_enableStationaryDetection)
            _buildSliderTile(
              title: 'Радиус неподвижности',
              subtitle: 'Смещение меньше этого радиуса за 30 сек = остановка',
              value: _stationaryRadius,
              min: 3,
              max: 30,
              unit: ' м',
              icon: Icons.gps_fixed,
              onChanged: (value) {
                setState(() {
                  _stationaryRadius = value;
                  _locationService.updateSettings(stationaryRadius: value);
                });
              },
            ),
          const Divider(height: 32),
          
          // Секция педометра
          _buildSectionHeader('Шагомер'),
          _buildInfoCard(
            'Алгоритм детекции шагов по пикам ускорения. '
            'Высокая чувствительность = детектирует больше шагов (для слабой ходьбы). '
            'Низкая = только уверенные шаги (для быстрой ходьбы).',
          ),
          _buildSliderTile(
            title: 'Чувствительность шагомера',
            subtitle: 'Выше = больше шагов (для слабой ходьбы)',
            value: _pedometerSensitivity,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            unit: '',
            icon: Icons.sensors,
            displayValue: _getSensitivityLabel(_pedometerSensitivity),
            onChanged: (value) {
              setState(() {
                _pedometerSensitivity = value;
                _pedometerService.setSensitivity(value);
              });
            },
          ),
          _buildSliderTile(
            title: 'Длина шага',
            subtitle: 'Для расчёта расстояния по шагам',
            value: _stepLength,
            min: 0.5,
            max: 1.0,
            divisions: 10,
            unit: ' м',
            icon: Icons.straighten,
            onChanged: (value) {
              setState(() {
                _stepLength = value;
                _pedometerService.setAverageStepLength(value);
              });
              // Сохраняем через WalkProvider
              context.read<WalkProvider>().saveSettings(stepLength: value);
            },
          ),
          const Divider(height: 32),
          
          // Советы
          _buildSectionHeader('Советы для точности'),
          _buildTipCard(
            icon: Icons.gps_fixed,
            title: 'GPS сигнал',
            tips: [
              'Дождитесь стабилизации GPS (10-30 сек)',
              'Находитесь на открытом пространстве',
              'Избегайте высоких зданий и плотной застройки',
            ],
          ),
          _buildTipCard(
            icon: Icons.phone_android,
            title: 'Телефон',
            tips: [
              'Держите телефон в кармане или на поясе',
              'Не блокируйте экран во время записи',
              'Разрешите работу в фоновом режиме',
            ],
          ),
          _buildTipCard(
            icon: Icons.directions_walk,
            title: 'Ходьба',
            tips: [
              'Идите ровным шагом для лучшей детекции',
              'При быстрой ходьбе уменьшите чувствительность',
              'При медленной/слабой ходьбе - увеличьте чувствительность',
            ],
          ),
          const SizedBox(height: 24),
          
          // Информация о приложении
          _buildSectionHeader('О приложении'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Прогулкин'),
            subtitle: Text('Версия 1.0.0\nТрекинг прогулок с OpenStreetMap'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Исходный код'),
            subtitle: const Text('github.com/NikasAl/progulkin'),
            onTap: () {
              // Можно добавить открытие ссылки
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDistanceSourceSelector() {
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
            ].map((source) => _buildSourceOption(source)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSourceOption(DistanceSource source) {
    final isSelected = _distanceSource == source;
    String title;
    String description;
    IconData icon;
    
    switch (source) {
      case DistanceSource.gps:
        title = 'Только GPS';
        description = 'Расстояние только по GPS координатам';
        icon = Icons.gps_fixed;
        break;
      case DistanceSource.pedometer:
        title = 'Только шагомер';
        description = 'Расстояние = шаги × длина шага (рекомендуется)';
        icon = Icons.directions_walk;
        break;
      case DistanceSource.average:
        title = 'Среднее';
        description = 'Среднее значение между GPS и шагомером';
        icon = Icons.calculate;
        break;
    }
    
    return InkWell(
      onTap: () {
        setState(() {
          _distanceSource = source;
        });
        // Сохраняем через WalkProvider
        context.read<WalkProvider>().saveSettings(distanceSource: source);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
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
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
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
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
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

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String unit,
    required IconData icon,
    String? displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
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
                  divisions: divisions ?? ((max - min) * 2).round(),
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  displayValue ?? '${value.toStringAsFixed(1)}$unit',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required List<String> tips,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(tip)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  String _getSensitivityLabel(double value) {
    if (value < 0.7) return 'Низкая';
    if (value < 1.0) return 'Пониженная';
    if (value < 1.3) return 'Нормальная';
    if (value < 1.7) return 'Повышенная';
    return 'Высокая';
  }
}
