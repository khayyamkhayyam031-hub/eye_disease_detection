import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/auth_repository.dart';
import '../common/nav.dart';
import '../common/widgets.dart';
import '../screens/dashboard_screen.dart';
import 'auth_common.dart';
import 'otp_screen.dart';

/// Email → reset code → code + new password → Dashboard.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  final _password = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_emailForm.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthRepository>();
    try {
      await auth.sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (e) {
      // Do not reveal whether an email is registered.
      if (mounted) {
        setState(() {
          if (e.key == 'err_generic') {
            _sent = true;
          } else {
            _error = e.key;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final codeErr = Validators.otp(_code.text);
    final valid = _resetForm.currentState!.validate();
    if (codeErr != null) setState(() => _error = codeErr);
    if (codeErr != null || !valid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthRepository>();
    try {
      await auth.resetPassword(_email.text, _code.text, _password.text);
      if (!mounted) return;
      showSnack(context, context.s.t('password_updated'));
      await replaceAll(context, const DashboardScreen());
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.key);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AuthScaffold(
      showBack: true,
      title: s.t('forgot_title'),
      subtitle: _sent
          ? '${s.t('reset_sent')}\n${Formatters.maskEmail(_email.text.trim())}'
          : s.t('forgot_subtitle'),
      children: _sent ? _resetStep(s) : _emailStep(s),
    );
  }

  List<Widget> _emailStep(S s) => [
        if (_error != null) FormMessage(s.t(_error!)),
        Form(
          key: _emailForm,
          child: TextFormField(
            controller: _email,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _send(),
            autofillHints: const [AutofillHints.email],
            validator: tr(context, Validators.email),
            decoration: InputDecoration(
              labelText: s.t('email'),
              prefixIcon: const Icon(Icons.mail_outline),
            ),
          ),
        ),
        const SizedBox(height: 24),
        LoadingButton(label: s.t('send_reset'), loading: _loading, onPressed: _send),
      ];

  List<Widget> _resetStep(S s) => [
        if (_error != null) FormMessage(s.t(_error!)),
        Text(s.t('reset_code'), style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        OtpBoxes(controller: _code, focusNode: _codeFocus, enabled: !_loading),
        const SizedBox(height: 20),
        Form(
          key: _resetForm,
          child: PasswordField(
            controller: _password,
            enabled: !_loading,
            label: s.t('new_password'),
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _reset(),
            validator: tr(context, Validators.password),
          ),
        ),
        const SizedBox(height: 24),
        LoadingButton(label: s.t('reset_password'), loading: _loading, onPressed: _reset),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(s.t('back_to_login')),
        ),
      ];
}
