import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/history_record.dart';
import '../../data/history_repository.dart';
import '../common/widgets.dart';

/// Summary tiles + pie chart by class + bar chart per month (custom painters,
/// no chart library → no APK size cost).
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  static const _classes = ['normal', 'cataract', 'glaucoma', 'diabetic_retinopathy'];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final records = context.watch<HistoryRepository>().records;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('statistics'))),
      body: records.isEmpty
          ? EmptyState(
              icon: Icons.bar_chart_outlined,
              title: s.t('no_stats'),
              subtitle: s.t('no_stats_sub'),
            )
          : _body(context, records, dark),
    );
  }

  Widget _body(BuildContext context, List<HistoryRecord> records, bool dark) {
    final s = context.s;
    final tt = Theme.of(context).textTheme;
    final counts = {for (final c in _classes) c: 0};
    for (final r in records) {
      counts[r.label] = (counts[r.label] ?? 0) + 1;
    }
    final slices = [
      for (final c in _classes)
        if ((counts[c] ?? 0) > 0)
          _Slice(s.label(c), counts[c]!, ResultStyle.of(c, dark: dark).color),
    ];

    // Last 6 months, oldest → newest.
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
    final perMonth = [
      for (final m in months)
        records.where((r) {
          final d = r.createdAt.toLocal();
          return d.year == m.year && d.month == m.month;
        }).length,
    ];

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: _Tile(title: s.t('total_scans'), value: '${records.length}')),
        const SizedBox(width: 12),
        Expanded(
          child: _Tile(
            title: s.t('last_scan'),
            value: Formatters.dateTime(records.first.createdAt),
            small: true,
          ),
        ),
      ]),
      SectionTitle(s.t('by_class')),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Semantics(
                label: slices.map((e) => '${e.label} ${e.count}').join(', '),
                child: CustomPaint(painter: _PiePainter(slices)),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final sl in slices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: sl.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(sl.label, style: tt.bodyMedium)),
                      Text('${sl.count}', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
      SectionTitle(s.t('by_month')),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          child: SizedBox(
            height: 180,
            child: Semantics(
              label: [
                for (var i = 0; i < months.length; i++)
                  '${Formatters.month(months[i])}: ${perMonth[i]}'
              ].join(', '),
              child: CustomPaint(
                painter: _BarPainter(
                  values: perMonth,
                  labels: months.map(Formatters.month).toList(),
                  color: Theme.of(context).colorScheme.primary,
                  textStyle: tt.bodySmall!.copyWith(color: AppPalette.of(context).textSecondary),
                  gridColor: AppPalette.of(context).divider,
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.value, this.small = false});
  final String title;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: tt.bodySmall?.copyWith(color: AppPalette.of(context).textSecondary)),
          const SizedBox(height: 6),
          Text(value,
              style: small ? tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600) : tt.headlineSmall),
        ]),
      ),
    );
  }
}

class _Slice {
  const _Slice(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices);
  final List<_Slice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (a, b) => a + b.count);
    if (total == 0) return;
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.22;
    final arcRect = rect.deflate(stroke / 2);
    var start = -math.pi / 2;
    for (final sl in slices) {
      final sweep = 2 * math.pi * sl.count / total;
      canvas.drawArc(
        arcRect,
        start,
        sweep - (slices.length > 1 ? 0.03 : 0),
        false,
        Paint()
          ..color = sl.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => old.slices != slices;
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.textStyle,
    required this.gridColor,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final TextStyle textStyle;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 22.0;
    const topPad = 18.0;
    final chartH = size.height - labelH - topPad;
    final maxV = values.fold<int>(1, math.max);
    final slot = size.width / values.length;
    final barW = slot * 0.5;

    canvas.drawLine(Offset(0, topPad + chartH), Offset(size.width, topPad + chartH),
        Paint()..color = gridColor);

    for (var i = 0; i < values.length; i++) {
      final h = chartH * values[i] / maxV;
      final x = slot * i + (slot - barW) / 2;
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, topPad + chartH - h, barW, h),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(r, Paint()..color = color);

      _text(canvas, labels[i], Offset(slot * i + slot / 2, topPad + chartH + 4), slot);
      if (values[i] > 0) {
        _text(canvas, '${values[i]}', Offset(slot * i + slot / 2, topPad + chartH - h - 16), slot);
      }
    }
  }

  void _text(Canvas canvas, String t, Offset center, double maxW) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxW);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.values != values || old.color != color || old.textStyle != textStyle;
}
