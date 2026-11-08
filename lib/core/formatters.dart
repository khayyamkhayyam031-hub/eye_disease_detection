import 'package:intl/intl.dart';

/// Pure helpers (unit-tested in `test/`).
class Formatters {
  Formatters._();

  /// 0.92437 -> "92.4%". Display is capped at 99.9% (never show 100%).
  static String confidence(double value) {
    var pct = (value * 1000).roundToDouble() / 10;
    if (pct > 99.9) pct = 99.9;
    if (pct < 0) pct = 0;
    return '${pct.toStringAsFixed(1)}%';
  }

  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a', 'en_US');
  static final DateFormat _month = DateFormat('MMM yy', 'en_US');

  /// "12 Oct 2026, 3:45 PM"
  static String dateTime(DateTime dt) => _dateTime.format(dt.toLocal());

  static String month(DateTime dt) => _month.format(dt.toLocal());

  /// k***@gmail.com
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email[0]}***${email.substring(at)}';
  }
}

/// Form validators. Each returns an error key (see `S`) or null when valid.
class Validators {
  Validators._();

  static final RegExp _email =
      RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');

  static String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'err_required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'err_required';
    return _email.hasMatch(v.trim()) ? null : 'err_email';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'err_required';
    return v.length >= 6 ? null : 'err_password_short';
  }

  static String? confirm(String? v, String password) {
    if (v == null || v.isEmpty) return 'err_required';
    return v == password ? null : 'err_password_match';
  }

  static String? otp(String? v) {
    if (v == null || v.trim().isEmpty) return 'err_required';
    return RegExp(r'^\d{6}$').hasMatch(v.trim()) ? null : 'err_otp';
  }

  /// 0 = weak, 1 = fair, 2 = strong.
  static int passwordStrength(String v) {
    var score = 0;
    if (v.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'\d').hasMatch(v)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) score++;
    if (v.length < 6) return 0;
    return score >= 3 ? 2 : (score >= 1 ? 1 : 0);
  }
}
