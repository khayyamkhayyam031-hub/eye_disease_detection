/// Build-time configuration.
///
/// Pass the Supabase project values when building/running, e.g.
///   flutter run --dart-define-from-file=env.json
/// (see `env.example.json`). Only the public anon key belongs in the app;
/// the service_role key must never be used here.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const String appVersion = '1.0.0';
  static const String developer = 'Khayyam';
  static const String university = 'Kohsar University Murree';
  static const String feedbackEmail = 'abbasikhayyam37@gmail.com';

  /// Test accuracy of the bundled model (update after the final Colab run).
  static const String modelAccuracy = '≥ 90% (test set)';

  static const String historyTable = 'history';
  static const String scansBucket = 'scans';
}
