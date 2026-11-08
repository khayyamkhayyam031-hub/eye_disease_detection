import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../data/settings_repository.dart';
import '../auth/login_screen.dart';
import '../common/nav.dart';
import '../common/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (Icons.remove_red_eye_outlined, 'ob1_title', 'ob1_body'),
    (Icons.camera_outlined, 'ob2_title', 'ob2_body'),
    (Icons.insights_outlined, 'ob3_title', 'ob3_body'),
  ];

  Future<void> _finish() async {
    await context.read<SettingsRepository>().setOnboardingDone();
    if (mounted) await replaceAll(context, const LoginScreen());
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: Duration(milliseconds: animationsOn(context) ? 300 : 1),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(onPressed: _finish, child: Text(s.t('skip'))),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final (icon, title, body) = _slides[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primaryContainer,
                      ),
                      child: Icon(icon, size: 96, color: cs.primary),
                    ),
                    const SizedBox(height: 40),
                    Text(s.t(title), style: tt.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Text(s.t(body),
                        style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center),
                    if (i == 1) ...[
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _Example(icon: Icons.blur_circular, ok: true),
                        const SizedBox(width: 24),
                        _Example(icon: Icons.back_hand_outlined, ok: false),
                        const SizedBox(width: 24),
                        _Example(icon: Icons.face_outlined, ok: false),
                      ]),
                    ],
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? cs.primary : cs.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: _next,
              child: Text(last ? s.t('get_started') : s.t('next')),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Example extends StatelessWidget {
  const _Example({required this.icon, required this.ok});
  final IconData icon;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = ok ? const Color(0xFF2E7D32) : cs.error;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: ok ? const Color(0xFFE65100).withValues(alpha: 0.2) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 36, color: ok ? const Color(0xFFE65100) : cs.onSurfaceVariant),
      ),
      Positioned(
        right: -6,
        bottom: -6,
        child: CircleAvatar(
          radius: 12,
          backgroundColor: color,
          child: Icon(ok ? Icons.check : Icons.close, size: 16, color: Colors.white),
        ),
      ),
    ]);
  }
}
