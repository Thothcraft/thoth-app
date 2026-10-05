import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/setup_controller.dart';
import '../data/provisioning_transport.dart';

/// AP recovery flow (Part 2) — advanced path only. Guides the user onto
/// the node's temporary network, then hands control to the shared
/// [SetupController] so no provisioning logic is duplicated.
class ApRecoveryScreen extends ConsumerStatefulWidget {
  const ApRecoveryScreen({super.key});

  @override
  ConsumerState<ApRecoveryScreen> createState() => _ApRecoveryScreenState();
}

enum _ApStep { enterRecovery, joinAp, connect, send, waitJoin, done }

class _ApRecoveryScreenState extends ConsumerState<ApRecoveryScreen> {
  _ApStep _step = _ApStep.enterRecovery;
  String? _error;
  final _ssid = TextEditingController();
  final _psk = TextEditingController();
  ApProvisioningTransport? _transport;

  @override
  void dispose() {
    _transport?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _step = _ApStep.connect;
      _error = null;
    });
    _transport = ApProvisioningTransport();
    try {
      // Verify we reached the node's AP endpoints.
      await _transport!.readIdentity();
      await ref
          .read(setupControllerProvider.notifier)
          .startApRecovery(_transport!);
      setState(() => _step = _ApStep.send);
    } catch (e) {
      setState(() {
        _step = _ApStep.joinAp;
        _error = 'Could not reach the node on its temporary network — '
            'make sure Wi-Fi is connected to it.';
      });
    }
  }

  Future<void> _send() async {
    setState(() => _step = _ApStep.waitJoin);
    try {
      // Reuses the same provisionWifi pipeline — AP poll detects the
      // node leaving AP mode, then claim/space resume via the machine.
      await ref
          .read(setupControllerProvider.notifier)
          .provisionWifi(_ssid.text.trim(), _psk.text);
      setState(() => _step = _ApStep.done);
    } catch (e) {
      setState(() {
        _step = _ApStep.send;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AP recovery')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Banner(
          message: 'advanced',
          location: BannerLocation.topEnd,
          child: SizedBox(height: 0),
        ),
        const Text('Recovery via temporary network',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Only use this when BLE commissioning is unavailable. The node '
          'broadcasts its own Wi-Fi network in recovery mode — join it, '
          'send your credentials, and the node leaves AP mode and resumes '
          'the normal claim flow automatically.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        _stepRow(0, 'Hold the node\'s setup button until its AP network '
            'appears (name usually starts with "thoth-").',
            _step.index >= 0),
        _stepRow(1, 'In system Wi-Fi settings, join that temporary '
            'network, then return here.',
            _step.index >= 1),
        if (_step == _ApStep.joinAp)
          FilledButton(
              onPressed: _connect, child: const Text('I\'m connected')),
        if (_step == _ApStep.connect)
          const ListTile(
              leading: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              title: Text('Reaching node…')),
        if (_step == _ApStep.send) ...[
          const SizedBox(height: 8),
          TextField(
              controller: _ssid,
              decoration:
                  const InputDecoration(labelText: 'Home Wi-Fi (SSID)')),
          const SizedBox(height: 8),
          TextField(
              controller: _psk,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 12),
          FilledButton(onPressed: _send, child: const Text('Send credentials')),
        ],
        if (_step == _ApStep.waitJoin)
          const ListTile(
              leading: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              title: Text('Node is joining your network…'),
              subtitle: Text(
                  'Reconnect your phone to your normal Wi-Fi — the app '
                  'will find the node through the service.')),
        if (_step == _ApStep.done)
          ListTile(
            leading:
                const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Node joined the network'),
            subtitle: const Text('Continue setup to claim and assign it.'),
            trailing: FilledButton(
                onPressed: () => context.pushReplacement('/setup'),
                child: const Text('Continue')),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ]),
    );
  }

  Widget _stepRow(int idx, String text, bool reached) => ListTile(
        dense: true,
        leading: Icon(
            reached ? Icons.check_circle : Icons.radio_button_off,
            color: reached ? Colors.green : Colors.grey,
            size: 20),
        title: Text(text, style: const TextStyle(fontSize: 13)),
      );
}
