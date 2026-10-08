import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/api/node_client.dart';

/// Edits the same authoritative room/v1 document as the portal.
class RoomSettingsScreen extends StatefulWidget {
  const RoomSettingsScreen({super.key, required this.deviceId});
  final String deviceId;
  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  final _form = GlobalKey<FormState>();
  Map<String, dynamic>? _doc;
  String? _error;
  bool _saving = false;
  String _roomId = '';
  final Map<String, TextEditingController> _fields = {};
  bool _surveyed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _active {
    final d = _doc!;
    if (_roomId == '${d['room_id'] ?? ''}') return d;
    return (d['rooms'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((r) => r['room_id'] == _roomId);
  }

  void _fill() {
    final d = _doc!, r = _active;
    final b = d['building'] as Map? ?? {}, a = b['anchor'] as Map? ?? {};
    final s = r['spatial'] as Map? ?? {}, dims = r['dims'] as Map? ?? {};
    final o = s['origin_enu_m'] as List?;
    final values = <String, dynamic>{
      'houseId': b['id'],
      'houseName': b['name'],
      'latitude': a['latitude'],
      'longitude': a['longitude'],
      'altitude': a['altitude_m'],
      'name': r['name'],
      'width': dims['w'],
      'depth': dims['d'],
      'height': dims['h'],
      'floor': s['floor'],
      'heading': s['heading_deg'],
      'east': o?[0],
      'north': o?[1],
      'up': o?[2],
    };
    final devices = (d['devices'] as List? ?? []).where((x) =>
        '${x['room_id'] ?? d['room_id'] ?? ''}' == _roomId ||
        (x['room_id'] == '' && _roomId == '${d['room_id'] ?? ''}'),);
    for (final dev in devices) {
      final id = dev['device_id'];
      final p = dev['pos'] as List?;
      values['$id.x'] = p?[0];
      values['$id.y'] = p?[1];
      values['$id.z'] = p?[2];
      values['$id.uncertainty'] = dev['position_uncertainty_m'];
    }
    for (final entry in values.entries) {
      (_fields[entry.key] ??= TextEditingController()).text =
          '${entry.value ?? ''}';
    }
    _surveyed = s['surveyed'] == true;
  }

  Future<void> _load() async {
    try {
      final d =
          await NodeClient.instance.getMap(widget.deviceId, '/api/v1/room');
      if (!mounted) return;
      setState(() {
        _doc = jsonDecode(jsonEncode(d));
        _roomId = '${d['room_id'] ?? ''}';
        _fill();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Cannot load layout: $e');
    }
  }

  double? _n(String key) => double.tryParse(_fields[key]?.text ?? '');
  String _t(String key) => _fields[key]?.text.trim() ?? '';

  Widget _field(String key, String label,
          {bool numeric = true,
          bool required = false,
          double? min,
          double? max,
          bool integer = false,}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _fields[key] ??= TextEditingController(),
          decoration: InputDecoration(labelText: label, hintText: 'Not set'),
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true, signed: true,)
              : TextInputType.text,
          validator: (text) {
            if ((text ?? '').trim().isEmpty) {
              return required ? 'Required' : null;
            }
            if (!numeric) return null;
            final v = double.tryParse(text!);
            if (v == null || !v.isFinite) return 'Enter a finite number';
            if (min != null && v < min || max != null && v > max) {
              return 'Outside the allowed range';
            }
            if (integer && v != v.roundToDouble()) {
              return 'Enter a whole floor number';
            }
            return null;
          },
        ),
      );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final latest =
          await NodeClient.instance.getMap(widget.deviceId, '/api/v1/room');
      if (latest['updated_at'] != _doc!['updated_at']) {
        throw StateError('Layout changed elsewhere. Reload before saving.');
      }
      final next = Map<String, dynamic>.from(jsonDecode(jsonEncode(_doc)));
      final r = _roomId == '${next['room_id'] ?? ''}'
          ? next
          : (next['rooms'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((r) => r['room_id'] == _roomId);
      next['building'] = {
        'id': _t('houseId'),
        'name': _t('houseName'),
        'anchor': {
          'latitude': _n('latitude'),
          'longitude': _n('longitude'),
          'altitude_m': _n('altitude'),
        },
      };
      r['name'] = _t('name');
      r['dims'] = {'w': _n('width'), 'd': _n('depth'), 'h': _n('height')};
      r['spatial'] = {
        'surveyed': _surveyed,
        'floor': _n('floor')?.toInt(),
        'heading_deg': _n('heading'),
        'origin_enu_m': ['east', 'north', 'up'].every((k) => _n(k) != null)
            ? [_n('east'), _n('north'), _n('up')]
            : null,
      };
      for (final dev in next['devices'] as List? ?? []) {
        final id = dev['device_id'];
        if (_fields.containsKey('$id.x')) {
          dev['pos'] = [_n('$id.x'), _n('$id.y'), _n('$id.z')];
          dev['position_uncertainty_m'] = _n('$id.uncertainty');
        }
      }
      final saved = await NodeClient.instance
          .put(widget.deviceId, '/api/v1/room', body: next);
      if (!mounted) return;
      if (saved is! Map || saved['format'] != 'room/v1') {
        throw StateError('Layout was not accepted');
      }
      setState(() {
        _doc = Map<String, dynamic>.from(saved);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('House and room layout saved')),);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('House and room layout'), actions: [
          IconButton(
              onPressed: _saving ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload saved layout',),
        ],),
        body: _doc == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(_error!),)
            : Form(
                key: _form,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text(
                      'Use the same house ID and origin on every node. Radio strength alone cannot determine floors or wall boundaries.',),
                  const SizedBox(height: 16),
                  _field('houseId', 'House ID',
                      numeric: false, required: _surveyed,),
                  _field('houseName', 'House name', numeric: false),
                  _field('latitude', 'Latitude',
                      min: -84.999999, max: 84.999999,),
                  _field('longitude', 'Longitude', min: -180, max: 180),
                  _field('altitude', 'House origin altitude (m, optional)'),
                  DropdownButtonFormField<String>(
                      initialValue: _roomId,
                      decoration: const InputDecoration(labelText: 'Room'),
                      items: [
                        _doc!,
                        ...(_doc!['rooms'] as List? ?? [])
                            .cast<Map<String, dynamic>>(),
                      ]
                          .map((r) => DropdownMenuItem(
                              value: '${r['room_id'] ?? ''}',
                              child: Text(
                                  '${r['name'] ?? r['room_id'] ?? 'Main room'}',),),)
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _roomId = v;
                            _fill();
                          });
                        }
                      },),
                  const SizedBox(height: 16),
                  _field('name', 'Room name', numeric: false),
                  for (final k in ['width', 'depth', 'height'])
                    _field(k, 'Room $k (m)', required: true, min: 0.01),
                  _field('floor', 'Floor (ground = 0)',
                      integer: true, required: _surveyed,),
                  _field('heading', 'Heading clockwise from north (degrees)',
                      required: _surveyed, min: 0, max: 359.999999,),
                  const Text(
                      'Room floor-centre offsets from the house origin. Heading points toward room −Z. Device coordinates use X across, Y up, Z back.',),
                  for (final k in ['east', 'north', 'up'])
                    _field(k, 'Room origin $k (m)', required: _surveyed),
                  SwitchListTile(
                      title: const Text('Measured room and anchor confirmed'),
                      value: _surveyed,
                      onChanged: (v) => setState(() => _surveyed = v),),
                  const Divider(),
                  const Text('Device anchors',
                      style: TextStyle(fontWeight: FontWeight.bold),),
                  for (final dev in _doc!['devices'] as List? ?? [])
                    if (_fields.containsKey('${dev['device_id']}.x')) ...[
                      Text('${dev['device_id']}'),
                      for (final axis in ['x', 'y', 'z'])
                        _field('${dev['device_id']}.$axis', 'Device $axis (m)',
                            required: true,),
                      _field('${dev['device_id']}.uncertainty',
                          'Placement uncertainty (m)',
                          min: 0,),
                    ],
                  TextButton.icon(
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Place this node in this room'),
                      onPressed: () {
                        setState(() {
                          final devices = (_doc!['devices'] ??= []) as List;
                          devices.removeWhere(
                              (d) => d['device_id'] == widget.deviceId,);
                          devices.add({
                            'device_id': widget.deviceId,
                            'room_id': _roomId,
                            'pos': [0.0, 0.0, 0.0],
                            'sensors': [],
                          });
                          _fill();
                        });
                      },),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,),),
                  FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save layout'),),
                ],),),
      );
}
