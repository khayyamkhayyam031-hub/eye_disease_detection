import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/pdf_report.dart';
import '../../core/theme.dart';
import '../../data/auth_repository.dart';
import '../../data/disease_info.dart';
import '../../data/history_repository.dart';
import '../../ml/eye_classifier.dart';
import '../../ml/prediction_result.dart';
import '../common/widgets.dart';

/// Runs the prediction and shows loading / accepted / rejected / error states.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.imagePath});
  final String imagePath;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const _minLoader = Duration(milliseconds: 400);

  PredictionResult? _result;
  DiseaseInfo? _info;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _result = null);
    final started = DateTime.now();
    final result = await EyeClassifier.instance.classifyFile(widget.imagePath);
    final info = result.isAccepted
        ? await DiseaseInfoRepository.instance.get(result.label).catchError((_) => null)
        : null;
    // Keep the loader at least 400 ms so it does not flicker.
    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minLoader) await Future<void>.delayed(_minLoader - elapsed);
    if (!mounted) return;
    setState(() {
      _result = result;
      _info = info;
    });
    final s = context.s;
    if (result.isAccepted) {
      announce(context, s.f('tts_result', {
        'name': s.label(result.label),
        'pct': (result.confidence * 100).round(),
      }));
      // Accepted results are saved automatically (in the background).
      final history = context.read<HistoryRepository>();
      unawaited(history.add(result, widget.imagePath).then((rec) {
        if (!mounted || rec == null) return;
        showSnack(context, s.t('saved_to_history'));
      }).catchError((Object e) {
        debugPrint('Save failed: $e');
      }));
    } else if (result.status == PredictionStatus.rejected) {
      announce(context, s.t('rejected_title'));
    }
  }

  Future<void> _share() async {
    final r = _result;
    if (r == null || !r.isAccepted || _sharing) return;
    setState(() => _sharing = true);
    try {
      await PdfReport.share(
        imagePath: widget.imagePath,
        label: r.label!,
        confidence: r.confidence,
        probabilities: r.probabilities,
        createdAt: DateTime.now(),
        patientName: context.read<AuthRepository>().displayName,
        info: _info,
      );
    } catch (e) {
      if (mounted) showSnack(context, context.s.t('err_generic'));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('result'))),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: animationsOn(context) ? 250 : 0),
          child: r == null
              ? _Loading(imagePath: widget.imagePath)
              : switch (r.status) {
                  PredictionStatus.accepted => ResultBody(
                      key: const ValueKey('accepted'),
                      imagePath: widget.imagePath,
                      label: r.label!,
                      confidence: r.confidence,
                      probabilities: r.probabilities,
                      info: _info,
                      footer: Column(children: [
                        if (kDebugMode)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(s.f('inference_time', {'ms': r.inferenceMs}),
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _sharing ? null : _share,
                              icon: _sharing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.share_outlined),
                              label: Text(s.t('share_report')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.refresh),
                              label: Text(s.t('scan_again')),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  PredictionStatus.rejected => _Message(
                      key: const ValueKey('rejected'),
                      imagePath: widget.imagePath,
                      icon: Icons.hide_image_outlined,
                      title: s.t('rejected_title'),
                      body: s.t('rejected_body'),
                      showTips: true,
                    ),
                  PredictionStatus.error => _Message(
                      key: const ValueKey('error'),
                      imagePath: widget.imagePath,
                      icon: Icons.error_outline,
                      title: s.t(r.errorKey ?? 'error_read_image'),
                      body: '',
                      onRetry: r.errorKey == 'model_error' ? _run : null,
                    ),
                },
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _ResultImage(path: imagePath),
      const SizedBox(height: 32),
      const Center(child: CircularProgressIndicator()),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: Text(context.s.t('analysing'),
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
      ),
    ]);
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.imagePath,
    required this.icon,
    required this.title,
    required this.body,
    this.showTips = false,
    this.onRetry,
  });

  final String imagePath;
  final IconData icon;
  final String title;
  final String body;
  final bool showTips;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tt = Theme.of(context).textTheme;
    final grey = AppPalette.of(context).textSecondary;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _ResultImage(path: imagePath),
      const SizedBox(height: 24),
      Icon(icon, size: 56, color: grey),
      const SizedBox(height: 12),
      Text(title, style: tt.titleMedium, textAlign: TextAlign.center),
      if (body.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(body, style: tt.bodyLarge?.copyWith(color: grey), textAlign: TextAlign.center),
      ],
      const SizedBox(height: 24),
      if (showTips)
        OutlinedButton.icon(
          onPressed: () => showImageTips(context),
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(s.t('see_tips')),
        ),
      if (onRetry != null)
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(s.t('retry')),
        ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(s.t('try_another')),
      ),
      const SizedBox(height: 24),
      const DisclaimerBar(),
    ]);
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.35;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: maxH),
        child: AspectRatio(
          aspectRatio: 1,
          child: Semantics(
            image: true,
            label: 'Analysed image',
            child: LocalImage(path: path, radius: 24, size: maxH),
          ),
        ),
      ),
    );
  }
}

/// Accepted result layout (shared with History Detail).
class ResultBody extends StatelessWidget {
  const ResultBody({
    super.key,
    required this.imagePath,
    required this.label,
    required this.confidence,
    required this.probabilities,
    required this.info,
    this.header,
    this.footer,
  });

  final String? imagePath;
  final String label;
  final double confidence;
  final Map<String, double> probabilities;
  final DiseaseInfo? info;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tt = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = ResultStyle.of(label, dark: dark);
    final normal = label == 'normal';
    final sorted = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      ?header,
      _ResultImage(path: imagePath),
      const SizedBox(height: 20),
      Semantics(
        label: s.f('tts_result', {'name': s.label(label), 'pct': (confidence * 100).round()}),
        excludeSemantics: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ResultBadge(label: label, large: true),
          const SizedBox(height: 8),
          Text(
            normal ? s.t('normal_tone') : s.f('disease_tone', {'name': s.label(label)}),
            style: tt.bodyLarge,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(s.t('confidence'), style: tt.titleMedium)),
            Text(Formatters.confidence(confidence),
                style: tt.headlineSmall?.copyWith(color: style.color)),
          ]),
          const SizedBox(height: 8),
          AnimatedBar(value: confidence, color: style.color, height: 12),
        ]),
      ),
      SectionTitle(s.t('all_probabilities')),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (final e in sorted)
              ProbabilityBar(label: e.key, value: e.value, highlight: e.key == label),
          ]),
        ),
      ),
      if (info != null) ...[
        const SizedBox(height: 16),
        DiseaseInfoSections(info: info!, expandDoctor: !normal),
      ],
      const SizedBox(height: 16),
      const DisclaimerBar(),
      if (footer != null) ...[const SizedBox(height: 16), footer!],
    ]);
  }
}
