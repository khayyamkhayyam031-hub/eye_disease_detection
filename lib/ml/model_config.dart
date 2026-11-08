import 'dart:convert';

/// Parsed `assets/model/model_config.json`.
class ModelConfig {
  const ModelConfig({
    required this.labels,
    required this.inputSize,
    required this.minConfidence,
    required this.rejectLabel,
    required this.modelFile,
    required this.ttaHorizontalFlip,
  });

  static const double defaultMinConfidence = 0.70;

  static const fallback = ModelConfig(
    labels: ['cataract', 'diabetic_retinopathy', 'glaucoma', 'normal', 'not_fundus'],
    inputSize: 224,
    minConfidence: defaultMinConfidence,
    rejectLabel: 'not_fundus',
    modelFile: 'eye_disease_model_fp16.tflite',
    ttaHorizontalFlip: false,
  );

  final List<String> labels;
  final int inputSize;
  final double minConfidence;
  final String rejectLabel;
  final String modelFile;
  final bool ttaHorizontalFlip;

  /// Parses the JSON; any missing/invalid field falls back to defaults.
  static ModelConfig parse(String? json) {
    if (json == null || json.trim().isEmpty) return fallback;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      final labels = (m['labels'] as List?)?.map((e) => e.toString()).toList();
      final size = m['input_size'];
      final minConf = m['min_confidence'];
      return ModelConfig(
        labels: (labels == null || labels.isEmpty) ? fallback.labels : labels,
        inputSize: size is List && size.isNotEmpty
            ? (size.first as num).toInt()
            : (size is num ? size.toInt() : fallback.inputSize),
        minConfidence:
            minConf is num ? minConf.toDouble() : defaultMinConfidence,
        rejectLabel: (m['reject_label'] as String?) ?? fallback.rejectLabel,
        modelFile: (m['model_file'] as String?) ?? fallback.modelFile,
        ttaHorizontalFlip: m['tta_horizontal_flip'] == true,
      );
    } catch (_) {
      return fallback;
    }
  }

  /// `labels.txt` (one per line) overrides the config labels when present.
  ModelConfig withLabelsText(String? text) {
    if (text == null) return this;
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return this;
    return ModelConfig(
      labels: lines,
      inputSize: inputSize,
      minConfidence: minConfidence,
      rejectLabel: rejectLabel,
      modelFile: modelFile,
      ttaHorizontalFlip: ttaHorizontalFlip,
    );
  }
}
