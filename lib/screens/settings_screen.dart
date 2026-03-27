import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/pedometer_service.dart';
import '../services/user_id_service.dart';
import '../services/map_object_export_service.dart';
import '../models/walk.dart';
import '../providers/walk_provider.dart';
import '../providers/map_object_provider.dart';

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
    final userInfo = await _userIdService.getUserInfo();
    
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
          
          // Секция экспорта/импорта объектов
          _buildSectionHeader('Экспорт/Импорт объектов'),
          _buildInfoCard(
            'Сохраняйте объекты в файл для резервного копирования '
            'или переноса на другое устройство. '
            'Формат JSON - человекочитаемый.',
          ),
          Consumer<MapObjectProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  // Кнопки экспорта/импорта
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: provider.allObjects.isEmpty
                                ? null
                                : () => _exportObjects(provider),
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Экспорт'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _importObjects(provider),
                            icon: const Icon(Icons.download),
                            label: const Text('Импорт'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Кнопка "Поделиться"
                  if (provider.allObjects.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _shareObjects(provider),
                          icon: const Icon(Icons.share),
                          label: const Text('Поделиться файлом'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Статистика объектов
                  FutureBuilder<Map<String, dynamic>>(
                    future: provider.getExportStats(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final stats = snapshot.data!;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildExportStat(
                                Icons.apps,
                                stats['total'] ?? 0,
                                'Всего',
                              ),
                              _buildExportStat(
                                Icons.delete_outline,
                                stats['trashMonsters'] ?? 0,
                                'Монстров',
                              ),
                              _buildExportStat(
                                Icons.message_outlined,
                                stats['secretMessages'] ?? 0,
                                'Секретов',
                              ),
                              _buildExportStat(
                                Icons.pets,
                                stats['creatures'] ?? 0,
                                'Существ',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
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

  Widget _buildExportStat(IconData icon, int count, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 16,
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

  /// Экспорт объектов в файл
  Future<void> _exportObjects(MapObjectProvider provider) async {
    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await provider.exportObjects();

      if (!mounted) return;
      Navigator.pop(context); // Закрываем индикатор

      if (result.success) {
        _showExportResultDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Показать результат экспорта
  void _showExportResultDialog(ExportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Экспорт завершён'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Объектов: ${result.objectsCount}'),
            const SizedBox(height: 8),
            Text('📁 Размер: ${result.fileSizeFormatted}'),
            if (result.filePath != null) ...[
              const SizedBox(height: 8),
              Text(
                '📍 Файл: ${result.filePath}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Поделиться файлом экспорта
  Future<void> _shareObjects(MapObjectProvider provider) async {
    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await provider.exportAndShareObjects();

      if (!mounted) return;
      Navigator.pop(context); // Закрываем индикатор

      if (!result.success && result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Импорт объектов из файла
  Future<void> _importObjects(MapObjectProvider provider) async {
    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await provider.importObjects();

      if (!mounted) return;
      Navigator.pop(context); // Закрываем индикатор

      _showImportResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Показать результат импорта
  void _showImportResultDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.warning,
              color: result.success ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(result.success ? 'Импорт завершён' : 'Импорт'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.summary),
              if (result.importedObjects.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Импортированные объекты:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...result.importedObjects.take(10).map(
                  (obj) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(obj),
                  ),
                ),
                if (result.importedObjects.length > 10)
                  Text(
                    '... и ещё ${result.importedObjects.length - 10}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
              ],
              if (result.errorDetails.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Ошибки:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                ...result.errorDetails.take(5).map(
                  (err) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      err,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
