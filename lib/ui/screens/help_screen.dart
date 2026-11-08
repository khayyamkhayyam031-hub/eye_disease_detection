import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/l10n.dart';
import '../common/widgets.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _feedback(BuildContext context) async {
    final s = context.s;
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.feedbackEmail,
      query: 'subject=${Uri.encodeComponent(s.t('feedback_subject'))}',
    );
    try {
      if (!await launchUrl(uri) && context.mounted) showSnack(context, s.t('err_generic'));
    } catch (_) {
      if (context.mounted) showSnack(context, s.t('err_generic'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('faq_title'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 1; i <= 4; i++) ...[
          InfoSection(
            title: s.t('faq_q$i'),
            icon: Icons.help_outline,
            text: s.t('faq_a$i'),
            initiallyExpanded: i == 1,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showImageTips(context),
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(s.t('image_tips')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _feedback(context),
          icon: const Icon(Icons.mail_outline),
          label: Text(s.t('send_feedback')),
        ),
      ]),
    );
  }
}
