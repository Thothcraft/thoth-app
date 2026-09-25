import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brain API client — bearer-token auth for mobile.
///
/// Flutter uses a stored access token (obtained via login or OAuth
/// sign-in); browsers use the HttpOnly session cookie instead.
class BrainClient {
  BrainClient._();
  static final BrainClient instance = BrainClient._();

  static const String defaultBaseUrl = AppConstants.brainApiUrl;
  static const String _tokenKey = 'brain_access_token';
  static const String _baseUrlKey = 'brain_base_url';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ),);

  String? _token;
  String _baseUrl = defaultBaseUrl;

  String get baseUrl => _baseUrl;
  bool get hasToken => _token != null && _token!.isNotEmpty;
  /// Bearer token for streaming endpoints (SSE headers).
  String? get token => _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  Options get _opts => Options(headers: {
        'Accept': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $_token',
      },);

  String _api(String path) => '$_baseUrl/api$path';
  String _v1(String path) => '$_baseUrl/v1$path';

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, dynamic>? params,}) async {
    final res = await _dio.get(_api(path),
        queryParameters: params, options: _opts,);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// GET a versioned v1 endpoint.
  Future<Map<String, dynamic>> getV1(String path,
      {Map<String, dynamic>? params,}) async {
    final res = await _dio.get(_v1(path),
        queryParameters: params, options: _opts,);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// POST a versioned v1 endpoint.
  Future<Map<String, dynamic>> postV1(String path,
      {Map<String, dynamic>? body,}) async {
    final res = await _dio.post(_v1(path),
        data: body ?? {}, options: _opts,);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Recent typed predictions for a device (v1 ``PredictionListV1``).
  Future<List<Map<String, dynamic>>> getDevicePredictions(String deviceId,
      {int limit = 50,}) async {
    final res = await getV1('/devices/$deviceId/predictions',
        params: {'limit': limit},);
    final list = (res['predictions'] ?? const []) as List;
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Cursor-paged real samples for one sensor (v1 ``StreamPageV1``).
  /// Returns ``{samples: [...], cursor: String?, state: String}``.
  Future<Map<String, dynamic>> streamSensor(String deviceId, String sensorId,
      {String? cursor,}) async {
    return getV1('/devices/$deviceId/streams/$sensorId',
        params: {if (cursor != null) 'cursor': cursor},);
  }

  /// List a device's captures (v1 ``CaptureListV1``).
  Future<List<Map<String, dynamic>>> getDeviceCaptures(String deviceId) async {
    final res = await getV1('/devices/$deviceId/captures');
    final list = (res['captures'] ?? const []) as List;
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Start a capture; returns the durable CaptureV1 (state ``requested``).
  Future<Map<String, dynamic>> startCapture(String deviceId,
      {List<String>? sensors,}) async {
    return postV1('/devices/$deviceId/captures',
        body: {'sensors': sensors ?? []},);
  }

  /// Stop a capture by its durable id; returns ``{id, device_id, state}``.
  Future<Map<String, dynamic>> stopCapture(String captureId) async {
    return postV1('/captures/$captureId/stop');
  }

  Future<Map<String, dynamic>> postJson(String path,
      {Map<String, dynamic>? body,}) async {
    final res = await _dio.post(_api(path),
        data: body ?? {}, options: _opts,);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> postMultipart(
      String path, String field, String filename, List<int> bytes,) async {
    final form = FormData.fromMap({
      field: MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(_api(path), data: form, options: _opts);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> delete(String path) async {
    await _dio.delete(_api(path), options: _opts);
  }

  /// Login with username/password; stores the returned token.
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('$_baseUrl/api/token',
        data: {'username': username, 'password': password},
        options: Options(headers: {'Accept': 'application/json'}),);
    final data = Map<String, dynamic>.from(res.data as Map);
    final token = data['access_token'] as String?;
    if (token == null) {
      throw DioException(
          requestOptions: res.requestOptions,
          error: 'No access_token in response',);
    }
    await setToken(token);
    return data;
  }

  Future<void> logout() async {
    try {
      await postJson('/logout');
    } catch (_) {/* best-effort */}
    await setToken(null);
  }
}
