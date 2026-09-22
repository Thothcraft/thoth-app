import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brain API client — bearer-token auth for mobile.
///
/// Flutter uses a stored access token (obtained via login or OAuth
/// sign-in); browsers use the HttpOnly session cookie instead.
class BrainClient {
  BrainClient._();
  static final BrainClient instance = BrainClient._();

  static const String defaultBaseUrl = 'https://api.thothcraft.com';
  static const String _tokenKey = 'brain_access_token';
  static const String _baseUrlKey = 'brain_base_url';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  String? _token;
  String _baseUrl = defaultBaseUrl;

  String get baseUrl => _baseUrl;
  bool get hasToken => _token != null && _token!.isNotEmpty;

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
      });

  String _api(String path) => '$_baseUrl/api$path';

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, dynamic>? params}) async {
    final res = await _dio.get(_api(path),
        queryParameters: params, options: _opts);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> postJson(String path,
      {Map<String, dynamic>? body}) async {
    final res = await _dio.post(_api(path),
        data: body ?? {}, options: _opts);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> postMultipart(
      String path, String field, String filename, List<int> bytes) async {
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
        options: Options(headers: {'Accept': 'application/json'}));
    final data = Map<String, dynamic>.from(res.data as Map);
    final token = data['access_token'] as String?;
    if (token == null) {
      throw DioException(
          requestOptions: res.requestOptions,
          error: 'No access_token in response');
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
