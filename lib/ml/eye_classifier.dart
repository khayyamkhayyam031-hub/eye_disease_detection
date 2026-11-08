import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'model_config.dart';
import 'prediction_result.dart';
import 'preprocess.dart';

/// One shared TFLite interpreter for the whole app.
///
/// * The interpreter lives on the Android side (`TfliteChannel.kt`) and runs on
///   its own background thread, so inference never blocks the UI.
/// * Loaded once after the first frame ([preload]) and warmed up with a dummy
///   inference so the user's first prediction is fast.
/// * Preprocessing runs in a short-lived Dart isolate.
/// * Only one prediction runs at a time (calls are serialised).
class EyeClassifier {
  EyeClassifier._();
  static final EyeClassifier instance = EyeClassifier._();

  static const _channel = MethodChannel('eye_disease/tflite');
  static const _modelDir = 'assets/model/';

  ModelConfig config = ModelConfig.fallback;
  Future<void>? _loading;
  Future<void> _queue = Future.value();
  bool _ready = false;

  bool get isReady => _ready;

  /// Starts loading (idempotent). Safe to call many times.
  Future<void> preload() => _loading ??= _load().catchError((Object e) {
        _loading = null; // allow a retry later
        throw e;
      });

  Future<void> _load() async {
    final sw = Stopwatch()..start();
    String? cfgText, labelsText;
    try {
      cfgText = await rootBundle.loadString('${_modelDir}model_config.json');
    } catch (_) {}
    try {
      labelsText = await rootBundle.loadString('${_modelDir}labels.txt');
    } catch (_) {}
    config = ModelConfig.parse(cfgText).withLabelsText(labelsText);

    final threads = Platform.numberOfProcessors >= 4 ? 4 : 2;
    await _channel.invokeMethod<Map<Object?, Object?>>('load', {
      'asset': '$_modelDir${config.modelFile}',
      'threads': threads,
    });

    // Warm-up so the user's first prediction is fast.
    final n = config.inputSize;
    await _infer(Float32List(n * n * 3));
    _ready = true;
    debugPrint('EyeClassifier ready in ${sw.elapsedMilliseconds} ms');
  }

  Future<List<double>> _infer(Float32List input) async {
    final out = await _channel.invokeMethod<Float32List>('run', {'input': input});
    if (out == null) throw StateError('empty output');
    return out.map((e) => e.toDouble()).toList();
  }

  /// Classifies the image at [path]. Never throws.
  Future<PredictionResult> classifyFile(String path) {
    final completer = Completer<PredictionResult>();
    _queue = _queue.then((_) async {
      completer.complete(await _classify(path));
    });
    return completer.future;
  }

  Future<PredictionResult> _classify(String path) async {
    try {
      await preload();
    } catch (e) {
      debugPrint('Model load failed: $e');
      return PredictionResult.error('model_error');
    }
    final size = config.inputSize;
    final tta = config.ttaHorizontalFlip;
    final List<Float32List>? inputs;
    try {
      inputs = await Isolate.run(() => _preprocessFile(path, size, tta));
    } catch (e) {
      debugPrint('Preprocess failed: $e');
      return PredictionResult.error('error_read_image');
    }
    if (inputs == null) return PredictionResult.error('error_read_image');

    try {
      final sw = Stopwatch()..start();
      var probs = await _infer(inputs.first);
      if (inputs.length > 1) {
        // Test-time augmentation: average with the horizontally flipped image.
        final p2 = await _infer(inputs[1]);
        probs = [for (var i = 0; i < probs.length; i++) (probs[i] + p2[i]) / 2];
      }
      sw.stop();
      return PredictionResult.fromProbabilities(
        probs: probs,
        labels: config.labels,
        minConfidence: config.minConfidence,
        rejectLabel: config.rejectLabel,
        inferenceMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      debugPrint('Inference failed: $e');
      return PredictionResult.error('model_error');
    }
  }

  static List<Float32List>? _preprocessFile(String path, int size, bool tta) {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width < 8 || decoded.height < 8) return null;
    final input = Preprocess.run(decoded, size: size);
    return [input, if (tta) Preprocess.flipBuffer(input, size: size)];
  }

  Future<void> close() async {
    _loading = null;
    _ready = false;
    try {
      await _channel.invokeMethod<void>('close');
    } catch (_) {}
  }
}
