import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/event_feed.dart';
import '../../context/application/context_providers.dart';
import '../../context/domain/models.dart';

/// Activity — one timeline of everything Brain is telling us:
/// semantic transitions (space enter/exit, polled so they never go
/// stale) merged with the live event stream (notifications, device
/// events). Apple-Fitness style day grouping + filter chips.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  /// Live events captured from the SSE feed while this screen is open.
  final List<_Item> _live = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _sub = EventFeed.instance.events.listen((batch) {
      if (!mounted) return;
      setState(() {
        _live.insertAll(0, batch.map(_itemFromFeed));
        if (_live.length > 200) _live.length = 200;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctxEvents = ref.watch(contextEventsProvider).valueOrNull ?? [];

    final items = <_Item>[
      ..._live,
      for (final e in ctxEvents) _itemFromContext(e),
    ]..sort((a, b) => b.ts.compareTo(a.ts));

    final filtered = _filter == 'all'
        ? items
        : items.where((i) => i.category == _filter).toList();

    return Column(children: [
      _FilterBar(
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f)),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(contextEventsProvider),
          child: filtered.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(children: [
                        Icon(Icons.timeline,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No activity yet',
                            style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text(
                            'Space transitions and device events appear '
                            'here as they happen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ]),
                    ),
                  ),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (c, i) {
                    final item = filtered[i];
                    final showHeader = i == 0 ||
                        !_sameDay(filtered[i - 1].ts, item.ts);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 14, 16, 4),
                            child: Text(_dayLabel(item.ts),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(c)
                                        .colorScheme
                                        .outline)),
                          ),
                        _EventTile(item: item),
                      ],
                    );
                  },
                ),
        ),
      ),
    ]);
  }

  // ── normalization ──────────────────────────────────────────────

  static _Item _itemFromContext(ContextEvent e) {
    final ts = e.timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch((e.timestamp! * 1000).round())
        : DateTime.now();
    final who = e.entityId?.split(':').last ?? 'entity';
    final place = _placeVal(e.value);
    return _Item(
      ts: ts,
      category: 'transitions',
      icon: switch (e.type) {
        'entered' => Icons.login,
        'exited' => Icons.logout,
        _ => Icons.swap_horiz,
      },
      color: switch (e.type) {
        'entered' => Colors.green,
        'exited' => Colors.grey,
        _ => Colors.blue,
      },
      title: '$who ${e.type} $place',
      sub: e.key,
    );
  }

  static _Item _itemFromFeed(Map<String, dynamic> e) {
    final kind = '${e['kind'] ?? 'event'}';
    final data = e['data'] is Map
        ? Map<String, dynamic>.from(e['data'] as Map)
        : const <String, dynamic>{};
    final tsRaw = e['ts'] ?? e['timestamp'] ?? data['ts'];
    DateTime ts;
    if (tsRaw is num) {
      ts = DateTime.fromMillisecondsSinceEpoch(
          (tsRaw > 1e12 ? tsRaw : tsRaw * 1000).round());
    } else {
      ts = DateTime.tryParse('$tsRaw') ?? DateTime.now();
    }
    final isNotif = kind == 'notification';
    return _Item(
      ts: ts,
      category: isNotif ? 'alerts' : 'system',
      icon: isNotif ? Icons.notifications_active : Icons.bolt,
      color: switch ('${data['severity'] ?? ''}') {
        'warning' => Colors.orange,
        'error' => Colors.red,
        _ => isNotif ? Colors.deepPurple : Colors.blueGrey,
      },
      title:
          '${data['title'] ?? e['type'] ?? e['event'] ?? kind}',
      sub: '${data['body'] ?? e['message'] ?? ''}',
    );
  }

  static String _placeVal(dynamic v) {
    if (v is Map) return '${v['space'] ?? v['space_id'] ?? v['name'] ?? v}';
    return '$v';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.year, t.month, t.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${t.month}/${t.day}/${t.year}';
  }
}

class _Item {
  const _Item({
    required this.ts,
    required this.category,
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });
  final DateTime ts;
  final String category;
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  static const _filters = {
    'all': 'All',
    'transitions': 'Transitions',
    'alerts': 'Alerts',
    'system': 'System',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final f in _filters.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.value),
                selected: selected == f.key,
                onSelected: (_) => onChanged(f.key),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    final t = item.ts;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 15,
        backgroundColor: item.color.withValues(alpha: 0.14),
        child: Icon(item.icon, size: 15, color: item.color),
      ),
      title: Text(item.title, style: const TextStyle(fontSize: 13.5)),
      subtitle: item.sub.isNotEmpty
          ? Text(item.sub,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: Text(time,
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }
}
