import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/habitat_service.dart';
import '../services/creature_service.dart';
import '../services/location_service.dart';
import '../models/map_objects/creature.dart';

/// Отладочный экран для визуализации сред обитания (habitats)
/// Позволяет увидеть какие области OSM определяются как habitats
class HabitatDebugScreen extends StatefulWidget {
  const HabitatDebugScreen({super.key});

  @override
  State<HabitatDebugScreen> createState() => _HabitatDebugScreenState();
}

class _HabitatDebugScreenState extends State<HabitatDebugScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final HabitatService _habitatService = HabitatService();
  final CreatureService _creatureService = CreatureService();

  LatLng? _currentLocation;
  LatLng _mapCenter = const LatLng(55.7558, 37.6173); // Москва по умолчанию
  double _currentZoom = 14.0;

  HabitatDetectionResult? _currentHabitat;
  List<_HabitatMarker> _habitatMarkers = [];
  bool _isLoading = false;
  String? _error;

  // Цвета для разных habitat
  static const Map<CreatureHabitat, Color> _habitatColors = {
    CreatureHabitat.forest: Color(0xFF228B22), // Forest green
    CreatureHabitat.water: Color(0xFF1E90FF), // Dodger blue
    CreatureHabitat.swamp: Color(0xFF556B2F), // Dark olive green
    CreatureHabitat.mountain: Color(0xFF8B4513), // Saddle brown
    CreatureHabitat.field: Color(0xFFFFD700), // Gold
    CreatureHabitat.city: Color(0xFF708090), // Slate gray
    CreatureHabitat.home: Color(0xFFCD853F), // Peru
    CreatureHabitat.anywhere: Color(0xFF9370DB), // Medium purple
  };

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _mapCenter = _currentLocation!;
      });
    }
  }

  Future<void> _detectHabitatAtCenter() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _habitatService.detectHabitat(
        _mapCenter.latitude,
        _mapCenter.longitude,
      );

      if (mounted) {
        setState(() {
          _currentHabitat = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanArea() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _habitatMarkers.clear();
    });

    try {
      // Сканируем сетку точек вокруг центра карты
      final center = _mapCenter;
      const step = 0.005; // ~500м между точками
      const radius = 0.015; // ~1.5км от центра

      final futures = <Future<_HabitatMarker>>[];

      for (double lat = center.latitude - radius; lat <= center.latitude + radius; lat += step) {
        for (double lng = center.longitude - radius; lng <= center.longitude + radius; lng += step) {
          futures.add(_detectHabitatAtPoint(lat, lng));
        }
      }

      final markers = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _habitatMarkers = markers.where((m) => m.habitat != null).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<_HabitatMarker> _detectHabitatAtPoint(double lat, double lng) async {
    try {
      final result = await _habitatService.detectHabitat(lat, lng);
      return _HabitatMarker(
        position: LatLng(lat, lng),
        habitat: result.primaryHabitat,
        scores: result.habitatScores,
        fromCache: result.fromCache,
      );
    } catch (e) {
      return _HabitatMarker(
        position: LatLng(lat, lng),
        habitat: null,
        scores: {},
        fromCache: false,
      );
    }
  }

  Future<void> _spawnTestCreature() async {
    if (_currentHabitat == null) {
      await _detectHabitatAtCenter();
    }

    if (_currentHabitat == null) return;

    final creature = await _creatureService.trySpawnCreatureAsync(
      centerLat: _mapCenter.latitude,
      centerLng: _mapCenter.longitude,
      radiusKm: 0.5,
    );

    if (mounted) {
      if (creature != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🦊 ${creature.creatureType.emoji} ${creature.creatureType.name} '
              '(${creature.rarity.name}) в среде ${creature.habitat.name}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось заспавнить существо в среде ${_currentHabitat!.primaryHabitat.name}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _moveToCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отладка Habitats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _moveToCurrentLocation,
            tooltip: 'Моё местоположение',
          ),
        ],
      ),
      body: Column(
        children: [
          // Карта
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _currentZoom,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _mapCenter = position.center ?? _mapCenter;
                    _currentZoom = position.zoom ?? _currentZoom;
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.progulkin',
                  maxZoom: 19,
                ),
                // Маркеры habitats
                CircleLayer(
                  circles: _habitatMarkers.map((marker) {
                    final color = _habitatColors[marker.habitat] ?? Colors.grey;
                    return CircleMarker(
                      point: marker.position,
                      radius: 200, // 200 метров
                      color: color.withValues(alpha: 0.4),
                      borderColor: color,
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),
                // Маркер текущей позиции
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                // Маркер центра карты
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _mapCenter,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.center_focus_strong,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Панель управления и информации
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Координаты центра
                    Text(
                      '📍 Центр карты: ${_mapCenter.latitude.toStringAsFixed(5)}, ${_mapCenter.longitude.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),

                    // Кнопки управления
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _detectHabitatAtCenter,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.search),
                            label: const Text('Определить habitat'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _scanArea,
                            icon: const Icon(Icons.grid_on),
                            label: const Text('Сканировать область'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading || _currentHabitat == null ? null : _spawnTestCreature,
                      icon: const Icon(Icons.pets),
                      label: const Text('Тестовый спавн существа'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    // Ошибка
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Результат определения habitat
                    if (_currentHabitat != null) ...[
                      const SizedBox(height: 16),
                      _buildHabitatResult(),
                    ],

                    // Легенда
                    const SizedBox(height: 16),
                    Text(
                      'Легенда цветов:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _habitatColors.entries.map((e) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: e.value,
                          ),
                          label: Text('${e.key.emoji} ${e.key.name}'),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),

                    // Существа для текущего habitat
                    if (_currentHabitat != null) ...[
                      const SizedBox(height: 16),
                      _buildCreaturesForHabitat(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitatResult() {
    final habitat = _currentHabitat!.primaryHabitat;
    final color = _habitatColors[habitat] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${habitat.emoji} ${habitat.name}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (_currentHabitat!.fromCache)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'из кэша',
                    style: TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Scores
          Text(
            'Очки для всех habitats:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ..._currentHabitat!.habitatScores.entries.map((e) {
            final scoreColor = _habitatColors[e.key] ?? Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text('${e.key.emoji} ${e.key.name}'),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: e.value,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(e.value.toStringAsFixed(2)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCreaturesForHabitat() {
    final habitat = _currentHabitat!.primaryHabitat;
    final creatures = _creatureService.getCreaturesForHabitat(habitat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Существа для ${habitat.name}:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (creatures.isEmpty)
          const Text(
            'Нет существ для этой среды',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: creatures.map((type) {
              final config = _creatureService.getSpawnConfig(type);
              return Chip(
                avatar: Text(type.emoji),
                label: Text(
                  '${type.name} (${(config!.spawnChance * 100).toStringAsFixed(1)}%)',
                ),
                backgroundColor: _getRarityColor(config.rarity).withValues(alpha: 0.2),
              );
            }).toList(),
          ),
      ],
    );
  }

  Color _getRarityColor(CreatureRarity rarity) {
    switch (rarity) {
      case CreatureRarity.common:
        return Colors.grey;
      case CreatureRarity.uncommon:
        return Colors.green;
      case CreatureRarity.rare:
        return Colors.blue;
      case CreatureRarity.epic:
        return Colors.purple;
      case CreatureRarity.legendary:
        return Colors.amber;
      case CreatureRarity.mythical:
        return Colors.red;
    }
  }
}

/// Маркер habitat на карте
class _HabitatMarker {
  final LatLng position;
  final CreatureHabitat? habitat;
  final Map<CreatureHabitat, double> scores;
  final bool fromCache;

  _HabitatMarker({
    required this.position,
    required this.habitat,
    required this.scores,
    required this.fromCache,
  });
}
