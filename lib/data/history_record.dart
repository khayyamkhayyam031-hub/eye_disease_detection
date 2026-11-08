class HistoryRecord {
  const HistoryRecord({
    required this.id,
    required this.userId,
    required this.label,
    required this.confidence,
    required this.probabilities,
    required this.createdAt,
    required this.remoteImagePath,
    this.localImagePath,
    this.remoteId,
    this.synced = false,
  });

  /// Client-generated uuid (also used as the image file name → no duplicates).
  final String id;
  final String userId;
  final String label;
  final double confidence;
  final Map<String, double> probabilities;
  final DateTime createdAt;

  /// Storage path `{user_id}/{uuid}.jpg` in the `scans` bucket.
  final String remoteImagePath;
  final String? localImagePath;
  final int? remoteId;
  final bool synced;

  HistoryRecord copyWith({String? localImagePath, int? remoteId, bool? synced}) =>
      HistoryRecord(
        id: id,
        userId: userId,
        label: label,
        confidence: confidence,
        probabilities: probabilities,
        createdAt: createdAt,
        remoteImagePath: remoteImagePath,
        localImagePath: localImagePath ?? this.localImagePath,
        remoteId: remoteId ?? this.remoteId,
        synced: synced ?? this.synced,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'label': label,
        'confidence': confidence,
        'probabilities': probabilities,
        'created_at': createdAt.toUtc().toIso8601String(),
        'image_path': remoteImagePath,
        'local_image_path': localImagePath,
        'remote_id': remoteId,
        'synced': synced,
      };

  static Map<String, double> _probs(Object? v) {
    if (v is Map) {
      return {
        for (final e in v.entries)
          e.key.toString(): (e.value is num) ? (e.value as num).toDouble() : 0.0,
      };
    }
    return const {};
  }

  factory HistoryRecord.fromJson(Map<String, dynamic> j) => HistoryRecord(
        id: j['id'] as String,
        userId: (j['user_id'] ?? '') as String,
        label: (j['label'] ?? 'normal') as String,
        confidence: ((j['confidence'] ?? 0) as num).toDouble(),
        probabilities: _probs(j['probabilities']),
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ?? DateTime.now(),
        remoteImagePath: (j['image_path'] ?? '') as String,
        localImagePath: j['local_image_path'] as String?,
        remoteId: (j['remote_id'] as num?)?.toInt(),
        synced: j['synced'] == true,
      );

  /// Row of the Supabase `history` table.
  Map<String, dynamic> toRow() => {
        'client_id': id,
        'predicted_label': label,
        'confidence': confidence,
        'probabilities': probabilities,
        'image_path': remoteImagePath,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory HistoryRecord.fromRow(Map<String, dynamic> r) => HistoryRecord(
        id: (r['client_id'] ?? 'remote-${r['id']}').toString(),
        userId: (r['user_id'] ?? '').toString(),
        label: (r['predicted_label'] ?? 'normal').toString(),
        confidence: ((r['confidence'] ?? 0) as num).toDouble(),
        probabilities: _probs(r['probabilities']),
        createdAt: DateTime.tryParse((r['created_at'] ?? '').toString()) ?? DateTime.now(),
        remoteImagePath: (r['image_path'] ?? '').toString(),
        remoteId: (r['id'] as num?)?.toInt(),
        synced: true,
      );
}
