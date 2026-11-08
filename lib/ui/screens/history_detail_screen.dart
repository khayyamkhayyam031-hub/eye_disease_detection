import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/pdf_report.dart';
import '../../data/auth_repository.dart';
import '../../data/disease_info.dart';
import '../../data/history_record.dart';
import '../../data/history_repository.dart';
import '../common/widgets.dart';
import 'history_screen.dart';
import 'result_screen.dart';

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({super.key, required this.recordId});
  final String recordId;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  DiseaseInfo? _info;
  String? _imagePath;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<HistoryRepository>();
    final r = repo.byId(widget.recordId);
    if (r != null) {
      DiseaseInfoRepository.instance.get(r.label).then((i) {
        if (mounted) setState(() => _info = i);
      }, onError: (_) {});
      repo.ensureLocalImage(r).then((p) {
        if (mounted) setState(() => _imagePath = p);
      });
    }
  }

  Future<void> _share(HistoryRecord r) async {
    final path = _imagePath;
    if (path == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await PdfReport.share(
        imagePath: path,
        label: r.label,
        confidence: r.confidence,
        probabilities: r.probabilities,
        createdAt: r.createdAt,
        patientName: context.read<AuthRepository>().displayName,
        info: _info,
      );
    } catch (_) {
      if (mounted) showSnack(context, context.s.t('err_generic'));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _delete(HistoryRecord r) async {
    final s = context.s;
    final ok = await confirmDialog(context,
        title: s.t('delete_q'), message: s.t('delete_msg'), action: s.t('delete'));
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    deleteWithUndo(context, r.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final r = context.select<HistoryRepository, HistoryRecord?>((h) => h.byId(widget.recordId));
    if (r == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('scan_detail')),
        actions: [
          IconButton(
            tooltip: s.t('share_report'),
            icon: _sharing
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_outlined),
            onPressed: _imagePath == null ? null : () => _share(r),
          ),
          IconButton(
            tooltip: s.t('delete_record'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(r),
          ),
        ],
      ),
      body: SafeArea(
        child: ResultBody(
          imagePath: _imagePath ?? r.localImagePath,
          label: r.label,
          confidence: r.confidence,
          probabilities: r.probabilities,
          info: _info,
          header: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              const Icon(Icons.schedule, size: 18),
              const SizedBox(width: 6),
              Text(Formatters.dateTime(r.createdAt),
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
        ),
      ),
    );
  }
}
