import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thothcraft/features/setup/application/setup_controller.dart';
import 'package:thothcraft/features/setup/data/provisioning_transport.dart';
import 'package:thothcraft/features/setup/domain/setup_contract.dart';

/// Fake commissioning transport — exercises the state machine without BLE.
class FakeTransport implements ProvisioningTransport {
  FakeTransport({this.identityDoc = const {
    'device_id': 'node-1',
    'model': 'pi5',
    'key_hash': '',
  }, this.verify = true, this.failSend = false,});

  final Map<String, dynamic> identityDoc;
  final bool verify;
  final bool failSend;
  bool sent = false;

  @override
  Future<Map<String, dynamic>> readIdentity() async => identityDoc;

  @override
  Future<bool> verifySetupKey(SetupIdentity identity) async => verify;

  @override
  Future<List<String>> scanWifi() async => const ['home'];

  @override
  Future<void> sendCredentials(String ssid, String psk) async {
    if (failSend) throw StateError('write rejected');
    sent = true;
  }

  @override
  Stream<ProvisionStatus> status() => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('SetupIdentity parsing', () {
    test('parses thoth://setup URI', () {
      final id = SetupIdentity.tryParse('thoth://setup?id=n1&k=secret');
      expect(id, isNotNull);
      expect(id!.nodeId, 'n1');
      expect(id.setupKey, 'secret');
    });
    test('parses JSON payload', () {
      final id = SetupIdentity.tryParse('{"id":"n2","k":"abc","model":"pi"}');
      expect(id!.nodeId, 'n2');
      expect(id.model, 'pi');
    });
    test('parses compact id:key', () {
      final id = SetupIdentity.tryParse('n3:xyz');
      expect(id!.nodeId, 'n3');
    });
    test('rejects garbage', () {
      expect(SetupIdentity.tryParse(''), isNull);
      expect(SetupIdentity.tryParse('{}'), isNull);
    });
  });

  group('candidate matching', () {
    test('matches truncated sha256 of the setup key', () {
      final id = const SetupIdentity(nodeId: 'n', setupKey: 's3cret');
      expect(matchCandidate(id, id.keyHash), MatchResult.matched);
      expect(matchCandidate(id, 'deadbeef'), MatchResult.noMatch);
      expect(matchCandidate(id, null), MatchResult.noAdvertisedHash);
    });
  });

  group('SetupController', () {
    (ProviderContainer, SetupController) make(
        {FakeTransport? transport,}) {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctl = c.read(setupControllerProvider.notifier);
      ctl.transportFactory = (_) => transport ?? FakeTransport();
      return (c, ctl);
    }

    test('advances verify → identity → wifi on a matching node', () async {
      final (_, ctl) = make();
      await ctl.acceptIdentity(
          const SetupIdentity(nodeId: 'n1', setupKey: 'k'),);
      expect(ctl.state.stage, SetupStage.discover);
      await ctl.selectCandidate(const CommissionCandidate(
          id: 'AA:BB', name: 'thoth-1', rssi: -50,),);
      expect(ctl.state.stage, SetupStage.wifiDetails);
      expect(ctl.state.deviceUuid, 'node-1');
      expect(ctl.state.deviceModel, 'pi5');
    });

    test('fails verification when the node does not match the code',
        () async {
      final (_, ctl) = make(transport: FakeTransport(verify: false));
      await ctl.acceptIdentity(
          const SetupIdentity(nodeId: 'n1', setupKey: 'k'),);
      await ctl.selectCandidate(const CommissionCandidate(
          id: 'AA:BB', name: 'thoth-1', rssi: -50,),);
      expect(ctl.state.provisionPhase, ProvisionPhase.failed);
      expect(ctl.state.error, isNotNull);
    });

    test('credential send enters joiningWifi; failure surfaces error',
        () async {
      final t = FakeTransport();
      final (_, ctl) = make(transport: t);
      await ctl.acceptIdentity(
          const SetupIdentity(nodeId: 'n1', setupKey: 'k'),);
      await ctl.selectCandidate(const CommissionCandidate(
          id: 'AA:BB', name: 'thoth-1', rssi: -50,),);
      await ctl.provisionWifi('ssid', 'psk');
      expect(t.sent, isTrue);
      expect(ctl.state.provisionPhase, ProvisionPhase.joiningWifi);
    });
  });
}
