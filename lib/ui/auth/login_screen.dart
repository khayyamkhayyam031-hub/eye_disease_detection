import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/auth_repository.dart';
import '../common/nav.dart';
import '../common/widgets.dart';
import '../screens/dashboard_screen.dart';
import 'auth_common.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return; // ignore double taps
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthRepository>();
    try {
      await auth.login(_email.text, _password.text);
      TextInput.finishAutofillContext();
      if (mounted) await replaceAll(context, const DashboardScreen());
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.key);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendAndVerify() async {
    final email = _email.text.trim();
    final auth = context.read<AuthRepository>();
    try {
      await auth.resendSignupCode(email);
    } on AuthFailure catch (e) {
      if (mounted && e.key != 'err_rate_limit') {
        setState(() => _error = e.key);
        return;
      }
    }
    if (mounted) push(context, OtpScreen(email: email));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final auth = context.read<AuthRepository>();
    return AuthScaffold(
      title: s.t('welcome_back'),
      subtitle: s.t('login_subtitle'),
      children: [
        if (!auth.isConfigured) FormMessage(s.t('not_configured')),
        if (_error != null)
          FormMessage(
            s.t(_error!),
            action: _error == 'err_not_verified'
                ? TextButton(onPressed: _resendAndVerify, child: Text(s.t('resend_code')))
                : null,
          ),
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              validator: tr(context, Validators.password),
            ),
          ]),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: _loading ? null : () => push(context, ForgotPasswordScreen(email: _email.text)),
            child: Text(s.t('forgot_password_q')),
          ),
        ),
        const SizedBox(height: 8),
        LoadingButton(label: s.t('login'), loading: _loading, onPressed: _login),
        const SizedBox(height: 16),
        if (!auth.isConfigured) ...[
          OutlinedButton.icon(
            onPressed: () {
              auth.continueAsGuest();
              replaceAll(context, const DashboardScreen());
            },
            icon: const Icon(Icons.person_outline),
            label: Text(s.t('continue_guest')),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(s.t('no_account')),
          TextButton(
            onPressed: _loading ? null : () => push(context, const RegisterScreen()),
            child: Text(s.t('register')),
          ),
        ]),
      ],
    );
  }
}
