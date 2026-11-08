import 'dart:async';

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

/// 6-digit email code verification with a 60 s resend cooldown.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.email});
  final String email;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _cooldown = 60;
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _left = _cooldown;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    final err = Validators.otp(_code.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final auth = context.read<AuthRepository>();
    try {
      await auth.verifySignupCode(widget.email, _code.text);
      if (mounted) await replaceAll(context, const DashboardScreen());
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _error = e.key);
        _code.clear();
        _focus.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthRepository>();
    _startTimer();
    try {
      await auth.resendSignupCode(widget.email);
      if (mounted) setState(() => _info = 'code_resent');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tt = Theme.of(context).textTheme;
    final mm = (_left ~/ 60).toString();
    final ss = (_left % 60).toString().padLeft(2, '0');
    return AuthScaffold(
      showBack: true,
      title: s.t('verify_title'),
      subtitle: '${s.t('verify_sent_to')}\n${Formatters.maskEmail(widget.email)}',
      children: [
        if (_error != null) FormMessage(s.t(_error!)),
        if (_info != null) FormMessage(s.t(_info!), isError: false),
        Text(s.t('verify_hint'), style: tt.bodyMedium),
        const SizedBox(height: 16),
        OtpBoxes(
          controller: _code,
          focusNode: _focus,
          enabled: !_loading,
          onCompleted: (_) => _verify(),
        ),
        const SizedBox(height: 24),
        LoadingButton(label: s.t('verify'), loading: _loading, onPressed: _verify),
        const SizedBox(height: 12),
        Center(
          child: _left > 0
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(s.f('resend_in', {'time': '$mm:$ss'}),
                      style: tt.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                )
              : TextButton(onPressed: _resend, child: Text(s.t('resend_code'))),
        ),
      ],
    );
  }
}

/// Six boxes backed by one hidden text field: auto-advance and paste support.
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onCompleted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onCompleted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(children: [
      // Real input (invisible); receives typing and pasting.
      Opacity(
        opacity: 0,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            if (v.length == 6) onCompleted?.call(v);
          },
        ),
      ),
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => focusNode.requestFocus(),
          child: ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              return Semantics(
                label: 'Verification code, ${text.length} of 6 digits entered',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    final active = focusNode.hasFocus && i == text.length.clamp(0, 5);
                    return Container(
                      width: 46,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? cs.primary : cs.outline,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Text(i < text.length ? text[i] : '',
                          style: Theme.of(context).textTheme.headlineSmall),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}
