import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Latest published Thoth watch firmware, fetched on demand from the
/// release feed — the ~400 kB DFU zip is never bundled in the app.
///
/// The release ships ``thothiot-latest.json`` next to ``thothiot-*.zip``:
/// ``{tag, fw_version, asset, sha256}`` (fw_version matches the string
/// the watch reports over DIS 0x2A26, e.g. ``1.16.99``).
class WatchFirmwareRelease {
  const WatchFirmwareRelease({
    required this.tag,
    required this.fwVersion,
    required this.downloadUrl,
    this.sha256,
  });

  final String tag;

  /// Firmware version the watch reports (``1.16.99``), or empty when the
  /// release predates the sidecar manifest — treated as "unknown".
  final String fwVersion;
  final String downloadUrl;
  final String? sha256;
}

class WatchFirmwareFeed {
  WatchFirmwareFeed({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const _api =
      'https://api.github.com/repos/Thothcraft/thothNode/releases/latest';

  /// Null when the feed is unreachable or carries no watch asset.
  Future<WatchFirmwareRelease?> latest() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_api,
          options: Options(
              headers: {'Accept': 'application/vnd.github+json'},
              receiveTimeout: const Duration(seconds: 15)),);
      final assets = (res.data?['assets'] as List?) ?? const [];
      Map<String, dynamic>? manifest;
      Map<String, dynamic>? zip;
      for (final a in assets.whereType<Map<String, dynamic>>()) {
        final name = a['name'] as String? ?? '';
        if (name == 'thothiot-latest.json') manifest = a;
        if (name.startsWith('thothiot-') && name.endsWith('.zip')) zip = a;
      }
      if (zip == null) return null;
      final zipUrl = zip['browser_download_url'] as String?;
      if (zipUrl == null) return null;
      var fw = '';
      String? sha;
      var tag = res.data?['tag_name'] as String? ?? '';
      if (manifest != null) {
        final mUrl = manifest['browser_download_url'] as String?;
        if (mUrl != null) {
          final m = await _dio.get<String>(mUrl,
              options: Options(responseType: ResponseType.plain,
                  receiveTimeout: const Duration(seconds: 10)),);
          final j = jsonDecode(m.data ?? '{}') as Map<String, dynamic>;
          fw = j['fw_version'] as String? ?? '';
          sha = j['sha256'] as String?;
          tag = j['tag'] as String? ?? tag;
        }
      }
      return WatchFirmwareRelease(
          tag: tag, fwVersion: fw, downloadUrl: zipUrl, sha256: sha,);
    } on Exception {
      return null; // offline / rate-limited — firmware check is best-effort
    }
  }

  /// Download the DFU zip to a temp file, verifying the published sha256
  /// when the manifest supplied one. Returns the zip path.
  Future<String> download(WatchFirmwareRelease rel,
      {void Function(int pct)? onProgress,}) async {
    final dest =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'thothiot-${rel.tag.replaceAll('/', '_')}.zip';
    await _dio.download(rel.downloadUrl, dest,
        options: Options(receiveTimeout: const Duration(minutes: 3)),
        onReceiveProgress: onProgress == null
            ? null
            : (got, total) {
                if (total > 0) onProgress((100 * got ~/ total));
              },);
    if (rel.sha256 != null) {
      final digest = sha256.convert(await File(dest).readAsBytes());
      if (digest.toString() != rel.sha256!.toLowerCase()) {
        await File(dest).delete();
        throw StateError('firmware checksum mismatch — download aborted');
      }
    }
    return dest;
  }
}

/// Compare dotted firmware versions; true when [candidate] > [installed].
/// Empty/malformed [installed] means stock or unknown — any published
/// release counts as newer. Empty [candidate] is never newer.
bool firmwareIsNewer(String installed, String candidate) {
  List<int> parts(String v) =>
      RegExp(r'\d+').allMatches(v).map((m) => int.parse(m[0]!)).toList();
  final a = parts(installed);
  final b = parts(candidate);
  if (b.isEmpty) return false;
  if (a.isEmpty) return true;
  for (var i = 0; i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    if (b[i] != x) return b[i] > x;
  }
  return false;
}
