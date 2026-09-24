import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/brain_client.dart';

/// Live view — polls v1 predictions for one device and shows the latest
/// occupancy/activity prediction stream.
class LiveScreen extends StatefulWidget {
  const LiveScreen({required this.deviceId, super.key});

  final String deviceId;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _client = BrainClient.instance;
  final List<Map<String, dynamic>> _predictions = [];
  final Set<String> _seenIds = {};
  Timer? _timer;
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

  bool _isOccupied(Map<String, dynamic> p) {
    final label = (p['label'] ?? '').toString().toLowerCase();
    if (label == 'occupied') return true;
    final scores = p['scores'];
    if (scores is Map && scores['occupied'] is num) {
      return (scores['occupied'] as num) > 0.5;
    }
    return false;
  }

  Future<void> _poll() async {
    try {
      // v1 typed predictions — replaces the legacy live-chunks contract.
      final preds = await _client.getDevicePredictions(widget.deviceId,
          limit: 50,);
      if (!mounted) return;
      setState(() {
        _error = null;
        for (final p in preds.reversed) {
          // PredictionV1.id may be empty for payloads without one; fall
          // back to a composite key so dedup still works.
          var id = (p['id'] ?? '').toString();
          if (id.isEmpty) {
            id = '${p['runtime_model_id']}|${p['timestamp']}|${p['label']}';
          }
          if (_seenIds.contains(id)) continue;
          _seenIds.add(id);
          _predictions.insert(0, p);
        }
        if (_predictions.length > 100) {
          _predictions.removeRange(100, _predictions.length);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _predictions.isNotEmpty ? _predictions.first : null;
    final occupied = latest != null && _isOccupied(latest);
    final label = (latest?['label'] ?? '—').toString();

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
            child: _predictions.isEmpty
                ? const Center(child: Text('Waiting for live data…'))
                : ListView.builder(
                    itemCount: _predictions.length,
                    itemBuilder: (context, i) {
                      final p = _predictions[i];
                      final occ = _isOccupied(p);
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          occ ? Icons.circle : Icons.circle_outlined,
                          size: 12,
                          color: occ ? Colors.green : Colors.grey,
                        ),
                        title: Text((p['label'] ?? 'prediction').toString()),
                        subtitle: Text(
                            (p['timestamp'] ?? '').toString(),),
                        trailing: p['confidence'] != null
                            ? Text('${p['confidence']}')
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
