import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';

/// Thrown by [AuthRepository]; [key] is a string key from `S`.
class AuthFailure implements Exception {
  const AuthFailure(this.key);
  final String key;
  @override
  String toString() => 'AuthFailure($key)';
}

/// Wraps Supabase Auth (email + password, 6-digit email OTP).
class AuthRepository extends ChangeNotifier {
  AuthRepository() {
    if (AppConfig.isSupabaseConfigured) {
      _sub = _auth.onAuthStateChange.listen((_) => notifyListeners());
    }
  }

  static const _timeout = Duration(seconds: 15);
  StreamSubscription<AuthState>? _sub;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  bool get isConfigured => AppConfig.isSupabaseConfigured;

  User? get currentUser => isConfigured ? _auth.currentUser : null;

  /// Offline guest mode, only offered when no backend is configured
  /// (lets the AI screening be tested without accounts; history stays local).
  bool _guest = false;
  bool get isGuest => _guest;

  void continueAsGuest() {
    if (isConfigured) return;
    _guest = true;
    notifyListeners();
  }

  /// Logged in AND email confirmed (unverified users never reach Dashboard).
  bool get isLoggedIn {
    if (_guest) return true;
    final u = currentUser;
    return u != null && u.emailConfirmedAt != null;
  }

  String? get userId => _guest ? 'guest' : currentUser?.id;
  String get email => _guest ? '' : currentUser?.email ?? '';

  String get displayName {
    if (_guest) return 'Guest';
    final n = currentUser?.userMetadata?['full_name'];
    if (n is String && n.trim().isNotEmpty) return n.trim();
    final e = email;
    return e.contains('@') ? e.substring(0, e.indexOf('@')) : e;
  }

  Future<T> _call<T>(Future<T> Function() fn) async {
    if (!isConfigured) throw const AuthFailure('not_configured');
    try {
      return await fn().timeout(_timeout);
    } on TimeoutException {
      throw const AuthFailure('err_timeout');
    } on SocketException {
      throw const AuthFailure('err_no_internet');
    } on AuthRetryableFetchException {
      throw const AuthFailure('err_no_internet');
    } on AuthWeakPasswordException {
      throw const AuthFailure('err_weak_password');
    } on AuthException catch (e) {
      throw AuthFailure(mapError(e.code, e.message, e.statusCode));
    } on AuthFailure {
      rethrow;
    } catch (e) {
      debugPrint('Auth error: $e');
      final s = e.toString();
      if (s.contains('SocketException') || s.contains('ClientException')) {
        throw const AuthFailure('err_no_internet');
      }
      throw const AuthFailure('err_generic');
    }
  }

  /// Supabase error code/message → string key.
  @visibleForTesting
  static String mapError(String? code, String message, String? status) {
    final m = message.toLowerCase();
    if (code == 'invalid_credentials' || m.contains('invalid login credentials')) {
      return 'err_login';
    }
    if (code == 'email_not_confirmed' || m.contains('email not confirmed')) {
      return 'err_not_verified';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        m.contains('already registered')) {
      return 'err_email_in_use';
    }
    if (code == 'otp_expired' ||
        code == 'otp_disabled' ||
        m.contains('token has expired') ||
        m.contains('otp')) {
      return 'err_otp_invalid';
    }
    if (code == 'weak_password' || m.contains('password should be')) {
      return 'err_weak_password';
    }
    if (status == '429' || code == 'over_email_send_rate_limit' || m.contains('rate limit')) {
      return 'err_rate_limit';
    }
    return 'err_generic';
  }

  /// Supabase emails a 6-digit code (email template must include {{ .Token }}).
  Future<void> register(String name, String email, String password) =>
      _call(() async {
        final res = await _auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': name.trim()},
        );
        // With "prevent email enumeration", an existing user gets an empty identities list.
        final ids = res.user?.identities;
        if (res.user != null && ids != null && ids.isEmpty) {
          throw const AuthFailure('err_email_in_use');
        }
        // If email confirmation is disabled on the project a session is returned directly.
      });

  Future<void> verifySignupCode(String email, String code) => _call(() async {
        try {
          await _auth.verifyOTP(type: OtpType.email, email: email.trim(), token: code.trim());
        } on AuthException catch (_) {
          // Older GoTrue versions expect type "signup".
          await _auth.verifyOTP(type: OtpType.signup, email: email.trim(), token: code.trim());
        }
        notifyListeners();
      });

  Future<void> resendSignupCode(String email) =>
      _call(() => _auth.resend(type: OtpType.signup, email: email.trim()));

  Future<void> login(String email, String password) => _call(() async {
        final res = await _auth.signInWithPassword(email: email.trim(), password: password);
        if (res.user?.emailConfirmedAt == null) {
          await _auth.signOut();
          throw const AuthFailure('err_not_verified');
        }
        notifyListeners();
      });

  Future<void> sendPasswordReset(String email) =>
      _call(() => _auth.resetPasswordForEmail(email.trim()));

  /// Verify recovery code → session → set new password.
  Future<void> resetPassword(String email, String code, String newPassword) =>
      _call(() async {
        await _auth.verifyOTP(type: OtpType.recovery, email: email.trim(), token: code.trim());
        await _auth.updateUser(UserAttributes(password: newPassword));
        notifyListeners();
      });

  Future<void> updateName(String name) => _call(() async {
        await _auth.updateUser(UserAttributes(data: {'full_name': name.trim()}));
        notifyListeners();
      });

  /// Re-authenticates with the current password, then changes it.
  Future<void> changePassword(String current, String next) => _call(() async {
        try {
          await _auth.signInWithPassword(email: email, password: current);
        } on AuthException catch (e) {
          if (mapError(e.code, e.message, e.statusCode) == 'err_login') {
            throw const AuthFailure('err_wrong_old_password');
          }
          rethrow;
        }
        await _auth.updateUser(UserAttributes(password: next));
      });

  /// Local sign-out is immediate; the server call is fire-and-forget.
  Future<void> logout() async {
    if (_guest) {
      _guest = false;
      notifyListeners();
      return;
    }
    if (!isConfigured) return;
    try {
      await _auth.signOut().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Session is cleared locally even if the network call fails.
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
