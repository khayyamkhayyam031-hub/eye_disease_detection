import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/disease_info.dart';

/// Whether non-essential animations should run ("Remove animations").
bool animationsOn(BuildContext context) => !MediaQuery.of(context).disableAnimations;

/// Primary filled button that swaps its label for a spinner while [loading].
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
          )
        : Text(label);
    return FilledButton(
      onPressed: loading ? () {} : onPressed,
      child: icon == null || loading
          ? child
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Flexible(child: child),
            ]),
    );
  }
}

/// Caption with info icon on a light warning tint (UI_UX §3).
class DisclaimerBar extends StatelessWidget {
  const DisclaimerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 18, color: p.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(context.s.t('disclaimer_short'),
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: cs.primary),
          ),
          const SizedBox(height: 24),
          Text(title, style: tt.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Colour badge + text label for a class (colour is never the only signal).
class ResultBadge extends StatelessWidget {
  const ResultBadge({super.key, required this.label, this.large = false});
  final String? label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = ResultStyle.of(label, dark: dark);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 8 : 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(style.icon, color: style.color, size: large ? 22 : 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.s.label(label),
            style: (large
                    ? Theme.of(context).textTheme.headlineSmall
                    : Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(color: style.color, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }
}

/// Label left, % right, LinearProgressIndicator below. Animates 0 → value.
class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = highlight
        ? ResultStyle.of(label, dark: dark).color
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.55);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(context.s.label(label),
                style: highlight
                    ? tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                    : tt.bodyMedium),
          ),
          Text(Formatters.confidence(value), style: tt.bodyMedium),
        ]),
        const SizedBox(height: 4),
        AnimatedBar(value: value, color: color),
      ]),
    );
  }
}

class AnimatedBar extends StatelessWidget {
  const AnimatedBar({super.key, required this.value, required this.color, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    ClipRRect bar(double v) => ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: v.clamp(0.0, 1.0),
            minHeight: height,
            color: color,
            backgroundColor: track,
          ),
        );
    if (!animationsOn(context)) return bar(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.decelerate,
      builder: (_, v, _) => bar(v),
    );
  }
}

/// Expandable info card: About / Symptoms / Prevention / Treatment / See doctor.
class InfoSection extends StatelessWidget {
  const InfoSection({
    super.key,
    required this.title,
    required this.icon,
    this.text,
    this.bullets = const [],
    this.initiallyExpanded = false,
    this.highlighted = false,
  });

  final String title;
  final IconData icon;
  final String? text;
  final List<String> bullets;
  final bool initiallyExpanded;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlighted ? BorderSide(color: p.warning, width: 1.5) : BorderSide.none,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: highlighted ? p.warning : cs.secondary),
          title: Text(title, style: tt.titleMedium?.copyWith(fontSize: 16)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text != null && text!.isNotEmpty) Text(text!, style: tt.bodyLarge),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: cs.secondary, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, style: tt.bodyLarge)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// The five disease-information sections.
class DiseaseInfoSections extends StatelessWidget {
  const DiseaseInfoSections({super.key, required this.info, this.expandDoctor = false});
  final DiseaseInfo info;
  final bool expandDoctor;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    const gap = SizedBox(height: 8);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InfoSection(title: s.t('about'), icon: Icons.info_outline, text: info.about),
      gap,
      InfoSection(title: s.t('symptoms'), icon: Icons.visibility_outlined, bullets: info.symptoms),
      gap,
      InfoSection(title: s.t('prevention'), icon: Icons.shield_outlined, bullets: info.prevention),
      gap,
      InfoSection(title: s.t('treatment'), icon: Icons.medical_services_outlined, bullets: info.treatment),
      gap,
      InfoSection(
        title: s.t('see_doctor'),
        icon: Icons.local_hospital_outlined,
        text: info.seeDoctor,
        initiallyExpanded: expandDoctor,
        highlighted: true,
      ),
    ]);
  }
}

/// Decodes a local file at display size (never full resolution).
class LocalImage extends StatelessWidget {
  const LocalImage({
    super.key,
    required this.path,
    this.size,
    this.fit = BoxFit.cover,
    this.radius = 0,
  });

  final String? path;
  final double? size;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
    );
    Widget child;
    if (path == null) {
      child = placeholder;
    } else {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      child = Image.file(
        File(path!),
        width: size,
        height: size,
        fit: fit,
        cacheWidth: size == null ? null : (size! * dpr).round(),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return radius == 0
        ? child
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Confirmation dialog with a destructive action in the error colour.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final p = AppPalette.of(context);
  final s = context.s;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: p.error),
          child: Text(action),
        ),
      ],
    ),
  );
  return r ?? false;
}

void showSnack(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    duration: duration ?? const Duration(seconds: 4),
    action: actionLabel == null
        ? null
        : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}

void announce(BuildContext context, String message) {
  SemanticsService.sendAnnouncement(
      View.of(context), message, Directionality.of(context));
}

/// Bottom sheet with tips for choosing a good fundus image.
void showImageTips(BuildContext context) {
  final s = context.s;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('tips_title'), style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final (i, k) in [
            (Icons.remove_red_eye_outlined, 'tip1'),
            (Icons.do_not_disturb_alt, 'tip2'),
            (Icons.wb_sunny_outlined, 'tip3'),
            (Icons.crop_outlined, 'tip4'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(i, color: Theme.of(ctx).colorScheme.secondary),
                const SizedBox(width: 12),
                Expanded(child: Text(s.t(k), style: Theme.of(ctx).textTheme.bodyLarge)),
              ]),
            ),
        ]),
      ),
    ),
  );
}
