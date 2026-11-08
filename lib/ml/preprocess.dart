import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pure preprocessing (runs inside a background isolate, unit-testable).
///
/// Mirrors `model_config.json` / the Colab pipeline:
///   exif_rotate → rgb → downscale_max_448_bilinear →
///   crop_dark_border → pad_to_square_black → resize_224_bilinear
/// Output is float32 RGB with raw 0–255 values (normalisation is inside the model).
class Preprocess {
  Preprocess._();

  static const int maxWorkingSide = 448;
  static const int darkThreshold = 15;
  static const double brightLineFraction = 0.01;
  static const double minRemaining = 0.20;

  /// Full pipeline for a decoded image. Returns [size*size*3] floats.
  static Float32List run(img.Image source, {int size = 224}) {
    var im = img.bakeOrientation(source);
    im = toRgb(im);
    im = downscaleMax(im, maxWorkingSide);
    im = cropDarkBorder(im);
    im = padToSquare(im);
    return toInputBuffer(im, size: size);
  }

  static img.Image toRgb(img.Image im) {
    if (im.numChannels == 3 && im.format == img.Format.uint8) return im;
    return im.convert(format: img.Format.uint8, numChannels: 3);
  }

  static img.Image downscaleMax(img.Image im, int maxSide) {
    final longest = im.width > im.height ? im.width : im.height;
    if (longest <= maxSide) return im;
    final scale = maxSide / longest;
    return img.copyResize(
      im,
      width: (im.width * scale).round().clamp(1, maxSide),
      height: (im.height * scale).round().clamp(1, maxSide),
      interpolation: img.Interpolation.linear,
    );
  }

  /// Removes the black frame around a fundus photo.
  /// A pixel is "bright" when its gray mean > 15; a row/column is kept when
  /// more than 1% of its pixels are bright. Cropping is applied only when
  /// the remaining area is more than 20% of the original.
  static img.Image cropDarkBorder(img.Image im) {
    final w = im.width, h = im.height;
    final rowCounts = List<int>.filled(h, 0);
    final colCounts = List<int>.filled(w, 0);
    for (final p in im) {
      final gray = (p.r + p.g + p.b) / 3.0;
      if (gray > darkThreshold) {
        rowCounts[p.y]++;
        colCounts[p.x]++;
      }
    }
    int first(List<int> c, double min) {
      for (var i = 0; i < c.length; i++) {
        if (c[i] > min) return i;
      }
      return -1;
    }

    int last(List<int> c, double min) {
      for (var i = c.length - 1; i >= 0; i--) {
        if (c[i] > min) return i;
      }
      return -1;
    }

    final rowMin = w * brightLineFraction;
    final colMin = h * brightLineFraction;
    final top = first(rowCounts, rowMin), bottom = last(rowCounts, rowMin);
    final left = first(colCounts, colMin), right = last(colCounts, colMin);
    if (top < 0 || left < 0) return im;
    final cw = right - left + 1, ch = bottom - top + 1;
    if (cw <= 0 || ch <= 0) return im;
    if (cw * ch <= minRemaining * w * h) return im;
    if (cw == w && ch == h) return im;
    return img.copyCrop(im, x: left, y: top, width: cw, height: ch);
  }

  static img.Image padToSquare(img.Image im) {
    if (im.width == im.height) return im;
    final side = im.width > im.height ? im.width : im.height;
    final canvas = img.Image(width: side, height: side, numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    img.compositeImage(canvas, im,
        dstX: (side - im.width) ~/ 2, dstY: (side - im.height) ~/ 2);
    return canvas;
  }

  /// Bilinear resize to [size]x[size] and pack as float32 RGB 0–255.
  static Float32List toInputBuffer(img.Image im, {int size = 224, bool flip = false}) {
    final resized = (im.width == size && im.height == size)
        ? im
        : img.copyResize(im,
            width: size, height: size, interpolation: img.Interpolation.linear);
    final out = Float32List(size * size * 3);
    var i = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = resized.getPixel(flip ? size - 1 - x : x, y);
        out[i++] = p.r.toDouble();
        out[i++] = p.g.toDouble();
        out[i++] = p.b.toDouble();
      }
    }
    return out;
  }

  /// Horizontally flipped copy of an already-packed [size]x[size]x3 buffer.
  static Float32List flipBuffer(Float32List src, {int size = 224}) {
    final out = Float32List(src.length);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final s = (y * size + x) * 3;
        final d = (y * size + (size - 1 - x)) * 3;
        out[d] = src[s];
        out[d + 1] = src[s + 1];
        out[d + 2] = src[s + 2];
      }
    }
    return out;
  }
}
