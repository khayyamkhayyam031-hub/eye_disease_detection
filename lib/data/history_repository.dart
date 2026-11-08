import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../ml/prediction_result.dart';
import 'history_record.dart';

/// Local-first history with background cloud sync (architecture.md §5.6).
///
/// * Records + compressed images live in app-private storage per user, so
///   History opens instantly and works offline.
/// * New records are queued and uploaded (image → row) when online; the
///   client uuid makes retries idempotent.
/// * Deletes are optimistic: removed from the list immediately with a 5 s
///   Undo window, then committed locally and on the server.
class HistoryRepository extends ChangeNotifier {
  HistoryRepository();

  static const undoWindow = Duration(seconds: 5);
  static const _uuid = Uuid();

  String? _uid;
  Directory? _root;
  List<HistoryRecord> _records = [];
  bool _loaded = false;
  bool _offline = false;
  bool _syncing = false;
  final Map<String, _PendingDelete> _pendingDeletes = {};
  Future<void> _writeChain = Future.value();

  List<HistoryRecord> get records => _records;
  bool get isLoaded => _loaded;
  bool get isOffline => _offline;
  String? get userId => _uid;

  SupabaseClient? get _client =>
      AppConfig.isSupabaseConfigured ? Supabase.instance.client : null;

  // ---------------------------------------------------------------- user scope

  /// Switches to [uid] (null on logout). Each user only sees their own data.
  Future<void> bindUser(String? uid) async {
    if (uid == _uid) return;
    _commitAllPendingDeletes();
    _uid = uid;
    _records = [];
    _loaded = false;
    _offline = false;
    notifyListeners();
    if (uid != null) await load();
  }

  Future<Directory> _userDir() async {
    _root ??= await getApplicationSupportDirectory();
    final dir = Directory('${_root!.path}/users/$_uid');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async => File('${(await _userDir()).path}/history.json');
  Future<File> _deletesFile() async =>
      File('${(await _userDir()).path}/pending_deletes.json');

  Future<Directory> _scanDir() async {
    final d = Directory('${(await _userDir()).path}/scans');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  // ---------------------------------------------------------------- load/save

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) return;
    final file = await _indexFile();
    final list = await Isolate.run(() => _readIndex(file.path));
    if (uid != _uid) return;
    _records = list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _loaded = true;
    notifyListeners();
    unawaited(sync());
  }

  static List<HistoryRecord> _readIndex(String path) {
    final f = File(path);
    if (!f.existsSync()) return [];
    try {
      final data = jsonDecode(f.readAsStringSync()) as List;
      return data
          .map((e) => HistoryRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _persist() {
    final uid = _uid;
    if (uid == null) return;
    final snapshot = jsonEncode(_records.map((r) => r.toJson()).toList());
    _writeChain = _writeChain.then((_) async {
      if (uid != _uid) return;
      final f = await _indexFile();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(snapshot, flush: true);
      await tmp.rename(f.path);
    }).catchError((Object e) {
      debugPrint('History persist failed: $e');
    });
  }

  // ---------------------------------------------------------------- add

  /// Saves an ACCEPTED prediction. [imagePath] is the prepared JPEG
  /// (EXIF-corrected, max side 1024, quality 90).
  Future<HistoryRecord?> add(PredictionResult result, String imagePath) async {
    final uid = _uid;
    if (uid == null || !result.isAccepted || result.label == null) return null;
    final id = _uuid.v4();
    final dest = File('${(await _scanDir()).path}/$id.jpg');
    await File(imagePath).copy(dest.path);
    final record = HistoryRecord(
      id: id,
      userId: uid,
      label: result.label!,
      confidence: result.confidence,
      probabilities: Map.of(result.probabilities),
      createdAt: DateTime.now(),
      remoteImagePath: '$uid/$id.jpg',
      localImagePath: dest.path,
    );
    if (uid != _uid) return null;
    _records = [record, ..._records];
    _persist();
    notifyListeners();
    unawaited(sync());
    return record;
  }

  HistoryRecord? byId(String id) {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ---------------------------------------------------------------- delete

  /// Removes the record from the list immediately; committed after [undoWindow].
  void delete(String id) {
    final idx = _records.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final record = _records[idx];
    _records = List.of(_records)..removeAt(idx);
    _pendingDeletes[id] = _PendingDelete(
      record,
      idx,
      Timer(undoWindow, () => _commitDelete(id)),
    );
    _persist();
    notifyListeners();
  }

  /// Restores a record deleted within the undo window.
  void undoDelete(String id) {
    final p = _pendingDeletes.remove(id);
    if (p == null) return;
    p.timer.cancel();
    final list = List.of(_records);
    list.insert(p.index.clamp(0, list.length), p.record);
    _records = list;
    _persist();
    notifyListeners();
  }

  void _commitAllPendingDeletes() {
    for (final id in _pendingDeletes.keys.toList()) {
      _pendingDeletes[id]!.timer.cancel();
      _commitDelete(id);
    }
  }

  void _commitDelete(String id) {
    final p = _pendingDeletes.remove(id);
    if (p == null) return;
    unawaited(_deleteFiles([p.record]));
    if (p.record.synced || p.record.remoteId != null) {
      unawaited(_queueRemoteDeletes([p.record]));
    }
  }

  Future<void> clearAll() async {
    _commitAllPendingDeletes();
    final all = _records;
    _records = [];
    _persist();
    notifyListeners();
    await _deleteFiles(all);
    await _queueRemoteDeletes(all, all: true);
  }

  Future<void> _deleteFiles(List<HistoryRecord> list) async {
    for (final r in list) {
      final p = r.localImagePath;
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _queueRemoteDeletes(List<HistoryRecord> list, {bool all = false}) async {
    if (_uid == null || !AppConfig.isSupabaseConfigured) return;
    final f = await _deletesFile();
    final pending = await _readDeletes(f);
    if (all) pending.add({'all': true});
    for (final r in list) {
      pending.add({'client_id': r.id, 'image_path': r.remoteImagePath});
    }
    await f.writeAsString(jsonEncode(pending));
    unawaited(sync());
  }

  static Future<List<Map<String, dynamic>>> _readDeletes(File f) async {
    if (!await f.exists()) return [];
    try {
      return (jsonDecode(await f.readAsString()) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------- sync

  /// Flushes pending deletes, uploads unsynced records and merges server rows.
  Future<void> sync() async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null || _syncing) return;
    if (client.auth.currentUser?.id != uid) return;
    _syncing = true;
    try {
      await _flushDeletes(client);
      await _uploadPending(client, uid);
      await _mergeRemote(client, uid);
      _setOffline(false);
    } catch (e) {
      debugPrint('History sync failed: $e');
      _setOffline(true);
    } finally {
      _syncing = false;
    }
  }

  void _setOffline(bool v) {
    if (_offline == v) return;
    _offline = v;
    notifyListeners();
  }

  Future<void> _flushDeletes(SupabaseClient client) async {
    final f = await _deletesFile();
    final pending = await _readDeletes(f);
    if (pending.isEmpty) return;
    final table = client.from(AppConfig.historyTable);
    final bucket = client.storage.from(AppConfig.scansBucket);
    final paths = <String>[];
    for (final d in pending) {
      if (d['all'] == true) {
        await table.delete().eq('user_id', _uid!).timeout(const Duration(seconds: 15));
      } else {
        await table.delete().eq('client_id', d['client_id'] as String)
            .timeout(const Duration(seconds: 15));
      }
      final p = d['image_path'];
      if (p is String && p.isNotEmpty) paths.add(p);
    }
    if (paths.isNotEmpty) {
      try {
        await bucket.remove(paths).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Image delete failed: $e');
      }
    }
    await f.writeAsString('[]');
  }

  Future<void> _uploadPending(SupabaseClient client, String uid) async {
    final pending = _records.where((r) => !r.synced).toList();
    if (pending.isEmpty) return;
    final bucket = client.storage.from(AppConfig.scansBucket);
    final table = client.from(AppConfig.historyTable);
    for (final r in pending) {
      final local = r.localImagePath;
      if (local != null && File(local).existsSync()) {
        final bytes = await File(local).readAsBytes();
        await bucket
            .uploadBinary(r.remoteImagePath, bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true))
            .timeout(const Duration(seconds: 30));
      }
      final rows = await table
          .upsert(r.toRow(), onConflict: 'client_id')
          .select('id')
          .timeout(const Duration(seconds: 15));
      final remoteId = rows.isNotEmpty ? (rows.first['id'] as num?)?.toInt() : null;
      if (uid != _uid) return;
      _replace(r.id, (old) => old.copyWith(synced: true, remoteId: remoteId));
    }
    _persist();
    notifyListeners();
  }

  /// Adds rows that exist on the server but not on this device (e.g. a new phone).
  Future<void> _mergeRemote(SupabaseClient client, String uid) async {
    final rows = await client
        .from(AppConfig.historyTable)
        .select()
        .order('created_at', ascending: false)
        .limit(500)
        .timeout(const Duration(seconds: 15));
    if (uid != _uid) return;
    final known = {for (final r in _records) r.id};
    final deleting = _pendingDeletes.keys.toSet();
    final added = <HistoryRecord>[];
    for (final row in rows) {
      final rec = HistoryRecord.fromRow(row);
      if (!known.contains(rec.id) && !deleting.contains(rec.id)) added.add(rec);
    }
    if (added.isEmpty) return;
    _records = [..._records, ...added]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _persist();
    notifyListeners();
  }

  void _replace(String id, HistoryRecord Function(HistoryRecord) fn) {
    final i = _records.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final list = List.of(_records);
    list[i] = fn(list[i]);
    _records = list;
  }

  /// Local file for a record's image; downloads it once if it only exists remotely.
  final Map<String, Future<String?>> _downloads = {};

  Future<String?> ensureLocalImage(HistoryRecord r) {
    final local = r.localImagePath;
    if (local != null && File(local).existsSync()) return Future.value(local);
    return _downloads[r.id] ??= _download(r).whenComplete(() => _downloads.remove(r.id));
  }

  Future<String?> _download(HistoryRecord r) async {
    final client = _client;
    if (client == null || r.remoteImagePath.isEmpty || _uid == null) return null;
    try {
      final bytes = await client.storage
          .from(AppConfig.scansBucket)
          .download(r.remoteImagePath)
          .timeout(const Duration(seconds: 20));
      final f = File('${(await _scanDir()).path}/${r.id}.jpg');
      await f.writeAsBytes(bytes, flush: true);
      _replace(r.id, (old) => old.copyWith(localImagePath: f.path));
      _persist();
      return f.path;
    } catch (e) {
      debugPrint('Image download failed: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _commitAllPendingDeletes();
    super.dispose();
  }
}

class _PendingDelete {
  _PendingDelete(this.record, this.index, this.timer);
  final HistoryRecord record;
  final int index;
  final Timer timer;
}
