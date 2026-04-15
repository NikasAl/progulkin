import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/map_object_provider.dart';
import '../../services/user_id_service.dart';
import 'settings_widgets.dart';

/// Секция P2P синхронизации
class P2PSyncSection extends StatefulWidget {
  final UserIdService userIdService;

  const P2PSyncSection({
    super.key,
    required this.userIdService,
  });

  @override
  State<P2PSyncSection> createState() => _P2PSyncSectionState();
}

class _P2PSyncSectionState extends State<P2PSyncSection> {
  bool _p2pEnabled = true;
  String _signalingServer = 'signaling.progulkin.ru';
  int _signalingPort = 9000;
  bool _p2pInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadP2PSettings();
  }

  Future<void> _loadP2PSettings() async {
    final mapObjectProvider = context.read<MapObjectProvider>();
    await widget.userIdService.getUserInfo();

    if (mounted) {
      setState(() {
        _p2pEnabled = mapObjectProvider.p2pEnabled;
        _p2pInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_p2pInitialized) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSyncToggle(),
        _buildServerSettings(),
        _buildSyncControls(),
        _buildSyncStats(),
      ],
    );
  }

  Widget _buildSyncToggle() {
    return Consumer<MapObjectProvider>(
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
    );
  }

  Widget _buildServerSettings() {
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

  Widget _buildSyncControls() {
    return Consumer<MapObjectProvider>(
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
    );
  }

  Widget _buildSyncStats() {
    return Consumer<MapObjectProvider>(
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
                    StatItem(emoji: '👹', count: stats['trashMonsters'] ?? 0, label: 'Монстров'),
                    StatItem(emoji: '📜', count: stats['secrets'] ?? 0, label: 'Секретов'),
                    StatItem(emoji: '🦊', count: stats['creatures'] ?? 0, label: 'Существ'),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text('${stats['cleaned'] ?? 0} убрано'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startP2P(MapObjectProvider provider) async {
    final userInfo = await widget.userIdService.getUserInfo();

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
}
