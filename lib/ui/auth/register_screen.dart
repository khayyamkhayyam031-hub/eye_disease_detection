import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/auth_repository.dart';
import '../../data/settings_repository.dart';
import '../common/nav.dart';
import '../common/widgets.dart';
import '../screens/disclaimer_screen.dart';
import 'auth_common.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agree = false;
  bool _agreeError = false;
  bool _loading = false;
  String? _error;
  int _strength = -1;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final valid = _form.currentState!.validate();
    setState(() => _agreeError = !_agree);
    if (!valid || !_agree) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthRepository>();
    final settings = context.read<SettingsRepository>();
    try {
      await auth.register(_name.text, _email.text, _password.text);
      await settings.setDisclaimerAccepted(true);
      if (mounted) await replace(context, OtpScreen(email: _email.text.trim()));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.key);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = AppPalette.of(context);
    final strengthText = switch (_strength) {
      0 => s.t('pw_weak'),
      1 => s.t('pw_fair'),
      2 => s.t('pw_strong'),
      _ => null,
    };
    final strengthColor = switch (_strength) {
      0 => p.error,
      1 => p.warning,
      _ => p.success,
    };
    return AuthScaffold(
      showBack: true,
      title: s.t('create_account'),
      subtitle: s.t('create_account_sub'),
      children: [
        if (_error != null) FormMessage(s.t(_error!)),
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _name,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: tr(context, Validators.required),
              decoration: InputDecoration(
                labelText: s.t('full_name'),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: tr(context, Validators.email),
              decoration: InputDecoration(
                labelText: s.t('email'),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              enabled: !_loading,
              label: s.t('password'),
              autofillHints: const [AutofillHints.newPassword],
              validator: tr(context, Validators.password),
              onChanged: (v) =>
                  setState(() => _strength = v.isEmpty ? -1 : Validators.passwordStrength(v)),
            ),
            if (strengthText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(strengthText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: strengthColor)),
              ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirm,
              enabled: !_loading,
              label: s.t('confirm_password'),
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
              validator: tr(context, (v) => Validators.confirm(v, _password.text)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Checkbox(
            value: _agree,
            isError: _agreeError,
            onChanged: _loading
                ? null
                : (v) => setState(() {
                      _agree = v ?? false;
                      if (_agree) _agreeError = false;
                    }),
          ),
          Expanded(
            child: InkWell(
              onTap: () => push(context, const DisclaimerScreen()),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  s.t('agree_disclaimer'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ]),
        if (_agreeError)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(s.t('must_accept_disclaimer'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.error)),
          ),
        const SizedBox(height: 8),
        const DisclaimerBar(),
        const SizedBox(height: 16),
        LoadingButton(label: s.t('create_account'), loading: _loading, onPressed: _register),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(s.t('have_account')),
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: Text(s.t('login')),
          ),
        ]),
      ],
    );
  }
}
