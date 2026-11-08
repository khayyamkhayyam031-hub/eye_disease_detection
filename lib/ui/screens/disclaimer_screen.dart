import 'package:flutter/material.dart';

import '../../core/l10n.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('disclaimer_title'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SelectableText(s.t('disclaimer_body'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('close')),
          ),
        ]),
      ),
    );
  }
}
