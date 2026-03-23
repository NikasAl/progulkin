import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';

/// Экран настроек приложения
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocationService _locationService = LocationService();
  
  late double _maxWalkingSpeed;
  late double _maxAccuracy;
  late bool _enableSmoothing;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _maxWalkingSpeed = prefs.getDouble('maxWalkingSpeed') ?? 10.0;
      _maxAccuracy = prefs.getDouble('maxAccuracy') ?? 50.0;
      _enableSmoothing = prefs.getBool('enableSmoothing') ?? true;
      _isLoading = false;
    });
    
    // Применяем к сервису
    _locationService.maxWalkingSpeedKmh = _maxWalkingSpeed;
    _locationService.maxAccuracyMeters = _maxAccuracy;
    _locationService.enableSmoothing = _enableSmoothing;
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setDouble('maxWalkingSpeed', _maxWalkingSpeed);
    await prefs.setDouble('maxAccuracy', _maxAccuracy);
    await prefs.setBool('enableSmoothing', _enableSmoothing);
    
    // Применяем к сервису
    _locationService.maxWalkingSpeedKmh = _maxWalkingSpeed;
    _locationService.maxAccuracyMeters = _maxAccuracy;
    _locationService.enableSmoothing = _enableSmoothing;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Настройки сохранены'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Секция GPS фильтрации
                _buildSectionHeader('Фильтрация GPS'),
                const SizedBox(height: 8),
                
                // Максимальная скорость
                _buildSpeedSlider(),
                const SizedBox(height: 16),
                
                // Максимальная точность
                _buildAccuracySlider(),
                const SizedBox(height: 16),
                
                // Сглаживание
                _buildSmoothingSwitch(),
                const SizedBox(height: 24),
                
                // Информация
                _buildInfoCard(),
                const SizedBox(height: 24),
                
                // Кнопка сохранения
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Сохранить настройки'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSpeedSlider() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Макс. скорость ходьбы',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Точки со скоростью выше этого значения будут отфильтрованы как выбросы GPS',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _maxWalkingSpeed,
                    min: 5,
                    max: 20,
                    divisions: 15,
                    label: '${_maxWalkingSpeed.toStringAsFixed(0)} км/ч',
                    onChanged: (value) {
                      setState(() {
                        _maxWalkingSpeed = value;
                      });
                    },
                  ),
                ),
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_maxWalkingSpeed.toStringAsFixed(0)} км/ч',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getSpeedRecommendation(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSpeedRecommendation() {
    if (_maxWalkingSpeed < 7) {
      return 'Медленная прогулка, высокий риск потери точек';
    } else if (_maxWalkingSpeed < 12) {
      return 'Оптимально для обычной ходьбы';
    } else if (_maxWalkingSpeed < 16) {
      return 'Быстрая ходьба / лёгкий бег';
    } else {
      return 'Бег, могут пройти шумные точки GPS';
    }
  }

  Widget _buildAccuracySlider() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Макс. погрешность GPS',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Точки с погрешностью выше этого значения будут отфильтрованы',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _maxAccuracy,
                    min: 20,
                    max: 100,
                    divisions: 8,
                    label: '${_maxAccuracy.toStringAsFixed(0)} м',
                    onChanged: (value) {
                      setState(() {
                        _maxAccuracy = value;
                      });
                    },
                  ),
                ),
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_maxAccuracy.toStringAsFixed(0)} м',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getAccuracyRecommendation(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAccuracyRecommendation() {
    if (_maxAccuracy < 30) {
      return 'Высокая точность, может терять точки в зданиях';
    } else if (_maxAccuracy < 60) {
      return 'Оптимальный баланс точности и надёжности';
    } else {
      return 'Могут пройти неточные точки в городе';
    }
  }

  Widget _buildSmoothingSwitch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.show_chart, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Сглаживание маршрута',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Усреднение соседних точек для более плавного маршрута',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _enableSmoothing,
              onChanged: (value) {
                setState(() {
                  _enableSmoothing = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, 
                  size: 20, 
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'О фильтрации GPS',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'GPS в смартфонах имеет погрешность 5-50 метров и может '
              'давать "выбросы" — точки, значительно удалённые от реального '
              'маршрута. Приложение использует несколько методов фильтрации:\n\n'
              '• Проверка точности каждой точки\n'
              '• Проверка скорости между точками\n'
              '• Медианный фильтр для выявления аномалий\n'
              '• Проверка на возврат к старым позициям\n'
              '• Скользящее среднее для сглаживания\n\n'
              'Настройте параметры под свой стиль ходьбы.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
