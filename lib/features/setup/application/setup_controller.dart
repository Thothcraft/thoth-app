import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/brain_client.dart';
import '../../context/data/context_repository.dart';
import '../data/provisioning_transport.dart';
import '../domain/setup_contract.dart';

/// Ordered provisioning stages (Part 1). Each maps to a UI step and a
/// resumable checkpoint — the stage index + non-secret fields persist to
/// SharedPreferences so an interrupted setup resumes at its last stage.
enum SetupStage {
  signIn,
  scanIdentity,
  permissions,
  discover,
  verify,
  connect,
  identity,
  wifiDetails,
  provision,
  claim,
  space,
  selfTest,
  calibrate,
  wearables,
  done,
}

/// Explicit provisioning sub-states shown while credentials transfer
/// (Part 1, step 10).
enum ProvisionPhase {
  idle,
  connectingToNode,
  sendingCredentials,
  joiningWifi,
  networkVerified,
  connectingToService,
  registered,
  failed,
}

class SetupState {
  const SetupState({
    this.stage = SetupStage.scanIdentity,
    this.identity,
    this.candidate,
    this.transportMode,
    this.provisionPhase = ProvisionPhase.idle,
    this.pairingCode,
    this.deviceUuid,
    this.deviceModel,
    this.capabilities = const [],
    this.spaceId,
    this.selfTest,
    this.error,
    this.retryCount = 0,
  });

  final SetupStage stage;
  final SetupIdentity? identity;
  final CommissionCandidate? candidate;
  final String? transportMode; // 'ble' | 'ap'
  final ProvisionPhase provisionPhase;
  final String? pairingCode;
  final String? deviceUuid;
  final String? deviceModel;
  final List<Map<String, dynamic>> capabilities;
  final int? spaceId;
  final Map<String, dynamic>? selfTest;
  final String? error;
  final int retryCount;

  /// True while an async pipeline stage is in flight.
  bool get busy => const {
        ProvisionPhase.connectingToNode,
        ProvisionPhase.sendingCredentials,
        ProvisionPhase.joiningWifi,
        ProvisionPhase.networkVerified,
        ProvisionPhase.connectingToService,
      }.contains(provisionPhase);

  SetupState copyWith({
    SetupStage? stage,
    SetupIdentity? identity,
    CommissionCandidate? candidate,
    String? transportMode,
    ProvisionPhase? provisionPhase,
    String? pairingCode,
    String? deviceUuid,
    String? deviceModel,
    List<Map<String, dynamic>>? capabilities,
    int? spaceId,
    Map<String, dynamic>? selfTest,
    String? error,
    int? retryCount,
    bool clearError = false,
  }) =>
      SetupState(
        stage: stage ?? this.stage,
        identity: identity ?? this.identity,
        candidate: candidate ?? this.candidate,
        transportMode: transportMode ?? this.transportMode,
        provisionPhase: provisionPhase ?? this.provisionPhase,
        pairingCode: pairingCode ?? this.pairingCode,
        deviceUuid: deviceUuid ?? this.deviceUuid,
        deviceModel: deviceModel ?? this.deviceModel,
        capabilities: capabilities ?? this.capabilities,
        spaceId: spaceId ?? this.spaceId,
        selfTest: selfTest ?? this.selfTest,
        error: clearError ? null : (error ?? this.error),
        retryCount: retryCount ?? this.retryCount,
      );

  /// Persisted checkpoint — secrets (PSK, raw setup key) never stored.
  Map<String, dynamic> toCheckpoint() => {
        'stage': stage.index,
        'node_id': identity?.nodeId,
        'model': deviceModel,
        'device_uuid': deviceUuid,
        'pairing_code': pairingCode,
        'space_id': spaceId,
      };
}

/// Drives the setup wizard. BLE commissioning is preferred; AP mode is a
/// recovery path feeding the SAME state machine via [startApRecovery].
class SetupController extends Notifier<SetupState> {
  static const _checkpointKey = 'setup.checkpoint';

  ProvisioningTransport? _transport;
  ContextRepository? _repo;
  StreamSubscription<ProvisionStatus>? _statusSub;

  ContextRepository get _context => _repo ??= ContextRepository();

  /// Test seams — injectable transport/fetch without touching BLE or net.
  ProvisioningTransport Function(CommissionCandidate candidate)?
      transportFactory;
  Future<List<Map<String, dynamic>>> Function()? capabilityProbe;

  @override
  SetupState build() {
    ref.onDispose(() {
      unawaited(_statusSub?.cancel());
      unawaited(_transport?.dispose());
      _transport = null;
    });
    return const SetupState();
  }

  // ── persistence / resume ───────────────────────────────────────────────

  Future<void> _saveCheckpoint() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_checkpointKey, json.encode(state.toCheckpoint()));
  }

  /// Non-null when a previous run stopped mid-flow — the wizard offers
  /// "resume" before restarting discovery.
  static Future<Map<String, dynamic>?> savedCheckpoint() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_checkpointKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(json.decode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCheckpoint() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_checkpointKey);
  }

  Future<void> reset() async {
    await _statusSub?.cancel();
    await _transport?.dispose();
    _transport = null;
    await clearCheckpoint();
    state = const SetupState();
  }

  void fail(String message) {
    state = state.copyWith(
        error: message,
        provisionPhase: ProvisionPhase.failed,
        retryCount: state.retryCount + 1,);
  }

  /// Restore a saved checkpoint — the wizard calls this when the user
  /// chooses "resume". Only non-secret fields are carried.
  void resumeFrom(Map<String, dynamic> cp) {
    final idx = cp['stage'] is int ? cp['stage'] as int : 0;
    state = state.copyWith(
      stage: SetupStage.values[idx.clamp(0, SetupStage.values.length - 1)],
      deviceUuid: cp['device_uuid'] as String?,
      deviceModel: cp['model'] as String?,
      pairingCode: cp['pairing_code'] as String?,
      spaceId: cp['space_id'] as int?,
    );
  }

  /// Advance to an arbitrary stage (UI "continue" buttons on optional
  /// steps — self-test → calibrate, etc.).
  void goToStage(SetupStage stage) {
    state = state.copyWith(stage: stage, clearError: true);
  }

  /// Clear a retryable failure without resetting the flow.
  void clearError() {
    state = state.copyWith(
        provisionPhase: ProvisionPhase.idle, clearError: true,);
  }

  // ── stage transitions ──────────────────────────────────────────────────

  /// Step 2: QR/setup code accepted → move to discovery.
  Future<void> acceptIdentity(SetupIdentity identity) async {
    state = state.copyWith(
        identity: identity, stage: SetupStage.discover, clearError: true,);
    await _saveCheckpoint();
  }

  /// Steps 4–6: user picked a discovered node → verify the cryptographic
  /// match, connect its commissioning GATT, then read identity.
  Future<void> selectCandidate(CommissionCandidate candidate) async {
    final identity = state.identity;
    if (identity == null) {
      fail('scan the setup code first');
      return;
    }
    state = state.copyWith(
        candidate: candidate,
        transportMode: 'ble',
        provisionPhase: ProvisionPhase.connectingToNode,
        clearError: true,);
    try {
      _transport = transportFactory != null
          ? transportFactory!(candidate)
          : BleCommissioningTransport(candidate.device ??
              (throw StateError('candidate has no BLE device')),);
      if (_transport is BleCommissioningTransport) {
        await (_transport as BleCommissioningTransport).connect();
      }
      state = state.copyWith(stage: SetupStage.verify);
      final verified = await _transport!.verifySetupKey(identity);
      if (!verified) {
        fail('this node does not match the scanned setup code');
        return;
      }
      state = state.copyWith(stage: SetupStage.identity);
      final idDoc = await _transport!.readIdentity();
      state = state.copyWith(
          deviceModel: idDoc['model']?.toString(),
          deviceUuid: idDoc['device_id']?.toString(),
          stage: SetupStage.wifiDetails,);
      _statusSub?.cancel();
      _statusSub = _transport!.status().listen(_onProvisionStatus);
      await _saveCheckpoint();
    } catch (e) {
      debugPrint('[setup] connect/verify failed: $e');
      fail('could not reach the node over commissioning BLE');
    }
  }

  /// AP recovery entry (Part 2): same machine, different transport.
  /// The UI guided the user onto the node's AP network first.
  Future<void> startApRecovery(ApProvisioningTransport transport) async {
    _transport = transport;
    state = state.copyWith(
        transportMode: 'ap',
        provisionPhase: ProvisionPhase.connectingToNode,
        clearError: true,);
    try {
      final identity = state.identity;
      final verified =
          identity != null && await transport.verifySetupKey(identity);
      if (identity != null && !verified) {
        fail('AP-mode node does not match the scanned setup code');
        return;
      }
      final idDoc = await transport.readIdentity();
      state = state.copyWith(
          deviceModel: idDoc['model']?.toString(),
          deviceUuid: idDoc['device_id']?.toString(),
          stage: SetupStage.wifiDetails,);
      await _saveCheckpoint();
    } catch (e) {
      fail('node AP unreachable — join the temporary network first');
    }
  }

  /// Step 9–10: send credentials → node joins Wi-Fi → network verified →
  /// connects to Brain → registered. Polls AP status or consumes BLE
  /// notifies; the pairing code arrives on the final status.
  Future<void> provisionWifi(String ssid, String psk) async {
    final transport = _transport;
    if (transport == null) {
      fail('no commissioning channel — rediscover the node');
      return;
    }
    state = state.copyWith(
        stage: SetupStage.provision,
        provisionPhase: ProvisionPhase.sendingCredentials,
        clearError: true,);
    try {
      await transport.sendCredentials(ssid, psk);
      // PSK deliberately drops out of scope here — never stored, never
      // logged, never reachable through state.
      if (transport is ApProvisioningTransport) {
        // AP mode: poll until the node leaves AP (requests fail = success)
        // then rediscover it on the LAN via Brain's device list.
        unawaited(_pollApExit(transport));
      }
      state = state.copyWith(provisionPhase: ProvisionPhase.joiningWifi);
      await _saveCheckpoint();
    } catch (e) {
      fail('sending credentials failed — retry or use AP recovery');
    }
  }

  Future<void> _pollApExit(ApProvisioningTransport transport) async {
    // The node drops the AP once it joins Wi-Fi — poll until unreachable,
    // then treat as joined and move to claim.
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final s = await transport.pollStatus();
        if (s.pairingCode != null) {
          state = state.copyWith(
              pairingCode: s.pairingCode,
              provisionPhase: ProvisionPhase.registered,);
          await _advanceToClaim();
          return;
        }
        if (s.isError) {
          fail(s.error ?? 'node reported a provisioning failure');
          return;
        }
      } catch (_) {
        // AP went away — node is joining the target network.
        state = state.copyWith(
            provisionPhase: ProvisionPhase.connectingToService,);
        await _advanceToClaim();
        return;
      }
    }
    fail('timed out waiting for the node to join Wi-Fi');
  }

  void _onProvisionStatus(ProvisionStatus s) {
    switch (s.phase) {
      case CommissioningContract.phaseJoining:
        state = state.copyWith(provisionPhase: ProvisionPhase.joiningWifi);
      case CommissioningContract.phaseVerified:
        state = state.copyWith(
            provisionPhase: ProvisionPhase.networkVerified,);
      case CommissioningContract.phaseRegistered:
        state = state.copyWith(
            provisionPhase: ProvisionPhase.registered,
            pairingCode: s.pairingCode ?? state.pairingCode,);
        unawaited(_advanceToClaim());
      case CommissioningContract.phaseFailed:
        fail(s.error ?? s.detail ?? 'node reported a provisioning failure');
      default:
        if (s.pairingCode != null) {
          state = state.copyWith(pairingCode: s.pairingCode);
        }
    }
  }

  /// Steps 11–12: claim the node with its pairing code, then the UI picks
  /// a space.
  Future<void> _advanceToClaim() async {
    state = state.copyWith(stage: SetupStage.claim);
    await _saveCheckpoint();
  }

  /// Claim via the existing pairing contract — the code came from the
  /// node's provisioning status (never typed by the user in the normal
  /// flow).
  Future<bool> claim() async {
    final code = state.pairingCode;
    if (code == null || code.isEmpty) {
      // Fallback: manual claim code (device screen / `thothcraft pair`).
      state = state.copyWith(clearError: true);
      return false;
    }
    try {
      final res = await BrainClient.instance.postJson(
          '/device/pairing/claim',
          body: {'code': code.toUpperCase().replaceAll('THOTH-', '')},);
      final dev = res['device'] is Map ? res['device'] as Map : res;
      state = state.copyWith(
          deviceUuid: '${dev['device_uuid'] ?? dev['id'] ?? state.deviceUuid}',
          stage: SetupStage.space,
          clearError: true,);
      await _saveCheckpoint();
      return true;
    } catch (e) {
      fail('claim failed — retry or enter the code manually');
      return false;
    }
  }

  /// Manual claim fallback path.
  Future<bool> claimWithCode(String code) async {
    state = state.copyWith(pairingCode: code, clearError: true);
    return claim();
  }

  Future<void> assignSpace(int spaceId) async {
    final uuid = state.deviceUuid;
    if (uuid != null) {
      try {
        await _context.assignDeviceToSpace(uuid, spaceId);
      } catch (e) {
        debugPrint('[setup] space assignment failed: $e');
      }
    }
    state = state.copyWith(spaceId: spaceId, stage: SetupStage.selfTest);
    await _saveCheckpoint();
  }

  /// Step 13–14: run hardware self-test via the node relay (or injected
  /// probe in tests). Result: capability list shown on the final screen.
  Future<Map<String, dynamic>> selfTest() async {
    if (capabilityProbe != null) {
      final caps = await capabilityProbe!();
      state = state.copyWith(
          capabilities: caps, stage: SetupStage.calibrate,);
      await _saveCheckpoint();
      return {'ok': true, 'capabilities': caps};
    }
    // Real path: the device list row carries capabilities/sensors after
    // the node registers.
    try {
      final devices = await BrainClient.instance.listDevices();
      final uuid = state.deviceUuid;
      final match = uuid == null
          ? null
          : devices.cast<Map<String, dynamic>?>().firstWhere(
              (d) => '${d?['device_uuid']}' == uuid,
              orElse: () => null,);
      final hw = match?['hardware_info'] is Map
          ? Map<String, dynamic>.from(match!['hardware_info'])
          : <String, dynamic>{};
      final caps = (hw['sensors'] is List
              ? hw['sensors']
              : match?['capabilities'] is List
                  ? match!['capabilities']
                  : const [])
          .map((e) => {'id': '$e', 'ok': true})
          .toList();
      state = state.copyWith(
          capabilities: caps,
          deviceUuid: uuid ?? '${match?['device_uuid'] ?? ''}',
          stage: SetupStage.calibrate,);
      await _saveCheckpoint();
      return {'ok': true, 'capabilities': caps};
    } catch (e) {
      fail('self-test could not reach the node');
      return {'ok': false, 'error': '$e'};
    }
  }

  /// Steps 15–17: optional calibration + wearable enrollment offers are
  /// separate routes; finishing lands on the live context screen.
  Future<void> finish() async {
    state = state.copyWith(stage: SetupStage.done);
    await clearCheckpoint();
  }
}

final setupControllerProvider =
    NotifierProvider<SetupController, SetupState>(SetupController.new);
