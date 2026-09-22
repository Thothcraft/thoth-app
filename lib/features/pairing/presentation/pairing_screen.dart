import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/brain_client.dart';
import '../../devices/application/devices_provider.dart';

/// Pairing — claim the code shown by a device (Pi dashboard, thothcraftd,
/// or `thothcraft pair`) to bind it to this account.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final code = _code.text.trim().toUpperCase().replaceAll('THOTH-', '');
    if (code.length != 8) {
      setState(() => _error = 'Enter the 8-character code shown on the device');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final res = await BrainClient.instance
          .postJson('/device/pairing/claim', body: {'code': code});
      setState(() =>
          _success = res['message'] as String? ?? 'Device paired',);
      ref.invalidate(devicesProvider);
    } catch (e) {
      setState(() => _error = 'Pairing failed — check the code and try again');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair a device')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the pairing code shown on your Thoth device or '
              'printed by `thothcraft pair`.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                LengthLimitingTextInputFormatter(13),
              ],
              decoration: const InputDecoration(
                labelText: 'Pairing code',
                hintText: 'THOTH-XXXXXXXX',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              onSubmitted: (_) => _claim(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),),
            ],
            if (_success != null) ...[
              const SizedBox(height: 16),
              Text(_success!, style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/devices'),
                child: const Text('Go to devices'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _claim,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),)
                  : const Text('Pair'),
            ),
          ],
        ),
      ),
    );
  }
}
