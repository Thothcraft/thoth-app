import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../context/application/context_providers.dart';
import '../application/setup_controller.dart';
import '../data/provisioning_transport.dart';
import '../domain/setup_contract.dart';

/// Node setup wizard (Parts 1–2): sign-in → QR → permissions → BLE
/// commissioning → Wi-Fi → claim → space → self-test → calibrate →
/// wearables → context. Every stage supports retry; a checkpoint
/// persists so the flow resumes after app restarts.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  @override
  void initState() {
    super.initState();
    _offerResume();
  }

  Future<void> _offerResume() async {
    final cp = await SetupController.savedCheckpoint();
    if (cp == null || !mounted) return;
    final stage = SetupStage.values[cp['stage'] as int? ?? 0];
    if (stage.index <= SetupStage.scanIdentity.index) return;
    final resume = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resume setup?'),
        content: Text(
            'A previous setup stopped at ${stage.name}. Continue from there?',),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Start over'),),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Resume'),),
        ],
      ),
    );
    if (resume == true && mounted) {
      ref.read(setupControllerProvider.notifier).resumeFrom(cp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(setupControllerProvider);
    final ctl = ref.read(setupControllerProvider.notifier);
    final reduce = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up a node')),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
          child: _stage(context, s, ctl),
        ),
      ),
      bottomNavigationBar: s.error != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Text(s.error!,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.error,),),
                  ),
                  TextButton(
                    onPressed: ctl.clearError,
                    child: const Text('Retry'),
                  ),
                ],),
              ),
            )
          : null,
    );
  }

  Widget _stage(BuildContext context, SetupState s, SetupController ctl) {
    switch (s.stage) {
      case SetupStage.signIn:
      case SetupStage.scanIdentity:
        return _ScanStep(
          key: const ValueKey('scan'),
          onIdentity: (id) => unawaited(ctl.acceptIdentity(id)),
        );
      case SetupStage.permissions:
      case SetupStage.discover:
        return _DiscoverStep(
          key: const ValueKey('discover'),
          identity: s.identity,
          onPick: (c) => unawaited(ctl.selectCandidate(c)),
        );
      case SetupStage.verify:
      case SetupStage.connect:
        return const _ProgressStep(
          key: ValueKey('verify'),
          title: 'Verifying setup identity',
          detail: 'Checking the node\'s advertised key against the '
              'scanned code…',
        );
      case SetupStage.identity:
      case SetupStage.wifiDetails:
        return _WifiStep(key: const ValueKey('wifi'), state: s, ctl: ctl);
      case SetupStage.provision:
        return _ProvisionStep(key: const ValueKey('prov'), state: s);
      case SetupStage.claim:
        return _ClaimStep(key: const ValueKey('claim'), state: s, ctl: ctl);
      case SetupStage.space:
        return _SpaceStep(key: const ValueKey('space'), ctl: ctl);
      case SetupStage.selfTest:
        return _SelfTestStep(key: const ValueKey('test'), state: s, ctl: ctl);
      case SetupStage.calibrate:
      case SetupStage.wearables:
        return _FinishStep(key: const ValueKey('done'), state: s, ctl: ctl);
      case SetupStage.done:
        return const _DoneStep(key: ValueKey('end'));
    }
  }
}

// ── step widgets ───────────────────────────────────────────────────────────

class _ScanStep extends StatefulWidget {
  const _ScanStep({super.key, required this.onIdentity});
  final ValueChanged<SetupIdentity> onIdentity;
  @override
  State<_ScanStep> createState() => _ScanStepState();
}

class _ScanStepState extends State<_ScanStep> {
  final _manual = TextEditingController();
  bool _manualMode = false;
  String? _error;

  void _accept(String raw) {
    final id = SetupIdentity.tryParse(raw);
    if (id == null) {
      setState(() => _error = 'Unrecognized setup code — check the sticker '
          'QR or enter the id:key pair.',);
      return;
    }
    widget.onIdentity(id);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Scan the setup code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),),
      const SizedBox(height: 6),
      const Text(
        'The QR on the device proves you\'re physically next to it — the '
        'app matches it to the commissioning advertisement before any '
        'credentials move.',
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 16),
      if (!_manualMode)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: MobileScanner(
              onDetect: (capture) {
                for (final b in capture.barcodes) {
                  final v = b.rawValue;
                  if (v != null && v.isNotEmpty) {
                    _accept(v);
                    break;
                  }
                }
              },
            ),
          ),
        )
      else
        TextField(
          controller: _manual,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          decoration: const InputDecoration(
            labelText: 'Setup payload',
            hintText: 'thoth://setup?id=…&k=…  or  id:key',
          ),
          onSubmitted: _accept,
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),),
        ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
          icon: Icon(_manualMode ? Icons.qr_code_scanner : Icons.keyboard),
          label: Text(_manualMode ? 'Scan instead' : 'Enter manually'),
          onPressed: () => setState(() => _manualMode = !_manualMode),
        ),
      ],),
      const SizedBox(height: 24),
      const Divider(),
      ListTile(
        dense: true,
        leading: const Icon(Icons.wifi_tethering_error),
        title: const Text('Node already flashed? AP recovery'),
        subtitle: const Text(
            'Use this only if the device is already broadcasting its own '
            'network — normal setup stays on Bluetooth.',
            style: TextStyle(fontSize: 11),),
        onTap: () => context.push('/setup/ap'),
      ),
    ],);
  }
}

class _DiscoverStep extends StatefulWidget {
  const _DiscoverStep({super.key, required this.identity, required this.onPick});
  final SetupIdentity? identity;
  final ValueChanged<CommissionCandidate> onPick;
  @override
  State<_DiscoverStep> createState() => _DiscoverStepState();
}

class _DiscoverStepState extends State<_DiscoverStep> {
  bool _permGranted = false;
  List<CommissionCandidate> _candidates = const [];
  StreamSubscription<List<CommissionCandidate>>? _sub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _askThenScan();
  }

  Future<void> _askThenScan() async {
    final granted = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (!mounted) return;
    setState(() =>
        _permGranted = granted.values.every((s) => s.isGranted),);
    if (!_permGranted) return;
    _startScan();
  }

  void _startScan() {
    _sub?.cancel();
    setState(() {
      _scanning = true;
      _candidates = const [];
    });
    _sub = BleCommissioningTransport.scan().listen((list) {
      if (mounted) setState(() => _candidates = list);
    }, onDone: () {
      if (mounted) setState(() => _scanning = false);
    },);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permGranted) {
      return _PermissionPane(
        onRetry: _askThenScan,
        onOpenSettings: openAppSettings,
      );
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        const Expanded(
          child: Text('Discovered nodes',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.w700),),
        ),
        if (_scanning)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),)
        else
          IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
      ],),
      const SizedBox(height: 6),
      const Text(
          'Only devices advertising the commissioning service appear. '
          'The app will verify the scanned code before connecting.',
          style: TextStyle(color: Colors.black54, fontSize: 12),),
      const SizedBox(height: 12),
      for (final c in _candidates)
        Card(
          child: ListTile(
            leading: const Icon(Icons.memory),
            title: Text(c.name),
            subtitle: Text('${c.id} · ${c.rssi} dBm'
                '${c.keyHash != null ? ' · key ${_matchTag(c.keyHash!)}' : ''}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onPick(c),
          ),
        ),
      if (_candidates.isEmpty && !_scanning)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No nodes found — hold the node\'s setup button until it '
              'advertises, then rescan.',
              textAlign: TextAlign.center,),
        ),
    ],);
  }

  String _matchTag(String advertised) {
    final id = widget.identity;
    if (id == null) return '';
    return matchCandidate(id, advertised) == MatchResult.matched
        ? '✓ match'
        : '≠';
  }
}

class _PermissionPane extends StatelessWidget {
  const _PermissionPane({required this.onRetry, required this.onOpenSettings});
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Bluetooth permission required',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w600),),
          const SizedBox(height: 8),
          const Text(
            'Commissioning talks to the node over BLE. Grant Nearby '
            'Devices permission, then retry. You can also use AP '
            'recovery (advanced).',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          TextButton(
              onPressed: onOpenSettings, child: const Text('Open settings'),),
        ],),
      );
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({super.key, required this.title, required this.detail});
  final String title, detail;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(),),
          const SizedBox(height: 24),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
        ],),
      );
}

class _WifiStep extends ConsumerStatefulWidget {
  const _WifiStep({super.key, required this.state, required this.ctl});
  final SetupState state;
  final SetupController ctl;
  @override
  ConsumerState<_WifiStep> createState() => _WifiStepState();
}

class _WifiStepState extends ConsumerState<_WifiStep> {
  final _ssid = TextEditingController();
  final _psk = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ssid.dispose();
    _psk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListView(padding: const EdgeInsets.all(20), children: [
      if (s.deviceModel != null || s.deviceUuid != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.verified_outlined, color: Colors.green),
            title: const Text('Node verified',
                style: TextStyle(fontWeight: FontWeight.w600),),
            subtitle: Text(
                '${s.deviceModel ?? 'node'} · ${s.deviceUuid ?? ''}',
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 11),),
          ),
        ),
      const SizedBox(height: 16),
      const Text('Wi-Fi credentials',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),),
      const SizedBox(height: 6),
      const Text(
          'Credentials travel over the commissioning channel only — the '
          'app never asks for an IP and never shows the password again.',
          style: TextStyle(color: Colors.black54, fontSize: 12),),
      const SizedBox(height: 16),
      TextField(
          controller: _ssid,
          decoration: const InputDecoration(
              labelText: 'Network name (SSID)',
              prefixIcon: Icon(Icons.wifi),),),
      const SizedBox(height: 12),
      TextField(
          controller: _psk,
          obscureText: _obscure,
          decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,),
                  onPressed: () =>
                      setState(() => _obscure = !_obscure),),),),
      const SizedBox(height: 24),
      FilledButton.icon(
        icon: const Icon(Icons.send),
        label: const Text('Provision node'),
        onPressed: _ssid.text.trim().isEmpty
            ? null
            : () => unawaited(widget.ctl
                .provisionWifi(_ssid.text.trim(), _psk.text),),
      ),
    ],);
  }
}

class _ProvisionStep extends StatelessWidget {
  const _ProvisionStep({super.key, required this.state});
  final SetupState state;

  @override
  Widget build(BuildContext context) {
    const labels = [
      (ProvisionPhase.connectingToNode, 'Connecting to node'),
      (ProvisionPhase.sendingCredentials, 'Sending credentials'),
      (ProvisionPhase.joiningWifi, 'Joining Wi-Fi'),
      (ProvisionPhase.networkVerified, 'Network verified'),
      (ProvisionPhase.connectingToService, 'Connecting to service'),
      (ProvisionPhase.registered, 'Registered'),
    ];
    final idx = labels.indexWhere((l) => l.$1 == state.provisionPhase);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Provisioning',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),),
      const SizedBox(height: 20),
      for (var i = 0; i < labels.length; i++)
        ListTile(
          dense: true,
          leading: Icon(
            i < idx || state.provisionPhase == ProvisionPhase.registered
                ? Icons.check_circle
                : i == idx
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
            color: i <= idx || state.provisionPhase == ProvisionPhase.registered
                ? Colors.green
                : Colors.grey,
            size: 20,
          ),
          title: Text(labels[i].$2),
          trailing: i == idx && state.busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),)
              : null,
        ),
      if (state.provisionPhase == ProvisionPhase.failed)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(state.error ?? 'Provisioning failed',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),),
        ),
    ],);
  }
}

class _ClaimStep extends ConsumerStatefulWidget {
  const _ClaimStep({super.key, required this.state, required this.ctl});
  final SetupState state;
  final SetupController ctl;
  @override
  ConsumerState<_ClaimStep> createState() => _ClaimStepState();
}

class _ClaimStepState extends ConsumerState<_ClaimStep> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // If the node already handed us a pairing code, claim immediately.
    if (widget.state.pairingCode != null) {
      unawaited(_claim());
    }
  }

  Future<void> _claim([String? manual]) async {
    setState(() => _busy = true);
    final ok = manual != null
        ? await widget.ctl.claimWithCode(manual)
        : await widget.ctl.claim();
    if (mounted) setState(() => _busy = false);
    if (!ok && manual == null && mounted) {
      // Fall through to manual entry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = widget.state.pairingCode != null;
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Link node to your account',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),),
      const SizedBox(height: 12),
      if (hasCode)
        ListTile(
          leading: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),)
              : const Icon(Icons.key, color: Colors.green),
          title: const Text('Claiming with node-provided code…'),
        )
      else ...[
        const Text(
            'The node did not emit a pairing code — enter the code on its '
            'screen (or `thothcraft pair` output) instead.'),
        const SizedBox(height: 12),
        TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'Pairing code', hintText: 'THOTH-XXXXXXXX',),),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: _busy ? null : () => _claim(_code.text.trim()),
            child: const Text('Claim'),),
      ],
    ],);
  }
}

class _SpaceStep extends ConsumerWidget {
  const _SpaceStep({super.key, required this.ctl});
  final SetupController ctl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(spacesLiveProvider);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Assign to a space',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),),
      const SizedBox(height: 6),
      const Text('Where is this node physically installed?',
          style: TextStyle(color: Colors.black54),),
      const SizedBox(height: 16),
      spaces.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('$e'),
        data: (list) => Column(children: [
          for (final s in list)
            Card(
              child: ListTile(
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text(s.name),
                onTap: () => unawaited(ctl.assignSpace(s.id)),
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create new space'),
            onPressed: () async {
              final ctl2 = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('New space'),
                  content: TextField(
                      controller: ctl2,
                      decoration:
                          const InputDecoration(hintText: 'e.g. office'),),
                  actions: [
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Create'),),
                  ],
                ),
              );
              if (ok == true && ctl2.text.trim().isNotEmpty) {
                final space = await ref
                    .read(contextRepoProvider)
                    .createSpace(ctl2.text.trim());
                unawaited(ctl.assignSpace(space.id));
              }
            },
          ),
          TextButton(
              onPressed: () => unawaited(ctl.selfTest()),
              child: const Text('Skip — assign later'),),
        ],),
      ),
    ],);
  }
}

class _SelfTestStep extends ConsumerStatefulWidget {
  const _SelfTestStep({super.key, required this.state, required this.ctl});
  final SetupState state;
  final SetupController ctl;
  @override
  ConsumerState<_SelfTestStep> createState() => _SelfTestStepState();
}

class _SelfTestStepState extends ConsumerState<_SelfTestStep> {
  @override
  void initState() {
    super.initState();
    if (widget.state.capabilities.isEmpty &&
        widget.state.stage == SetupStage.selfTest) {
      unawaited(widget.ctl.selfTest());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(setupControllerProvider);
    final caps = s.capabilities;
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Hardware check',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),),
      const SizedBox(height: 16),
      if (caps.isEmpty)
        const Center(child: CircularProgressIndicator())
      else
        Card(
          child: Column(children: [
            for (final c in caps)
              ListTile(
                dense: true,
                leading: Icon(
                    c['ok'] == false ? Icons.error : Icons.check_circle,
                    color: c['ok'] == false ? Colors.red : Colors.green,
                    size: 18,),
                title: Text('${c['id']}',
                    style: const TextStyle(fontFamily: 'monospace'),),
                subtitle: Text('${c['detail'] ?? 'detected'}',
                    style: const TextStyle(fontSize: 11),),
              ),
          ],),
        ),
      const SizedBox(height: 24),
      FilledButton(
          onPressed: () => widget.ctl.goToStage(SetupStage.calibrate),
          child: const Text('Continue'),),
    ],);
  }
}

class _FinishStep extends ConsumerWidget {
  const _FinishStep({super.key, required this.state, required this.ctl});
  final SetupState state;
  final SetupController ctl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.check_circle, size: 56, color: Colors.green),
      const SizedBox(height: 12),
      const Text('Node is online',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),),
      const SizedBox(height: 24),
      Card(
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.radar),
            title: const Text('Calibrate localization'),
            subtitle: const Text(
                'Optional — walk a short path so BLE fingerprints map '
                'to this space\'s zones.'),
            onTap: () => context.push('/calibrate'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.watch),
            title: const Text('Enroll a wearable'),
            subtitle: const Text(
                'Optional — associate a PineTime with a person so the '
                'node attributes IMU evidence.'),
            onTap: () => context.push('/watch/enroll'),
          ),
        ],),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        icon: const Icon(Icons.insights),
        label: const Text('Open live context'),
        onPressed: () async {
          await ctl.finish();
          if (context.mounted) context.go('/context');
        },
      ),
    ],);
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Setup complete — opening context…'),
      );
}
