import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/brain_client.dart';

/// Live view — polls live-chunks for one device and shows the latest
/// occupancy/activity prediction stream.
class LiveScreen extends StatefulWidget {
  const LiveScreen({required this.deviceId, super.key});

  final String deviceId;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _client = BrainClient.instance;
  final List<Map<String, dynamic>> _chunks = [];
  Timer? _timer;
  int _cursor = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final payload = await _client.getJson(
        '/device/${widget.deviceId}/live-chunks',
        params: {'cursor': _cursor},
      );
      final chunks = (payload['chunks'] ?? payload['data'] ?? []) as List;
      setState(() {
        _error = null;
        for (final c in chunks) {
          _chunks.insert(0, Map<String, dynamic>.from(c as Map));
        }
        if (_chunks.length > 100) _chunks.removeRange(100, _chunks.length);
        _cursor = (payload['cursor'] ?? payload['next_cursor'] ?? _cursor) as int;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _chunks.isNotEmpty ? _chunks.first : null;
    final occupied = latest?['occupied'] == true;
    final label = (latest?['label'] ?? latest?['prediction'] ?? '—').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Live')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: occupied ? Colors.green.shade700 : Colors.grey.shade800,
            child: Column(
              children: [
                Icon(occupied ? Icons.person : Icons.person_off,
                    size: 48, color: Colors.white,),
                const SizedBox(height: 8),
                Text(occupied ? 'Occupied' : 'Empty',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,),),
                Text(label,
                    style: const TextStyle(color: Colors.white70),),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),),
            ),
          Expanded(
            child: _chunks.isEmpty
                ? const Center(child: Text('Waiting for live data…'))
                : ListView.builder(
                    itemCount: _chunks.length,
                    itemBuilder: (context, i) {
                      final c = _chunks[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          c['occupied'] == true
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 12,
                          color: c['occupied'] == true
                              ? Colors.green
                              : Colors.grey,
                        ),
                        title: Text(
                            (c['label'] ?? c['prediction'] ?? 'chunk').toString(),),
                        subtitle: Text(
                            (c['minute'] ?? c['timestamp'] ?? '').toString(),),
                        trailing: c['confidence'] != null
                            ? Text('${c['confidence']}')
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
