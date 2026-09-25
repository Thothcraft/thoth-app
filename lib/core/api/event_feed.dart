import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../notifications/notification_service.dart';
import 'brain_client.dart';

/// Live Brain event feed — SSE subscription to ``/v1/events/stream``.
///
/// Replaces polling: events arrive the moment Brain persists them.
/// Reconnects with ``Last-Event-ID`` so a dropped stream replays misses.
/// `notification` events surface as system notifications; all events
/// are forwarded to [onEvent] for in-app UI.
class EventFeed {
  EventFeed._();
  static final EventFeed instance = EventFeed._();

  final Dio _dio = Dio(BaseOptions(
    // No receive timeout — the stream is long-lived; heartbeats keep it up.
    connectTimeout: const Duration(seconds: 10),
  ));

  CancelToken? _cancel;
  String? _lastEventId;
  bool _running = false;

  /// Latest event batch — UI snackbars/listeners consume this.
  final StreamController<List<Map<String, dynamic>>> _events =
      StreamController.broadcast();

  /// Last-Event-ID cursor (survives reconnects; mirrors Brain replay).
  Stream<List<Map<String, dynamic>>> get events => _events.stream;

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_loop());
  }

  void stop() {
    _running = false;
    _cancel?.cancel();
    _cancel = null;
  }

  Future<void> _loop() async {
    var backoff = const Duration(seconds: 1);
    while (_running) {
      try {
        await _consume();
        backoff = const Duration(seconds: 1);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        if (!_running) return;
        await Future<void>.delayed(backoff);
        backoff = backoff * 2 > const Duration(seconds: 30)
            ? const Duration(seconds: 30)
            : backoff * 2;
      } catch (_) {
        if (!_running) return;
        await Future<void>.delayed(backoff);
      }
    }
  }

  Future<void> _consume() async {
    final client = BrainClient.instance;
    if (!client.hasToken) throw StateError('no token');
    final res = await _dio.get<ResponseBody>(
      '${client.baseUrl}/v1/events/stream',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer ${client.token}',
          'Cache-Control': 'no-cache',
          if (_lastEventId != null) 'Last-Event-ID': _lastEventId,
        },
      ),
    );
    final stream = res.data?.stream;
    if (stream == null) return;

    var event = <String, String>{};          // id / event / data fields
    var buffer = '';
    await for (final chunk in stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      var nl = buffer.indexOf('\n');
      while (nl >= 0) {
        final line = buffer.substring(0, nl);
        buffer = buffer.substring(nl + 1);
        nl = buffer.indexOf('\n');
        final trimmed = line.trimRight();
        if (trimmed.isEmpty) {
          if (event.isNotEmpty) {
            _dispatch(event);
            event = {};
          }
          continue;
        }
        if (trimmed.startsWith(':')) continue;      // heartbeat comment
        final colon = trimmed.indexOf(':');
        if (colon < 0) continue;
        final field = trimmed.substring(0, colon);
        final value = trimmed.substring(colon + 1).trimLeft();
        event[field] = value;
      }
      if (!_running) return;
    }
  }

  void _dispatch(Map<String, String> frame) {
    final id = frame['id'];
    if (id != null) _lastEventId = id;
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(json.decode(frame['data'] ?? '{}'));
    } catch (_) {
      data = {'raw': frame['data']};
    }
    data['id'] ??= id;
    data['kind'] ??= frame['event'];

    _events.add([data]);

    if (data['kind'] == 'notification') {
      final payload = Map<String, dynamic>.from(
          (data['data'] as Map?) ?? const {});
      NotificationService.instance.show(
        (payload['title'] as String?) ?? 'Thoth',
        (payload['body'] as String?) ?? '',
        severity: (payload['severity'] as String?) ?? 'info',
      );
    }
  }
}
