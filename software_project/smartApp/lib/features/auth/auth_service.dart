import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';

/// The authenticated user, as returned by the backend.
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.role});

  final int id;
  final String email;
  final String role; // 'admin' | 'teacher' | 'student'

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        email: json['email'] as String,
        role: json['role'] as String,
      );
}

/// Holds auth state for the whole app. A single instance lives in [app_di].
///
/// [user] is a [ValueListenable]; screens and route guards rebuild when it
/// changes (login / logout / session restore).
class AuthService {
  AuthService(this._api);

  final ApiClient _api;
  final ValueNotifier<AuthUser?> user = ValueNotifier<AuthUser?>(null);

  bool get isAuthenticated => user.value != null;

  /// Verifies credentials with the backend. Throws on failure (wrong password,
  /// server unreachable, …) — the message is safe to show to the user.
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/api/auth/login', {
      'email': email,
      'password': password,
    });

    final token = res['token'] as String?;
    final userJson = res['user'];
    if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
      throw Exception('Unexpected response from server');
    }

    await _api.saveToken(token);
    final loggedIn = AuthUser.fromJson(userJson);
    user.value = loggedIn;
    return loggedIn;
  }

  /// Creates a new account (student or teacher) and logs it in.
  /// Throws a user-safe message on failure (email taken, weak password, …).
  Future<AuthUser> register({
    required String email,
    required String password,
    required String role,
  }) async {
    final res = await _api.post('/api/auth/register', {
      'email': email,
      'password': password,
      'role': role,
    });

    final token = res['token'] as String?;
    final userJson = res['user'];
    if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
      throw Exception('Unexpected response from server');
    }

    await _api.saveToken(token);
    final created = AuthUser.fromJson(userJson);
    user.value = created;
    return created;
  }

  /// Called on app start: if a stored token is still valid, restore the session.
  Future<void> restoreSession() async {
    try {
      final res = await _api.getAuthed('/api/auth/me');
      final userJson = res['user'];
      if (userJson is Map<String, dynamic>) {
        user.value = AuthUser.fromJson(userJson);
        return;
      }
    } catch (_) {
      // No token, expired token, or server down — treat as logged out.
    }
    await _api.logout();
    user.value = null;
  }

  Future<void> logout() async {
    await _api.logout();
    user.value = null;
  }
}
