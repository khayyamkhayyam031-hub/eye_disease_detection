import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Image helpers. Every heavy operation runs in a background isolate.
class ImageUtils {
  ImageUtils._();

  static const int maxSide = 1024;
  static const int jpegQuality = 90;

  static Future<Directory> _workDir() async {
    final d = Directory('${(await getTemporaryDirectory()).path}/work');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  static Future<String> _newPath() async =>
      '${(await _workDir()).path}/img_${DateTime.now().microsecondsSinceEpoch}.jpg';

  /// EXIF-rotate, downscale (max 1024 px) and compress (JPEG 90).
  /// Returns the new file path, or null when the image cannot be decoded.
  static Future<String?> prepare(String sourcePath) async {
    final out = await _newPath();
    return Isolate.run(() => _prepareSync(sourcePath, out));
  }

  static String? _prepareSync(String src, String out) {
    final decoded = img.decodeImage(File(src).readAsBytesSync());
    if (decoded == null) return null;
    var im = img.bakeOrientation(decoded);
    im = _downscale(im, maxSide);
    File(out).writeAsBytesSync(img.encodeJpg(_rgb(im), quality: jpegQuality));
    return out;
  }

  /// Rotates by [quarterTurns]×90° clockwise, then crops [cropRect]
  /// (fractions 0–1 of the rotated image: left, top, width, height).
  static Future<String?> rotateAndCrop(
    String sourcePath, {
    required int quarterTurns,
    List<double>? cropRect,
  }) async {
    final out = await _newPath();
    return Isolate.run(() => _rotateCropSync(sourcePath, out, quarterTurns, cropRect));
  }

  static String? _rotateCropSync(String src, String out, int turns, List<double>? rect) {
    final decoded = img.decodeImage(File(src).readAsBytesSync());
    if (decoded == null) return null;
    var im = img.bakeOrientation(decoded);
    final t = turns % 4;
    if (t != 0) im = img.copyRotate(im, angle: 90 * t);
    if (rect != null && rect.length == 4) {
      final x = (rect[0] * im.width).round().clamp(0, im.width - 1);
      final y = (rect[1] * im.height).round().clamp(0, im.height - 1);
      final w = (rect[2] * im.width).round().clamp(1, im.width - x);
      final h = (rect[3] * im.height).round().clamp(1, im.height - y);
      if (w < im.width || h < im.height) {
        im = img.copyCrop(im, x: x, y: y, width: w, height: h);
      }
    }
    im = _downscale(im, maxSide);
    File(out).writeAsBytesSync(img.encodeJpg(_rgb(im), quality: jpegQuality));
    return out;
  }

  /// Small JPEG bytes for embedding in the PDF report.
  static Future<Uint8List?> reportImage(String path) => Isolate.run(() {
        final f = File(path);
        if (!f.existsSync()) return null;
        final decoded = img.decodeImage(f.readAsBytesSync());
        if (decoded == null) return null;
        return Uint8List.fromList(
            img.encodeJpg(_rgb(_downscale(decoded, 600)), quality: 85));
      });

  static img.Image _rgb(img.Image im) => im.numChannels == 3
      ? im
      : im.convert(numChannels: 3);

  static img.Image _downscale(img.Image im, int max) {
    final longest = im.width > im.height ? im.width : im.height;
    if (longest <= max) return im;
    final s = max / longest;
    return img.copyResize(im,
        width: (im.width * s).round(),
        height: (im.height * s).round(),
        interpolation: img.Interpolation.linear);
  }

  /// Removes temporary working images older than a day.
  static Future<void> cleanWorkDir() async {
    try {
      final d = await _workDir();
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      await for (final e in d.list()) {
        if (e is File && (await e.lastModified()).isBefore(cutoff)) await e.delete();
      }
    } catch (_) {}
  }
}
