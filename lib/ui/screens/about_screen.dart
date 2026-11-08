import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../ml/eye_classifier.dart';
import 'splash_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tt = Theme.of(context).textTheme;
    final cfg = EyeClassifier.instance.config;
    final classes = cfg.labels.where((l) => l != cfg.rejectLabel).map(s.label).join(', ');

    Widget row(String k, String v) => ListTile(
          title: Text(s.t(k), style: tt.bodySmall),
          subtitle: Text(v, style: tt.bodyLarge),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.t('about_app'))),
      body: ListView(padding: const EdgeInsets.symmetric(vertical: 16), children: [
        const Center(child: AppLogo(size: 80)),
        const SizedBox(height: 12),
        Center(child: Text(s.t('app_name'), style: tt.headlineSmall)),
        Center(child: Text('${s.t('version')} ${AppConfig.appVersion}', style: tt.bodyMedium)),
        const SizedBox(height: 16),
        row('model', s.t('model_name')),
        row('test_accuracy', AppConfig.modelAccuracy),
        row('classes', classes),
        row('reject_threshold', '${(cfg.minConfidence * 100).round()}%'),
        row('developer', AppConfig.developer),
        row('university', AppConfig.university),
      ]),
    );
  }
}
