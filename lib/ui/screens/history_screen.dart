import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/history_record.dart';
import '../../data/history_repository.dart';
import '../common/nav.dart';
import '../common/widgets.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Cache is shown immediately; refresh from the server in the background.
    context.read<HistoryRepository>().sync();
  }

  Future<void> _delete(HistoryRecord r) async {
    final s = context.s;
    final ok = await confirmDialog(context,
        title: s.t('delete_q'), message: s.t('delete_msg'), action: s.t('delete'));
    if (!ok || !mounted) return;
    deleteWithUndo(context, r.id);
  }

  Future<void> _clearAll() async {
    final s = context.s;
    final ok = await confirmDialog(context,
        title: s.t('clear_all_q'), message: s.t('clear_all_msg'), action: s.t('clear_all'));
    if (!ok || !mounted) return;
    await context.read<HistoryRepository>().clearAll();
    if (mounted) showSnack(context, s.t('history_cleared'));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final repo = context.watch<HistoryRepository>();
    final records = repo.records;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('history')),
        actions: [
          if (records.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              style: TextButton.styleFrom(foregroundColor: AppPalette.of(context).error),
              child: Text(s.t('clear_all')),
            ),
        ],
      ),
      body: !repo.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? EmptyState(
                  icon: Icons.history,
                  title: s.t('no_scans'),
                  subtitle: s.t('no_scans_sub'),
                  actionLabel: s.t('start_scan'),
                  onAction: () => Navigator.pop(context),
                )
              : RefreshIndicator(
                  onRefresh: repo.sync,
                  child: _HistoryList(records: records, offline: repo.isOffline, onDelete: _delete),
                ),
    );
  }
}

/// Deletes optimistically and offers Undo for 5 s.
void deleteWithUndo(BuildContext context, String id) {
  final repo = context.read<HistoryRepository>();
  final s = context.s;
  repo.delete(id);
  showSnack(
    context,
    s.t('record_deleted'),
    actionLabel: s.t('undo'),
    onAction: () => repo.undoDelete(id),
    duration: HistoryRepository.undoWindow,
  );
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.records, required this.offline, required this.onDelete});
  final List<HistoryRecord> records;
  final bool offline;
  final ValueChanged<HistoryRecord> onDelete;

  String _section(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'today';
    if (d == today.subtract(const Duration(days: 1))) return 'yesterday';
    return 'earlier';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // Flatten to [header?, record, record, header, ...].
    final items = <Object>[];
    String? last;
    for (final r in records) {
      final sec = _section(r.createdAt.toLocal());
      if (sec != last) {
        items.add(sec);
        last = sec;
      }
      items.add(r);
    }
    final hasBanner = offline;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length + (hasBanner ? 1 : 0),
      itemBuilder: (context, i) {
        if (hasBanner && i == 0) {
          return MaterialBanner(
            content: Text(s.t('offline_cached')),
            leading: const Icon(Icons.cloud_off_outlined),
            actions: const [SizedBox.shrink()],
          );
        }
        final item = items[i - (hasBanner ? 1 : 0)];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(s.t(item),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          );
        }
        final r = item as HistoryRecord;
        return HistoryTile(
          key: ValueKey(r.id),
          record: r,
          onTap: () => push(context, HistoryDetailScreen(recordId: r.id)),
          onDelete: () => onDelete(r),
        );
      },
    );
  }
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final HistoryRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = ResultStyle.of(record.label, dark: dark).color;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          RecordThumb(record: record, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(ResultStyle.of(record.label, dark: dark).icon, size: 16, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(s.label(record.label),
                      style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text(Formatters.confidence(record.confidence),
                    style: tt.bodyMedium?.copyWith(color: color)),
              ]),
              const SizedBox(height: 4),
              Text(Formatters.dateTime(record.createdAt),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (!record.synced)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Icon(Icons.cloud_upload_outlined, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(s.t('pending_upload'),
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ]),
                ),
            ]),
          ),
          IconButton(
            tooltip: s.t('delete_record'),
            icon: Icon(Icons.delete_outline, color: AppPalette.of(context).error),
            onPressed: onDelete,
          ),
        ]),
      ),
    );
  }
}

/// Thumbnail from the local copy; downloads once if it only exists in the cloud.
class RecordThumb extends StatelessWidget {
  const RecordThumb({super.key, required this.record, required this.size, this.radius = 8});
  final HistoryRecord record;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final local = record.localImagePath;
    if (local != null) return LocalImage(path: local, size: size, radius: radius);
    return FutureBuilder<String?>(
      future: context.read<HistoryRepository>().ensureLocalImage(record),
      builder: (_, snap) => LocalImage(path: snap.data, size: size, radius: radius),
    );
  }
}
