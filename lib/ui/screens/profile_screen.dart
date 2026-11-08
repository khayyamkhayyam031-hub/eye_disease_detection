import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/auth_repository.dart';
import '../auth/auth_common.dart';
import '../common/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameForm = GlobalKey<FormState>();
  final _pwForm = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _savingName = false;
  bool _savingPw = false;
  String? _nameError;
  String? _pwError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<AuthRepository>().displayName);
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_savingName || !_nameForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _savingName = true;
      _nameError = null;
    });
    try {
      await context.read<AuthRepository>().updateName(_name.text);
      if (mounted) showSnack(context, context.s.t('name_updated'));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _nameError = e.key);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    if (_savingPw || !_pwForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _savingPw = true;
      _pwError = null;
    });
    try {
      await context.read<AuthRepository>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      _current.clear();
      _next.clear();
      showSnack(context, context.s.t('password_updated'));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _pwError = e.key);
    } finally {
      if (mounted) setState(() => _savingPw = false);
    }
  }

  Future<void> _logout() async {
    final s = context.s;
    final ok = await confirmDialog(context,
        title: s.t('logout_q'), message: s.t('logout_msg'), action: s.t('logout'));
    if (ok && mounted) await context.read<AuthRepository>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final auth = context.watch<AuthRepository>();
    final cs = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final initial = auth.displayName.isEmpty ? '?' : auth.displayName[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('profile'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: cs.primaryContainer,
            child: Text(initial,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: cs.primary)),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(auth.email, style: Theme.of(context).textTheme.bodyMedium)),
        SectionTitle(s.t('edit_name')),
        if (_nameError != null) FormMessage(s.t(_nameError!)),
        Form(
          key: _nameForm,
          child: TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            validator: tr(context, Validators.required),
            decoration: InputDecoration(
              labelText: s.t('full_name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LoadingButton(label: s.t('save'), loading: _savingName, onPressed: _saveName),
        SectionTitle(s.t('change_password')),
        if (_pwError != null) FormMessage(s.t(_pwError!)),
        Form(
          key: _pwForm,
          child: Column(children: [
            PasswordField(
              controller: _current,
              label: s.t('current_password'),
              validator: tr(context, Validators.password),
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _next,
              label: s.t('new_password'),
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _changePassword(),
              validator: tr(context, Validators.password),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        LoadingButton(label: s.t('update'), loading: _savingPw, onPressed: _changePassword),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: p.error,
            side: BorderSide(color: p.error),
            minimumSize: const Size(double.infinity, 52),
          ),
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: Text(s.t('logout')),
        ),
      ]),
    );
  }
}
