import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/brain_client.dart';

/// Actuators/Automations tab — Brain-side rules (/v1/automation/rules) that
/// turn predictions/context into actuator commands, plus the ActionRequest
/// queue (/v1/automation/actions) showing what fired, queued, or failed.
class ActuatorsScreen extends ConsumerStatefulWidget {
  const ActuatorsScreen({super.key});

  @override
  ConsumerState<ActuatorsScreen> createState() => _ActuatorsScreenState();
}

class _ActuatorsScreenState extends ConsumerState<ActuatorsScreen> {
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _actions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = BrainClient.instance;
      final rules = await client.getV1('/automation/rules');
      final actions = await client.getV1('/automation/actions');
      setState(() {
        _rules = (rules['rules'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _actions = (actions['actions'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleRule(Map<String, dynamic> rule, bool enabled) async {
    try {
      await BrainClient.instance.postV1('/automation/rules', body: {
        'name': rule['name'],
        'when': _decode(rule['when']),
        'then': _decode(rule['then']),
        'cooldown_s': rule['cooldown_s'] ?? 0,
        'enabled': enabled,
      });
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Toggle failed: $e')));
      }
    }
  }

  Map<String, dynamic> _decode(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(json.decode(v));
      } catch (_) {}
    }
    return const {};
  }

  Future<void> _evaluate() async {
    try {
      final res = await BrainClient.instance.postV1('/automation/evaluate');
      await _reload();
      if (mounted) {
        final fired = (res['fired'] as List? ?? const []).length;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Evaluated — $fired rule(s) fired')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Evaluate failed: $e')));
      }
    }
  }

  Future<void> _redispatch(String actionId) async {
    try {
      await BrainClient.instance
          .postV1('/automation/actions/$actionId/dispatch');
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Dispatch failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(text: 'Rules'),
            Tab(text: 'Actions'),
          ]),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text('Failed to load\n$_error',
                            textAlign: TextAlign.center))
                    : TabBarView(children: [
                        _rulesTab(),
                        _actionsTab(),
                      ]),
          ),
        ],
      ),
    );
  }

  Widget _rulesTab() {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Evaluate now'),
              onPressed: _evaluate,
            ),
          ]),
          const SizedBox(height: 8),
          if (_rules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                    'No automation rules yet.\nRules fire actuators when predictions/context change — create them in the portal.',
                    textAlign: TextAlign.center),
              ),
            ),
          for (final r in _rules)
            Card(
              child: SwitchListTile(
                dense: true,
                title: Text('${r['name']}',
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  'when ${_short(r['when'])} → then ${_short(r['then'])}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
                value: r['enabled'] != false,
                onChanged: (v) => _toggleRule(r, v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionsTab() {
    return RefreshIndicator(
      onRefresh: _reload,
      child: _actions.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(
                  child: Text(
                      'No action requests yet.\nThey appear when rules fire or actuators are called.')),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _actions.length,
              itemBuilder: (context, i) {
                final a = _actions[i];
                final status = '${a['status'] ?? 'queued'}';
                final queued = status == 'queued' || status == 'failed';
                return Card(
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      status == 'delivered'
                          ? Icons.check_circle
                          : status == 'failed'
                              ? Icons.error
                              : Icons.schedule,
                      color: status == 'delivered'
                          ? Colors.green
                          : status == 'failed'
                              ? Colors.red
                              : Colors.orange,
                      size: 20,
                    ),
                    title: Text(
                        '${a['actuator_id'] ?? a['action_id'] ?? 'action'}',
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${a['command'] ?? _short(a['payload'])} • $status',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
                    ),
                    trailing: queued
                        ? IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Redispatch',
                            onPressed: () =>
                                _redispatch('${a['action_id']}'),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  String _short(dynamic v) {
    final s = v is String ? v : json.encode(_decode(v));
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }
}
