/// Typed client model for the Brain v1 context API
/// (``/v1/context/{entities,relationships,evidence,state,events,snapshot}``).
///
/// Predictions are evidence, never truth; states are derived statements
/// attributed to an ``estimator``. These types keep that distinction
/// explicit in the UI layer.
library;

import 'dart:convert';

/// Canonical context keys the platform emits. The backend accepts any
/// versioned key — this list exists so the UI can group known keys, not to
/// whitelist them.
abstract final class ContextKeys {
  static const occupancy = 'occupancy.v1';
  static const presence = 'presence.v1';
  static const locationGeo = 'location.geo.v1';
  static const locationSpace = 'location.space.v1';
  static const locationZone = 'location.zone.v1';
  static const activityPosture = 'activity.posture.v1';
  static const activityMotion = 'activity.motion.v1';
  static const activitySleep = 'activity.sleep.v1';
  static const activityFall = 'activity.fall.v1';

  /// Mobile-produced observation evidence keys (they are evidence, never
  /// asserted context state — an estimator produces the state).
  static const bleProximityEvidence = 'ble.proximity.v1';
  static const geoEvidence = 'location.geo.v1';
  static const phoneMotionEvidence = 'activity.motion.v1';

  /// Family prefix for grouping in filters (``activity``, ``location``…).
  static String family(String key) => key.split('.').first;
}

class ContextEntity {
  const ContextEntity({
    required this.id,
    required this.kind,
    this.name,
    this.attributes = const {},
    this.createdAt,
  });

  final String id; // e.g. "person:gad", "space:office", "wearable:watch01"
  final String kind; // person | device | wearable | space | object | …
  final String? name;
  final Map<String, dynamic> attributes;
  final double? createdAt;

  factory ContextEntity.fromJson(Map<String, dynamic> j) => ContextEntity(
        id: '${j['id'] ?? j['entity_key'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        name: j['name']?.toString(),
        attributes: _decodeMap(j['attributes']),
        createdAt: _num(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        if (name != null) 'name': name,
        'attributes': attributes,
      };
}

class ContextRelationship {
  const ContextRelationship({
    required this.id,
    required this.subject,
    required this.predicate,
    required this.object,
    this.validFrom,
    this.validUntil,
    this.confidence = 1.0,
    this.source = '',
    this.provenance = const {},
  });

  final int id;
  final String subject;
  final String predicate; // e.g. "wears", "observes", "located_in", "member_of"
  final String object;
  final double? validFrom;
  final double? validUntil;
  final double confidence;
  final String source;
  final Map<String, dynamic> provenance;

  bool get active =>
      validUntil == null || validUntil! > DateTime.now().millisecondsSinceEpoch / 1000;

  factory ContextRelationship.fromJson(Map<String, dynamic> j) =>
      ContextRelationship(
        id: _int(j['id']),
        subject: '${j['subject'] ?? ''}',
        predicate: '${j['predicate'] ?? ''}',
        object: '${j['object'] ?? ''}',
        validFrom: _num(j['valid_from']),
        validUntil: _num(j['valid_until']),
        confidence: _num(j['confidence']) ?? 1.0,
        source: '${j['source'] ?? ''}',
        provenance: _decodeMap(j['provenance']),
      );

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'predicate': predicate,
        'object': object,
        if (validFrom != null) 'valid_from': validFrom,
        if (validUntil != null) 'valid_until': validUntil,
        'confidence': confidence,
        'source': source,
        'provenance': provenance,
      };
}

/// Evidence wraps an observation/prediction with provenance. ``value`` is
/// the raw payload (e.g. an RSSI reading) — it is never a distance unless
/// a ranging estimator produced one.
class ContextEvidence {
  const ContextEvidence({
    required this.id,
    required this.key,
    this.value,
    this.timestamp,
    this.sourceId,
    this.deviceId,
    this.predictionId,
    this.observationId,
    this.modelId,
    this.modelVersion,
    this.confidence,
    this.provenance = const {},
  });

  final String id;
  final String key;
  final dynamic value;
  final double? timestamp;
  final String? sourceId;
  final String? deviceId;
  final String? predictionId;
  final String? observationId;
  final String? modelId;
  final String? modelVersion;
  final double? confidence;
  final Map<String, dynamic> provenance;

  factory ContextEvidence.fromJson(Map<String, dynamic> j) => ContextEvidence(
        id: '${j['id'] ?? ''}',
        key: '${j['key'] ?? j['evidence_key'] ?? ''}',
        value: j['value'] is String ? _tryJson(j['value']) : j['value'],
        timestamp: _num(j['timestamp']),
        sourceId: j['source_id']?.toString(),
        deviceId: j['device_id']?.toString(),
        predictionId: j['prediction_id']?.toString(),
        observationId: j['observation_id']?.toString(),
        modelId: j['model_id']?.toString(),
        modelVersion: j['model_version']?.toString(),
        confidence: _num(j['confidence']),
        provenance: _decodeMap(j['provenance']),
      );
}

/// Derived semantic state with estimator attribution and evidence links.
class ContextState {
  const ContextState({
    required this.id,
    required this.key,
    this.value,
    this.entityId = '',
    this.confidence = 1.0,
    this.since,
    this.validUntil,
    this.evidenceIds = const [],
    this.estimator = '',
  });

  final int id;
  final String key; // e.g. "location.space.v1"
  final dynamic value;
  final String entityId;
  final double confidence;
  final double? since;
  final double? validUntil;
  final List<String> evidenceIds;
  final String estimator;

  bool get active =>
      validUntil == null || validUntil! > DateTime.now().millisecondsSinceEpoch / 1000;

  /// Age in seconds since the state last transitioned.
  double get ageSeconds => since == null
      ? 0
      : DateTime.now().millisecondsSinceEpoch / 1000 - since!;

  factory ContextState.fromJson(Map<String, dynamic> j) => ContextState(
        id: _int(j['id']),
        key: '${j['key'] ?? j['state_key'] ?? ''}',
        value: j['value'] is String ? _tryJson(j['value']) : j['value'],
        entityId: '${j['entity_id'] ?? ''}',
        confidence: _num(j['confidence']) ?? 1.0,
        since: _num(j['since']),
        validUntil: _num(j['valid_until']),
        evidenceIds: _decodeList(j['evidence_ids'])
            .map((e) => '$e')
            .toList(growable: false),
        estimator: '${j['estimator'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'entity_id': entityId,
        'confidence': confidence,
        if (since != null) 'since': since,
        if (validUntil != null) 'valid_until': validUntil,
        'evidence_ids': evidenceIds,
        'estimator': estimator,
      };
}

/// Discrete transition emitted when a state changes.
class ContextEvent {
  const ContextEvent({
    required this.id,
    required this.key,
    required this.type,
    this.entityId,
    this.value,
    this.previousValue,
    this.confidence,
    this.timestamp,
    this.provenance = const {},
  });

  final int id;
  final String key;
  final String type; // entered | exited | changed
  final String? entityId;
  final dynamic value;
  final dynamic previousValue;
  final double? confidence;
  final double? timestamp;
  final Map<String, dynamic> provenance;

  factory ContextEvent.fromJson(Map<String, dynamic> j) => ContextEvent(
        id: _int(j['id']),
        key: '${j['key'] ?? j['event_key'] ?? ''}',
        type: '${j['type'] ?? j['event_type'] ?? ''}',
        entityId: j['entity_id']?.toString(),
        value: j['value'] is String ? _tryJson(j['value']) : j['value'],
        previousValue: j['previous_value'] is String
            ? _tryJson(j['previous_value'])
            : j['previous_value'],
        confidence: _num(j['confidence']),
        timestamp: _num(j['timestamp']),
        provenance: _decodeMap(j['provenance']),
      );
}

class ContextSnapshot {
  const ContextSnapshot({
    this.entities = const [],
    this.relationships = const [],
    this.states = const [],
    this.generatedAt,
  });
  final List<ContextEntity> entities;
  final List<ContextRelationship> relationships;
  final List<ContextState> states;
  final double? generatedAt;
}

/// Space + live occupancy as returned by the spatial API
/// (``/api/spaces`` + ``/api/spaces/state``).
class SpaceInfo {
  const SpaceInfo({
    required this.id,
    required this.name,
    this.parentId,
    this.widthM,
    this.heightM,
    this.zones = const [],
    this.placements = const [],
    this.occupied = false,
    this.peopleCount = 0,
    this.occupancyConfidence = 0.0,
    this.zoneStates = const {},
    this.lastActivity,
  });

  final int id;
  final String name;
  final int? parentId;
  final double? widthM;
  final double? heightM;
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> placements;
  final bool occupied;
  final int peopleCount;
  final double occupancyConfidence;
  final Map<String, Map<String, dynamic>> zoneStates;
  final String? lastActivity;

  factory SpaceInfo.fromJson(Map<String, dynamic> j) => SpaceInfo(
        id: _int(j['id'] ?? j['space_id']),
        name: '${j['name'] ?? 'space'}',
        parentId: j['parent_id'] == null ? null : _int(j['parent_id']),
        widthM: _num(j['width_m']),
        heightM: _num(j['height_m']),
        zones: (j['zones'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        placements: (j['placements'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        occupied: j['occupied'] == true,
        peopleCount: _int(j['people_count']),
        occupancyConfidence: _num(j['confidence']) ?? 0.0,
        zoneStates: (j['zone_states'] is Map ? j['zone_states'] : j['zones_state'])
                is Map
            ? Map<String, Map<String, dynamic>>.from(
                ((j['zone_states'] ?? j['zones_state']) as Map).map((k, v) =>
                    MapEntry('$k', Map<String, dynamic>.from(v as Map))))
            : const {},
        lastActivity: j['last_activity']?.toString(),
      );
}

// ── helpers ────────────────────────────────────────────────────────────────

double? _num(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

int _int(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

dynamic _tryJson(String? s) {
  if (s == null) return null;
  try {
    return json.decode(s);
  } catch (_) {
    return s;
  }
}

Map<String, dynamic> _decodeMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String && v.isNotEmpty) {
    final d = _tryJson(v);
    if (d is Map) return Map<String, dynamic>.from(d);
  }
  return const {};
}

List<dynamic> _decodeList(dynamic v) {
  if (v is List) return v;
  if (v is String && v.isNotEmpty) {
    final d = _tryJson(v);
    if (d is List) return d;
  }
  return const [];
}
