import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/auth_repository.dart';
import 'data/history_repository.dart';
import 'data/secure_session_storage.dart';
import 'data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only cheap work before the first frame; the model is preloaded from
  // the splash screen after it has been drawn.
  final settings = await SettingsRepository.load();
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          localStorage: SecureSessionStorage(),
        ),
        debug: false,
      );
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  }

  final auth = AuthRepository();
  final history = HistoryRepository();
  void bind() => history.bindUser(auth.isLoggedIn ? auth.userId : null);
  auth.addListener(bind);
  bind();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: history),
    ],
    child: const EyeApp(),
  ));
}
