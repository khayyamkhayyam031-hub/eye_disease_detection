import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/history_repository.dart';
import '../../data/settings_repository.dart';
import '../common/nav.dart';
import '../common/widgets.dart';
import 'about_screen.dart';
import 'disclaimer_screen.dart';
import 'help_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearHistory(BuildContext context) async {
    final s = context.s;
    final ok = await confirmDialog(context,
        title: s.t('clear_all_q'), message: s.t('clear_all_msg'), action: s.t('clear_all'));
    if (!ok || !context.mounted) return;
    await context.read<HistoryRepository>().clearAll();
    if (context.mounted) showSnack(context, s.t('history_cleared'));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = context.watch<SettingsRepository>();
    final cs = Theme.of(context).colorScheme;

    Widget header(String key) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(s.t(key),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: ListView(children: [
        header('appearance'),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(s.t('dark_mode')),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(s.t('theme_system'))),
                ButtonSegment(value: ThemeMode.light, label: Text(s.t('theme_light'))),
                ButtonSegment(value: ThemeMode.dark, label: Text(s.t('theme_dark'))),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) => settings.setThemeMode(v.first),
            ),
          ),
        ),
        header('language'),
        RadioGroup<String>(
          groupValue: settings.locale.languageCode,
          onChanged: (v) {
            if (v != null) settings.setLanguage(v);
          },
          child: const Column(children: [
            RadioListTile<String>(value: 'en', title: Text('English')),
            RadioListTile<String>(value: 'ur', title: Text('اردو')),
          ]),
        ),
        header('data'),
        ListTile(
          leading: Icon(Icons.delete_sweep_outlined, color: AppPalette.of(context).error),
          title: Text(s.t('clear_history')),
          onTap: () => _clearHistory(context),
        ),
        header('about'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(s.t('about_app')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(context, const AboutScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.policy_outlined),
          title: Text(s.t('disclaimer_privacy')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(context, const DisclaimerScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(s.t('help')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(context, const HelpScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.tag),
          title: Text(s.t('version')),
          trailing: const Text(AppConfig.appVersion),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
