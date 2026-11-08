import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'data/auth_repository.dart';
import 'data/settings_repository.dart';
import 'ui/auth/login_screen.dart';
import 'ui/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class EyeApp extends StatefulWidget {
  const EyeApp({super.key});

  @override
  State<EyeApp> createState() => _EyeAppState();
}

class _EyeAppState extends State<EyeApp> {
  late final AuthRepository _auth;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthRepository>();
    _wasLoggedIn = _auth.isLoggedIn;
    _auth.addListener(_onAuthChanged);
  }

  /// Logout or an expired session that could not be refreshed → Login,
  /// with the whole back stack cleared.
  void _onAuthChanged() {
    final now = _auth.isLoggedIn;
    if (_wasLoggedIn && !now) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
    _wasLoggedIn = now;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (ctx) => S.of(ctx).t('app_name'),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
