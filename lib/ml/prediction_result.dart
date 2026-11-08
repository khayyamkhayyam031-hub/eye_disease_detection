enum PredictionStatus { accepted, rejected, error }

class PredictionResult {
  const PredictionResult({
    required this.status,
    required this.label,
    required this.topLabel,
    required this.confidence,
    required this.probabilities,
    required this.inferenceMs,
    this.errorKey,
  });

  final PredictionStatus status;

  /// Accepted class, null when rejected / error.
  final String? label;

  /// Raw top class (also set when rejected).
  final String? topLabel;
  final double confidence;
  final Map<String, double> probabilities;
  final int inferenceMs;
  final String? errorKey;

  bool get isAccepted => status == PredictionStatus.accepted;

  factory PredictionResult.error(String key) => PredictionResult(
        status: PredictionStatus.error,
        label: null,
        topLabel: null,
        confidence: 0,
        probabilities: const {},
        inferenceMs: 0,
        errorKey: key,
      );

  /// Reject rule (PRD M10 AC3): top == reject label OR top < threshold.
  /// Confidence exactly equal to the threshold is ACCEPTED (>= rule).
  static PredictionResult fromProbabilities({
    required List<double> probs,
    required List<String> labels,
    required double minConfidence,
    String rejectLabel = 'not_fundus',
    int inferenceMs = 0,
  }) {
    var top = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[top]) top = i;
    }
    final map = <String, double>{
      for (var i = 0; i < probs.length && i < labels.length; i++) labels[i]: probs[i],
    };
    final topLabel = top < labels.length ? labels[top] : rejectLabel;
    final conf = probs.isEmpty ? 0.0 : probs[top];
    final rejected = topLabel == rejectLabel || conf < minConfidence;
    return PredictionResult(
      status: rejected ? PredictionStatus.rejected : PredictionStatus.accepted,
      label: rejected ? null : topLabel,
      topLabel: topLabel,
      confidence: conf,
      probabilities: map,
      inferenceMs: inferenceMs,
    );
  }
}
