import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/brain_client.dart';
import '../../../core/api/event_feed.dart';

/// Events tab — merged view of the live Brain event feed (SSE) plus recent
/// context events for cold-start history. Predictions, automation triggers,
/// room changes, and notifications all land here.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final List<Map<String, dynamic>> _events = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _sub = EventFeed.instance.events.listen((batch) {
      setState(() => _events.insertAll(0, batch));
      if (_events.length > 300) _events.removeRange(300, _events.length);
    });
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    try {
      final res = await BrainClient.instance
          .getV1('/context/events', params: {'limit': 100});
      final rows = (res['events'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (mounted) {
        setState(() {
          for (final e in rows.reversed) {
            _events.add({
              'kind': 'context:${e['event_type'] ?? e['event_key']}',
              'data': e,
              'ts': e['timestamp'],
            });
          }
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  IconData _iconFor(String kind) {
    if (kind.contains('prediction')) return Icons.psychology;
    if (kind.contains('trigger')) return Icons.bolt;
    if (kind.contains('room')) return Icons.meeting_room;
    if (kind.contains('notification')) return Icons.notifications;
    if (kind.startsWith('context')) return Icons.hub;
    return Icons.info_outline;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _events.isEmpty
            ? ListView(children: [
                const SizedBox(height: 120),
                Center(
                  child: _loadingHistory
                      ? const CircularProgressIndicator()
                      : const Text(
                          'No events yet.\nPredictions, automation triggers and watch events arrive live here.',
                          textAlign: TextAlign.center),
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _events.length,
                itemBuilder: (context, i) {
                  final e = _events[i];
                  final kind = '${e['kind'] ?? 'event'}';
                  final ts = e['ts'];
                  final when = ts is num
                      ? DateTime.fromMillisecondsSinceEpoch(
                              (ts * 1000).round())
                          .toLocal()
                          .toString()
                          .substring(5, 19)
                      : '';
                  final data = e['data'];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(_iconFor(kind), size: 20),
                      title: Text(kind, style: const TextStyle(fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data is Map && data.isNotEmpty)
                            Text(
                              _summarize(data),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace'),
                            ),
                          if (when.isNotEmpty)
                            Text(when,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.black45)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _summarize(Map data) {
    // Prefer human fields; fall back to compact JSON.
    final parts = <String>[
      if (data['label'] != null) 'label=${data['label']}',
      if (data['confidence'] != null) 'conf=${data['confidence']}',
      if (data['value'] != null) 'value=${data['value']}',
      if (data['title'] != null) '${data['title']}: ${data['body'] ?? ''}',
    ];
    if (parts.isNotEmpty) return parts.join('  ');
    final s = data.toString();
    return s.length > 140 ? '${s.substring(0, 140)}…' : s;
  }
}
