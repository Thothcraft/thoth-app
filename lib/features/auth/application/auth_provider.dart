import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/brain_client.dart';

class AuthState {
  const AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.username,
    this.plan = 'free',
    this.entitlements = const {},
    this.error,
  });

  final bool isLoading;
  final bool isAuthenticated;
  final String? username;
  final String plan;
  final Map<String, dynamic> entitlements;
  final String? error;

  bool hasEntitlement(String key) => entitlements[key] == true;

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? username,
    String? plan,
    Map<String, dynamic>? entitlements,
    String? error,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        username: username ?? this.username,
        plan: plan ?? this.plan,
        entitlements: entitlements ?? this.entitlements,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _restore();
  }

  final _client = BrainClient.instance;

  Future<void> _restore() async {
    await _client.init();
    if (!_client.hasToken) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final profile = await _client.getJson('/profile');
      await _loadEntitlements();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        username: profile['username'] as String?,
        plan: (profile['plan'] as String?) ?? 'free',
      );
    } catch (_) {
      await _client.setToken(null);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadEntitlements() async {
    try {
      final data = await _client.getJson('/account/entitlements');
      state = state.copyWith(
        plan: (data['plan'] as String?) ?? state.plan,
        entitlements:
            Map<String, dynamic>.from(data['entitlements'] as Map? ?? {}),
      );
    } catch (_) {/* best-effort */}
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _client.login(username.trim(), password);
      await _loadEntitlements();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        username: data['username'] as String? ?? username.trim(),
        plan: (data['plan'] as String?) ?? 'free',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Invalid username or password',);
      return false;
    }
  }

  Future<void> logout() async {
    await _client.logout();
    state = const AuthState(isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
