import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/pedometer_service.dart';
import '../services/user_id_service.dart';
import '../models/walk.dart';
import '../providers/walk_provider.dart';
import '../providers/map_object_provider.dart';
import '../providers/theme_provider.dart';
import '../config/version.dart';
import 'settings/settings.dart';
import 'storage_screen.dart';
import 'route_planning_screen.dart';
import 'privacy_policy_screen.dart';
import 'habitat_debug_screen.dart';

/// Экран настроек приложения
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocationService _locationService = LocationService();
  final PedometerService _pedometerService = PedometerService();
  final UserIdService _userIdService = UserIdService();

  // Настройки GPS
  late double _maxSpeed;
  late double _maxAccuracy;
  late bool _enableSmoothing;

  // Настройки сглаживания
  late bool _enableAdaptiveSmoothing;
  late double _turnThreshold;
  late double _smoothingWeight;

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
    _enableAdaptiveSmoothing = _locationService.enableAdaptiveSmoothing;
    _turnThreshold = _locationService.sharpTurnThresholdDegrees;
    _smoothingWeight = _locationService.smoothingWeight;
    _enableStationaryDetection = _locationService.enableStationaryDetection;
    _stationaryRadius = _locationService.stationaryRadiusMeters;
    _pedometerSensitivity = _pedometerService.sensitivity;
    _stepLength = _pedometerService.averageStepLength;
    _distanceSource = DistanceSource.pedometer;

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
          // Профиль
          ProfileSection(
            userIdService: _userIdService,
            onUpdate: () => setState(() {}),
          ),
          const Divider(height: 32),

          // Источник расстояния
          const SectionHeader(title: 'Источник расстояния'),
          const InfoCard(
            text: 'Педометр обычно точнее GPS для ходьбы. '
                'GPS может давать ошибки до 100м из-за особенностей сигнала. '
                'Рекомендуется: "Шагомер" или "Среднее".',
          ),
          DistanceSourceSelector(
            currentSource: _distanceSource,
            onChanged: (source) {
              setState(() => _distanceSource = source);
              context.read<WalkProvider>().saveSettings(distanceSource: source);
            },
          ),
          const Divider(height: 32),

          // Фильтрация GPS
          const SectionHeader(title: 'Фильтрация GPS'),
          const InfoCard(
            text: 'Настройки помогают отфильтровать неточные данные GPS. '
                'Если расстояние завышено - уменьшите скорость и точность.',
          ),
          _buildGpsFilterSection(),
          const Divider(height: 16),

          // Определение неподвижности
          const SectionHeader(title: 'Определение неподвижности'),
          const InfoCard(
            text: 'Когда вы стоите на месте, GPS даёт разброс координат. '
                'Эта функция определяет неподвижность и не записывает лишние точки.',
          ),
          _buildStationarySection(),
          const Divider(height: 32),

          // Шагомер
          const SectionHeader(title: 'Шагомер'),
          const InfoCard(
            text: 'Алгоритм детекции шагов по пикам ускорения. '
                'Высокая чувствительность = детектирует больше шагов (для слабой ходьбы). '
                'Низкая = только уверенные шаги (для быстрой ходьбы).',
          ),
          _buildPedometerSection(),
          const Divider(height: 32),

          // P2P Синхронизация
          const SectionHeader(title: 'P2P Синхронизация'),
          const InfoCard(
            text: 'Объекты синхронизируются напрямую между устройствами. '
                'Сервер только знакомит устройства в одной зоне, '
                'не храня данные объектов.',
          ),
          P2PSyncSection(userIdService: _userIdService),
          const Divider(height: 32),

          // Внешний вид
          const SectionHeader(title: 'Внешний вид'),
          const ThemeSelectorCard(),
          const Divider(height: 32),

          // Управление данными
          const SectionHeader(title: 'Управление данными'),
          _buildDataManagementSection(),
          const Divider(height: 32),

          // Советы
          const SectionHeader(title: 'Советы для точности'),
          const TipCard(
            icon: Icons.gps_fixed,
            title: 'GPS сигнал',
            tips: [
              'Дождитесь стабилизации GPS (10-30 сек)',
              'Находитесь на открытом пространстве',
              'Избегайте высоких зданий и плотной застройки',
            ],
          ),
          const TipCard(
            icon: Icons.phone_android,
            title: 'Телефон',
            tips: [
              'Держите телефон в кармане или на поясе',
              'Не блокируйте экран во время записи',
              'Разрешите работу в фоновом режиме',
            ],
          ),
          const TipCard(
            icon: Icons.directions_walk,
            title: 'Ходьба',
            tips: [
              'Идите ровным шагом для лучшей детекции',
              'При быстрой ходьбе уменьшите чувствительность',
              'При медленной/слабой ходьбе - увеличьте чувствительность',
            ],
          ),
          const SizedBox(height: 24),

          // О приложении
          const SectionHeader(title: 'О приложении'),
          _buildAboutSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGpsFilterSection() {
    return Column(
      children: [
        SettingsSlider(
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
        SettingsSlider(
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
        if (_enableSmoothing) ...[
          SwitchListTile(
            secondary: const Icon(Icons.turn_right),
            title: const Text('Сохранять повороты'),
            subtitle: const Text('Не сглаживать точки на резких поворотах'),
            value: _enableAdaptiveSmoothing,
            onChanged: (value) {
              setState(() {
                _enableAdaptiveSmoothing = value;
                _locationService.updateSettings(adaptiveSmoothing: value);
              });
            },
          ),
          if (_enableAdaptiveSmoothing) ...[
            SettingsSlider(
              title: 'Порог поворота',
              subtitle: 'Угол больше этого значения = поворот',
              value: _turnThreshold,
              min: 15,
              max: 60,
              divisions: 9,
              unit: '°',
              icon: Icons.turn_slight_right,
              displayValue: '${_turnThreshold.toStringAsFixed(0)}°',
              onChanged: (value) {
                setState(() {
                  _turnThreshold = value;
                  _locationService.updateSettings(turnThreshold: value);
                });
              },
            ),
            SettingsSlider(
              title: 'Сила сглаживания',
              subtitle: 'Выше = плавнее, но медленнее реакция',
              value: _smoothingWeight,
              min: 0.33,
              max: 0.8,
              divisions: 10,
              unit: '',
              icon: Icons.tune,
              displayValue: _getSmoothingLabel(_smoothingWeight),
              onChanged: (value) {
                setState(() {
                  _smoothingWeight = value;
                  _locationService.updateSettings(smoothingWeight: value);
                });
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStationarySection() {
    return Column(
      children: [
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
          SettingsSlider(
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
      ],
    );
  }

  Widget _buildPedometerSection() {
    return Column(
      children: [
        SettingsSlider(
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
        SettingsSlider(
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
            context.read<WalkProvider>().saveSettings(stepLength: value);
          },
        ),
      ],
    );
  }

  Widget _buildDataManagementSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('Хранилище объектов'),
          subtitle: const Text('Статистика, экспорт/импорт объектов карты'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StorageScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Отладка Habitats'),
          subtitle: const Text('Визуализация сред обитания на карте'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HabitatDebugScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.map),
          title: const Text('Кеширование карт'),
          subtitle: const Text('Управление кешем тайлов OpenStreetMap'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RoutePlanningScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Прогулкин'),
          subtitle: Text(
            '${AppVersion.versionInfo}\n'
            'Трекинг прогулок с OpenStreetMap',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Коммит сборки'),
          subtitle: Text(
            'Хэш: ${AppVersion.commitHash}\n'
            'Полная версия: ${AppVersion.fullVersion}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Исходный код'),
          subtitle: const Text('github.com/NikasAl/progulkin'),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Политика конфиденциальности'),
          subtitle: const Text('Информация об обработке данных'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
          ),
        ),
      ],
    );
  }

  String _getSensitivityLabel(double value) {
    if (value < 0.7) return 'Низкая';
    if (value < 1.0) return 'Пониженная';
    if (value < 1.3) return 'Нормальная';
    if (value < 1.7) return 'Повышенная';
    return 'Высокая';
  }

  String _getSmoothingLabel(double value) {
    if (value < 0.4) return 'Слабое';
    if (value < 0.5) return 'Умеренное';
    if (value < 0.6) return 'Среднее';
    if (value < 0.7) return 'Сильное';
    return 'Очень сильное';
  }
}
