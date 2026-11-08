import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/image_utils.dart';
import '../../core/l10n.dart';
import '../common/widgets.dart';

class PreviewResult {
  const PreviewResult.use(this.path) : retake = false;
  const PreviewResult.retake()
      : path = null,
        retake = true;
  final String? path;
  final bool retake;
}

/// Rotate 90° and pinch/drag to crop inside a square frame.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.imagePath});
  final String imagePath;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _transform = TransformationController();
  int _turns = 0;
  Size? _imageSize;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  /// Reads the dimensions from the header without a full decode.
  Future<void> _readSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final desc = await ui.ImageDescriptor.encoded(buffer);
      if (mounted) {
        setState(() => _imageSize = Size(desc.width.toDouble(), desc.height.toDouble()));
      }
      desc.dispose();
      buffer.dispose();
    } catch (_) {
      if (mounted) setState(() => _imageSize = const Size(1, 1));
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _rotate() => setState(() {
        _turns = (_turns + 1) % 4;
        _transform.value = Matrix4.identity();
      });

  void _reset() => setState(() {
        _turns = 0;
        _transform.value = Matrix4.identity();
      });

  /// Visible square → fractions of the rotated image.
  List<double>? _cropFractions(double side) {
    final size = _imageSize;
    if (size == null) return null;
    final m = _transform.value;
    if (m.isIdentity()) return null;
    final inv = Matrix4.inverted(m);
    final tl = MatrixUtils.transformPoint(inv, Offset.zero);
    final br = MatrixUtils.transformPoint(inv, Offset(side, side));

    final rotated = _turns.isOdd ? Size(size.height, size.width) : size;
    final scale = side / (rotated.width > rotated.height ? rotated.width : rotated.height);
    final dw = rotated.width * scale, dh = rotated.height * scale;
    final ox = (side - dw) / 2, oy = (side - dh) / 2;

    double fx(double x) => ((x - ox) / dw).clamp(0.0, 1.0);
    double fy(double y) => ((y - oy) / dh).clamp(0.0, 1.0);
    final l = fx(tl.dx), t = fy(tl.dy), r = fx(br.dx), b = fy(br.dy);
    if (r - l < 0.02 || b - t < 0.02) return null;
    return [l, t, r - l, b - t];
  }

  Future<void> _use(double side) async {
    if (_saving) return;
    final crop = _cropFractions(side);
    if (_turns == 0 && crop == null) {
      Navigator.pop(context, PreviewResult.use(widget.imagePath));
      return;
    }
    setState(() => _saving = true);
    final out = await ImageUtils.rotateAndCrop(widget.imagePath,
        quarterTurns: _turns, cropRect: crop);
    if (!mounted) return;
    setState(() => _saving = false);
    if (out == null) {
      showSnack(context, context.s.t('image_load_error'));
      return;
    }
    Navigator.pop(context, PreviewResult.use(out));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('preview_title')),
        actions: [
          IconButton(
            tooltip: s.t('rotate'),
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
            onPressed: _saving ? null : _rotate,
          ),
          IconButton(
            tooltip: s.t('reset'),
            icon: const Icon(Icons.restart_alt),
            onPressed: _saving ? null : _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final fit = (c.maxWidth - 32) < (c.maxHeight - 200)
              ? c.maxWidth - 32
              : c.maxHeight - 200;
          final side = fit < 120 ? 120.0 : fit;
          return Column(children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: cs.secondary, width: 2),
                ),
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 6,
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: RotatedBox(
                        quarterTurns: _turns,
                        child: Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s.t('crop_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, const PreviewResult.retake()),
                    child: Text(s.t('retake')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LoadingButton(
                    label: s.t('use_image'),
                    loading: _saving,
                    onPressed: _imageSize == null ? null : () => _use(side),
                  ),
                ),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}
