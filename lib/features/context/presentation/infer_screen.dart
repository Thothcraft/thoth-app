import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../watch/application/watch_providers.dart';
import '../application/context_providers.dart';
import '../domain/models.dart';

/// LLM context inference — phone port of the Portal "Infer" tab.
///
/// Drives Brain's /v1/context/infer: pick a tier or an explicit
/// large-context model, let Brain gather the stored evidence bundle,
/// and inspect what the model saw / produced. The verdict can also be
/// pushed to a paired PineTime as an ANS alert.
class InferScreen extends ConsumerStatefulWidget {
  const InferScreen({super.key});

  @override
  ConsumerState<InferScreen> createState() => _InferScreenState();
}

class _InferScreenState extends ConsumerState<InferScreen> {
  InferOptions _options = const InferOptions();
  String _tier = 'standard';
  String? _model; // null → tier default
  bool _gather = true;
  bool _dryRun = false;
  bool _busy = false;
  final _gatherCtl = TextEditingController(text: '900');
  final _hintCtl = TextEditingController();
  InferResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gatherCtl.dispose();
    _hintCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(contextRepoProvider);
    try {
      final opts = await repo.inferOptions();
      final last = await repo.inferLast();
      if (!mounted) return;
      setState(() {
        _options = opts;
        _gatherCtl.text = opts.gatherDefaultS.round().toString();
        if (last != null && last.summary != null) {
          _result = last.toResult();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(contextRepoProvider).infer(
            thinking: _tier,
            model: _model,
            gatherWindowS: _gather
                ? double.tryParse(_gatherCtl.text) ?? _options.gatherDefaultS
                : 0,
            entityHint: _hintCtl.text.trim(),
            dryRun: _dryRun,
          );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Push the verdict to every connected watch as an ANS alert
  /// (category 9 = instant message — vibrates + shows on the band).
  Future<void> _sendToWatch() async {
    final r = _result;
    if (r == null) return;
    final relays = ref.read(watchManagerProvider).values
        .where((w) => w.connected && w.link != null)
        .toList();
    if (relays.isEmpty) {
      _toast('No watch connected — pair one on the Watch tab.');
      return;
    }
    final body = '${r.summary ?? 'context update'}'
        '${r.analysis != null ? '\n${r.analysis}' : ''}';
    var sent = 0;
    for (final relay in relays) {
      try {
        await relay.link!.sendAlert(category: 9,
            title: 'Thoth context',
            body: body.length > 240 ? '${body.substring(0, 240)}…' : body,);
        sent++;
      } catch (e) {
        debugPrint('[infer] watch alert: $e');
      }
    }
    _toast(sent > 0
        ? 'Sent to $sent watch${sent == 1 ? '' : 'es'}'
        : 'Watch alert failed — is it in range?',);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Controls ────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, size: 18,
                      color: AppColors.primaryBlue,),
                  const SizedBox(width: 8),
                  Text('Context inference',
                      style: Theme.of(context).textTheme.titleSmall,),
                ],),
                const SizedBox(height: 4),
                Text('LLM judges the stored sensor evidence — occupancy, '
                    'device identity, activity.',
                    style: Theme.of(context).textTheme.bodySmall,),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _tier,
                  decoration: const InputDecoration(
                      labelText: 'Reasoning tier', isDense: true,),
                  items: [
                    for (final t in (_options.tiers.isEmpty
                        ? const ['quick', 'standard', 'deep']
                        : _options.tiers))
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) =>
                      setState(() => _tier = v ?? 'standard'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _model ?? '',
                  decoration: const InputDecoration(
                      labelText: 'Model (explicit override)',
                      isDense: true,),
                  items: [
                    DropdownMenuItem(value: '',
                        child: Text('tier default'
                            '${_options.defaults[_tier] != null
                                ? ' · ${_options.defaults[_tier]}'
                                : ''}'),),
                    for (final m in _options.models)
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setState(
                      () => _model = (v == null || v.isEmpty) ? null : v,),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gather stored evidence',
                      style: TextStyle(fontSize: 13),),
                  subtitle: const Text(
                      'Brain assembles devices + scenes + scans + map',
                      style: TextStyle(fontSize: 11),),
                  value: _gather,
                  onChanged: (v) => setState(() => _gather = v),
                ),
                if (_gather)
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Gather window (seconds)',
                        isDense: true,),
                    controller: _gatherCtl,
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _hintCtl,
                  decoration: const InputDecoration(
                      labelText: 'Entity hint (optional)',
                      hintText: 'e.g. person:me, place:office',
                      isDense: true,),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dry run', style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                      'Preview only — nothing written to the map',
                      style: TextStyle(fontSize: 11),),
                  value: _dryRun,
                  onChanged: (v) => setState(() => _dryRun = v),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _run,
                      icon: _busy
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,),)
                          : const Icon(Icons.play_arrow, size: 18),
                      label: Text(_busy ? 'Inferring…' : 'Infer now'),
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Send verdict to watch',
                      onPressed: _sendToWatch,
                      icon: const Icon(Icons.watch_outlined),
                    ),
                  ],
                ],),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,),),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_result != null) ...[
          // ── What the model produced ───────────────────────────────
          _SectionLabel('What the model produced'
              '${_result!.modelId != null ? ' · ${_result!.modelId}' : ''}'
              '${_result!.dryRun ? ' · dry run' : ''}'),
          if (_result!.summary != null)
            _BodyCard(_result!.summary!),
          if (_result!.analysis != null)
            _BodyCard(_result!.analysis!),
          if (_result!.states.isNotEmpty)
            _JsonList('States', _result!.states),
          if (_result!.deviceUpdates.isNotEmpty)
            _JsonList('Device naming proposals', _result!.deviceUpdates),
          if (_result!.entities.isNotEmpty)
            _JsonList('Entities', _result!.entities),
          if (_result!.relationships.isNotEmpty)
            _JsonList('Relationships', _result!.relationships),
          if (_result!.questions.isNotEmpty)
            _JsonList('Questions', _result!.questions),
          if (_result!.uncertainties.isNotEmpty)
            _JsonList('Uncertainties', _result!.uncertainties),
          if (_result!.modelText != null)
            _Json('Raw model output', _result!.modelText!),
          const SizedBox(height: 16),

          // ── What the model saw ────────────────────────────────────
          const _SectionLabel('What the model saw'),
          if (_result!.seen == null || _result!.seen!.isEmpty)
            const _BodyCard('(no payload echo retained)'),
          for (final e in (_result!.seen ?? const {}).entries)
            if (e.value != null &&
                (e.value is! List || (e.value as List).isNotEmpty) &&
                (e.value is! Map || (e.value as Map).isNotEmpty))
              _Json(e.key, e.value),
        ] else
          const _BodyCard(
              'No run yet — press Infer now, or wait for the stored '
              'last run to load.'),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _BodyCard extends StatelessWidget {
  const _BodyCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      );
}

/// Collapsible JSON section — one per payload/form key.
class _Json extends StatelessWidget {
  const _Json(this.title, this.value);
  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final pretty = value is String
        ? value as String
        : const JsonEncoder.withIndent('  ').convert(value);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        visualDensity: VisualDensity.compact,
        title: Text(title, style: const TextStyle(fontSize: 13)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          SizedBox(
            width: double.infinity,
            child: SelectableText(pretty,
                style: const TextStyle(
                    fontSize: 11, fontFamily: 'monospace',),),
          ),
        ],
      ),
    );
  }
}

/// Count + collapsible list — states/proposals/questions.
class _JsonList extends StatelessWidget {
  const _JsonList(this.title, this.items);
  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) => _Json(
      '$title (${items.length})',
      items.map((e) => e is Map
          ? Map<String, dynamic>.from(e) : '$e',).toList(),);
}
