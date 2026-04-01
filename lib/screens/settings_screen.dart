import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/pedometer_service.dart';
import '../services/user_id_service.dart';
import '../models/walk.dart';
import '../providers/walk_provider.dart';
import '../providers/map_object_provider.dart';
import '../providers/theme_provider.dart';
import 'storage_screen.dart';
import 'route_planning_screen.dart';
import 'profile_screen.dart';
import 'privacy_policy_screen.dart';

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
  
  // Настройки P2P
  bool _p2pEnabled = true;
  String _signalingServer = 'signaling.progulkin.ru';
  int _signalingPort = 9000;
  bool _p2pInitialized = false;

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
    
    // Загружаем из WalkProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walkProvider = context.read<WalkProvider>();
      setState(() {
        _distanceSource = walkProvider.distanceSource;
        _stepLength = walkProvider.stepLength;
      });
      
      // Загружаем настройки P2P
      _loadP2PSettings();
    });
  }
  
  Future<void> _loadP2PSettings() async {
    final mapObjectProvider = context.read<MapObjectProvider>();
    await _userIdService.getUserInfo();
    
    setState(() {
      _p2pEnabled = mapObjectProvider.p2pEnabled;
      _p2pInitialized = true;
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
          // Секция профиля пользователя
          _buildProfileSection(),
          const Divider(height: 32),
          
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
              _buildSliderTile(
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
              _buildSliderTile(
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
          
          // Секция P2P синхронизации
          _buildSectionHeader('P2P Синхронизация'),
          _buildInfoCard(
            'Объекты синхронизируются напрямую между устройствами. '
            'Сервер только знакомит устройства в одной зоне, '
            'не храня данные объектов.',
          ),
          if (_p2pInitialized) ...[
            Consumer<MapObjectProvider>(
              builder: (context, provider, child) {
                return SwitchListTile(
                  secondary: Icon(
                    provider.isP2PRunning ? Icons.sync : Icons.sync_disabled,
                    color: provider.isP2PRunning ? Colors.green : Colors.grey,
                  ),
                  title: const Text('Синхронизация объектов'),
                  subtitle: Text(
                    provider.isP2PRunning 
                        ? 'Активно • ${provider.allObjects.length} объектов'
                        : 'Отключено',
                  ),
                  value: _p2pEnabled,
                  onChanged: (value) {
                    provider.setP2PEnabled(value);
                    setState(() {
                      _p2pEnabled = value;
                    });
                  },
                );
              },
            ),
            _buildP2PServerSettings(),
            Consumer<MapObjectProvider>(
              builder: (context, provider, child) {
                if (!provider.isP2PRunning && _p2pEnabled) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _startP2P(provider),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Запустить синхронизацию'),
                    ),
                  );
                }
                if (provider.isP2PRunning) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => provider.forceSync(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Синхронизировать'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => provider.stopP2P(),
                            icon: const Icon(Icons.stop),
                            label: const Text('Остановить'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Статистика P2P
            Consumer<MapObjectProvider>(
              builder: (context, provider, child) {
                final stats = provider.stats;
                return Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('👹', stats['trashMonsters'] ?? 0, 'Монстров'),
                            _buildStatItem('📜', stats['secrets'] ?? 0, 'Секретов'),
                            _buildStatItem('🦊', stats['creatures'] ?? 0, 'Существ'),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 4),
                            Text('${stats['cleaned'] ?? 0} убрано'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const Divider(height: 32),

          // Секция внешнего вида
          _buildSectionHeader('Внешний вид'),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(themeProvider.themeModeIcon),
                      title: const Text('Тема приложения'),
                      subtitle: Text(themeProvider.themeModeName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showThemeSelector(themeProvider),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 32),

          // Секция управления данными
          _buildSectionHeader('Управление данными'),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Хранилище объектов'),
            subtitle: const Text('Статистика, экспорт/импорт объектов карты'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openStorage(context),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Кеширование карт'),
            subtitle: const Text('Управление кешем тайлов OpenStreetMap'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openTileCache(context),
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
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Политика конфиденциальности'),
            subtitle: const Text('Информация об обработке данных'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
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

  String _getSmoothingLabel(double value) {
    if (value < 0.4) return 'Слабое';
    if (value < 0.5) return 'Умеренное';
    if (value < 0.6) return 'Среднее';
    if (value < 0.7) return 'Сильное';
    return 'Очень сильное';
  }
  
  Widget _buildP2PServerSettings() {
    return ExpansionTile(
      leading: const Icon(Icons.dns_outlined),
      title: const Text('Настройки сервера'),
      subtitle: Text('$_signalingServer:$_signalingPort'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Адрес сервера',
                  hintText: 'signaling.progulkin.ru',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                controller: TextEditingController(text: _signalingServer),
                onChanged: (value) {
                  _signalingServer = value;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Порт',
                  hintText: '9000',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                controller: TextEditingController(text: _signalingPort.toString()),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _signalingPort = int.tryParse(value) ?? 9000;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Используйте публичный сервер или запустите свой: dart run bin/signaling_server.dart',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<void> _startP2P(MapObjectProvider provider) async {
    final userInfo = await _userIdService.getUserInfo();
    
    await provider.startP2P(
      signalingServer: _signalingServer,
      signalingPort: _signalingPort,
      deviceId: userInfo.id,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.isP2PRunning 
                ? 'Синхронизация запущена!' 
                : 'Ошибка запуска: ${provider.error ?? "Неизвестная ошибка"}',
          ),
          backgroundColor: provider.isP2PRunning ? Colors.green : Colors.red,
        ),
      );
    }
  }
  
  Widget _buildStatItem(String emoji, int count, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Открыть хранилище объектов
  void _openStorage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StorageScreen()),
    );
  }

  /// Открыть экран кеширования карт
  void _openTileCache(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoutePlanningScreen()),
    );
  }

  /// Секция профиля пользователя
  Widget _buildProfileSection() {
    return FutureBuilder<UserInfo>(
      future: _userIdService.getUserInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ));
        }

        final user = snapshot.data!;
        final isDefaultName = user.name == 'Прогульщик';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Профиль',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Аватар и имя
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDefaultName) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'По умолчанию',
                                    style: TextStyle(fontSize: 10, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Репутация: ${user.reputation}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditNameDialog(user),
                      tooltip: 'Изменить имя',
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                
                // ID пользователя
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fingerprint, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID пользователя',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                            Text(
                              user.id.substring(0, 8).toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Копируем только первые 8 символов для краткости
                          // В реальности можно скопировать весь ID
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Копировать'),
                      ),
                    ],
                  ),
                ),

                if (isDefaultName) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Установите своё имя, чтобы другие пользователи могли узнать вас',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Кнопка редактирования профиля контакта
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                  icon: const Icon(Icons.contact_page),
                  label: const Text('Профиль для контактов'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Диалог редактирования имени
  void _showEditNameDialog(UserInfo user) {
    final controller = TextEditingController(text: user.name == 'Прогульщик' ? '' : user.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ваше имя'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Введите ваше имя',
                border: OutlineInputBorder(),
              ),
              maxLength: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Это имя будет отображаться рядом с вашими объектами на карте',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Имя не может быть пустым')),
                );
                return;
              }

              await _userIdService.setUserName(newName);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {}); // Обновляем UI
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Имя сохранено'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  /// Показать диалог выбора темы
  void _showThemeSelector(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Тема приложения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              themeProvider,
              ThemeMode.system,
              Icons.brightness_auto,
              'Авто',
              'Следовать настройкам системы',
            ),
            _buildThemeOption(
              themeProvider,
              ThemeMode.light,
              Icons.light_mode,
              'Светлая',
              'Всегда светлая тема',
            ),
            _buildThemeOption(
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
          Navigator.pop(context);
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
