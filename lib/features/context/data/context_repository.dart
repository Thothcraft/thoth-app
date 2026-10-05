import '../../../core/api/brain_client.dart';
import '../domain/models.dart';

/// Typed repository over Brain's ``/v1/context/*`` and ``/api/spaces*``
/// endpoints (Part 10 — no scattered HTTP in widgets).
class ContextRepository {
  ContextRepository([BrainClient? client]) : _brain = client ?? BrainClient.instance;
  final BrainClient _brain;

  // ── entities ────────────────────────────────────────────────────────────

  Future<List<ContextEntity>> entities({String? kind}) async {
    final res = await _brain.getV1('/context/entities',
        params: {if (kind != null) 'kind': kind});
    return (res['entities'] as List? ?? const [])
        .map((e) => ContextEntity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ContextEntity> upsertEntity(ContextEntity entity) async {
    final res = await _brain.postV1('/context/entities', body: entity.toJson());
    return ContextEntity.fromJson(res);
  }

  Future<void> deleteEntity(String entityKey) async {
    await _brain.deleteV1('/context/entities/$entityKey');
  }

  // ── relationships ───────────────────────────────────────────────────────

  Future<List<ContextRelationship>> relationships(
      {String? subject, String? predicate, bool activeOnly = false}) async {
    final res = await _brain.getV1('/context/relationships', params: {
      if (subject != null) 'subject': subject,
      if (predicate != null) 'predicate': predicate,
      if (activeOnly) 'active_only': true,
    });
    return (res['relationships'] as List? ?? const [])
        .map((e) => ContextRelationship.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ContextRelationship> createRelationship({
    required String subject,
    required String predicate,
    required String object,
    double confidence = 1.0,
    String source = 'thoth-app',
    bool allowUnresolved = false,
    Map<String, dynamic> provenance = const {},
  }) async {
    final res = await _brain.postV1('/context/relationships', body: {
      'subject': subject,
      'predicate': predicate,
      'object': object,
      'confidence': confidence,
      'source': source,
      'provenance': provenance,
      'allow_unresolved': allowUnresolved,
    });
    return ContextRelationship.fromJson(res);
  }

  Future<void> endRelationship(int relId) async {
    await _brain.deleteV1('/context/relationships/$relId');
  }

  // ── evidence ────────────────────────────────────────────────────────────

  /// Ingest one or more evidence items. ``external_id`` provides
  /// idempotency so batched retries never duplicate.
  Future<List<ContextEvidence>> postEvidence(
      List<Map<String, dynamic>> items) async {
    final res = await _brain.postV1('/context/evidence',
        body: items.length == 1 ? items.first : {'items': items});
    return (res['evidence'] as List? ?? const [])
        .map((e) => ContextEvidence.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ContextEvidence>> evidence(
      {String? key, String? sourceId, double? since, int limit = 200}) async {
    final res = await _brain.getV1('/context/evidence', params: {
      if (key != null) 'key': key,
      if (sourceId != null) 'source_id': sourceId,
      if (since != null) 'since': since,
      'limit': limit,
    });
    return (res['evidence'] as List? ?? const [])
        .map((e) => ContextEvidence.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── state + events ──────────────────────────────────────────────────────

  Future<List<ContextState>> states(
      {String? key, String? entityId, bool activeOnly = false}) async {
    final res = await _brain.getV1('/context/state', params: {
      if (key != null) 'key': key,
      if (entityId != null) 'entity_id': entityId,
      if (activeOnly) 'active_only': true,
    });
    return (res['states'] as List? ?? const [])
        .map((e) => ContextState.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Upsert a context state — e.g. `location.zone` for the person on a
  /// geofence transition.
  Future<ContextState> postState({
    required String stateKey,
    required String entityId,
    required Map<String, dynamic> value,
    String? estimator,
    double? confidence,
    double? since,
    String? transition,
  }) async {
    final res = await _brain.postV1('/context/state', body: {
      'key': stateKey,
      'entity_id': entityId,
      'value': value,
      if (since != null) 'since': since,
      if (transition != null) 'transition': transition,
      if (estimator != null) 'estimator': estimator,
      if (confidence != null) 'confidence': confidence,
    });
    return ContextState.fromJson(
        Map<String, dynamic>.from(res['state'] ?? res));
  }

  Future<List<ContextEvent>> events(
      {String? key, double? since, int limit = 200}) async {
    final res = await _brain.getV1('/context/events', params: {
      if (key != null) 'key': key,
      if (since != null) 'since': since,
      'limit': limit,
    });
    return (res['events'] as List? ?? const [])
        .map((e) => ContextEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Current context: live entities + valid relationships + non-expired
  /// states in one call — the mobile context home source.
  Future<ContextSnapshot> snapshot() async {
    final res = await _brain.getV1('/context/snapshot');
    return ContextSnapshot(
      entities: (res['entities'] as List? ?? const [])
          .map((e) => ContextEntity.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      relationships: (res['relationships'] as List? ?? const [])
          .map((e) =>
              ContextRelationship.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      states: (res['states'] as List? ?? const [])
          .map((e) => ContextState.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      generatedAt: (res['generated_at'] as num?)?.toDouble(),
    );
  }

  // ── spaces (spatial API) ────────────────────────────────────────────────

  Future<List<SpaceInfo>> spaces() async {
    final res = await _brain.getJson('/spaces');
    return (res['spaces'] as List? ?? const [])
        .map((e) => SpaceInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Live per-space occupancy + zone state.
  Future<Map<int, SpaceInfo>> spacesState() async {
    final res = await _brain.getJson('/spaces/state');
    final out = <int, SpaceInfo>{};
    for (final s in (res['spaces'] as List? ?? const [])) {
      final info = SpaceInfo.fromJson(Map<String, dynamic>.from(s));
      out[info.id] = info;
    }
    return out;
  }

  Future<SpaceInfo> createSpace(String name,
      {int? parentId, double? widthM, double? heightM}) async {
    final res = await _brain.postJson('/spaces', body: {
      'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (widthM != null) 'width_m': widthM,
      if (heightM != null) 'height_m': heightM,
    });
    return SpaceInfo.fromJson(
        Map<String, dynamic>.from(res['space'] as Map? ?? res));
  }

  Future<void> assignDeviceToSpace(String deviceUuid, int spaceId,
      {double x = 0.0, double y = 0.0, double rotationDeg = 0.0}) async {
    await _brain.putJson('/spaces/devices/$deviceUuid/placement', body: {
      'space_id': spaceId,
      'x': x,
      'y': y,
      'rotation_deg': rotationDeg,
    });
  }

  // ── device pairing (existing contract) ──────────────────────────────────

  /// Claim a node by its 8-char pairing code.
  Future<Map<String, dynamic>> claimDevice(String code) =>
      _brain.postJson('/device/pairing/claim', body: {'code': code});
}
