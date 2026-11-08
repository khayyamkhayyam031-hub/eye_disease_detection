import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/image_utils.dart';
import '../../core/l10n.dart';
import '../../data/auth_repository.dart';
import '../../data/disease_info.dart';
import '../../data/settings_repository.dart';
import '../../ml/eye_classifier.dart';
import '../auth/login_screen.dart';
import '../common/nav.dart';
import '../common/widgets.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

/// Brand splash: shown only while startup work runs (min 1 s, max 2 s).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _min = Duration(seconds: 1);
  static const _max = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    // Heavy preloading starts only after the first frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final started = DateTime.now();
    final model = EyeClassifier.instance.preload().catchError((_) {});
    unawaited(DiseaseInfoRepository.instance.load().then((_) {}, onError: (_) {}));
    unawaited(ImageUtils.cleanWorkDir());

    // Wait for the model up to the 2 s cap; it keeps loading in the background.
    await Future.any([model, Future<void>.delayed(_max)]);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < _min) await Future<void>.delayed(_min - elapsed);
    if (!mounted) return;

    final settings = context.read<SettingsRepository>();
    final auth = context.read<AuthRepository>();
    final Widget next;
    if (!settings.onboardingDone) {
      next = const OnboardingScreen();
    } else if (auth.isLoggedIn) {
      next = const DashboardScreen();
    } else {
      next = const LoginScreen();
    }
    unawaited(replaceAll(context, next));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = context.s;
    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      const AppLogo(size: 96),
      const SizedBox(height: 20),
      Text(s.t('app_name'),
          style: tt.displaySmall?.copyWith(color: cs.primary), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(s.t('app_tagline'),
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 40),
      SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.secondary),
      ),
    ]);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: animationsOn(context)
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
                  ),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}

/// Eye logo drawn with widgets (no bitmap assets → tiny APK).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: size * 0.55),
    );
  }
}
