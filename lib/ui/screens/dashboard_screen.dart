import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/image_utils.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/auth_repository.dart';
import '../../ml/eye_classifier.dart';
import '../common/nav.dart';
import '../common/widgets.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'library_screen.dart';
import 'preview_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _picker = ImagePicker();
  String? _imagePath;
  bool _picking = false;
  DateTime? _lastBack;

  @override
  void initState() {
    super.initState();
    unawaited(EyeClassifier.instance.preload().catchError((_) {}));
    _recoverLostImage();
  }

  /// Android may kill the activity while the camera is open.
  Future<void> _recoverLostImage() async {
    try {
      final lost = await _picker.retrieveLostData();
      final file = lost.file;
      if (file != null && mounted) await _handlePicked(file.path, ImageSource.camera);
    } catch (_) {}
  }

  static const _system = MethodChannel('eye_disease/system');

  Future<void> _openAppSettings() async {
    try {
      await _system.invokeMethod<bool>('openAppSettings');
    } catch (_) {}
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      // image_picker asks for the camera permission itself.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
        requestFullMetadata: true,
      );
      if (file == null || !mounted) return; // cancelled → nothing changes
      await _handlePicked(file.path, source);
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code.contains('camera_access_denied')) {
        showSnack(context, context.s.t('camera_denied'),
            actionLabel: context.s.t('open_settings'),
            onAction: _openAppSettings,
            duration: const Duration(seconds: 6));
      } else {
        showSnack(context, context.s.t('image_load_error'));
      }
    } catch (_) {
      if (mounted) showSnack(context, context.s.t('image_load_error'));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _handlePicked(String rawPath, ImageSource source) async {
    final prepared = await ImageUtils.prepare(rawPath);
    if (!mounted) return;
    if (prepared == null) {
      showSnack(context, context.s.t('image_load_error'));
      return;
    }
    final result = await push<PreviewResult>(context, PreviewScreen(imagePath: prepared));
    if (!mounted || result == null) return;
    if (result.retake) {
      unawaited(_pick(source));
    } else if (result.path != null) {
      setState(() => _imagePath = result.path);
    }
  }

  void _predict() {
    final path = _imagePath;
    if (path == null) return;
    push(context, ResultScreen(imagePath: path));
  }

  Future<void> _logout() async {
    final s = context.s;
    final ok = await confirmDialog(context,
        title: s.t('logout_q'), message: s.t('logout_msg'), action: s.t('logout'));
    if (!ok || !mounted) return;
    // AuthRepository notifies → EyeApp opens Login and clears the back stack.
    await context.read<AuthRepository>().logout();
  }

  Future<void> _findDoctor() async {
    final uri = Uri.parse('geo:0,0?q=eye+hospital+ophthalmologist');
    final web = Uri.parse('https://www.google.com/maps/search/eye+hospital+near+me');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  void _onPop(bool didPop, Object? _) {
    if (didPop) return;
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
    } else {
      _lastBack = now;
      showSnack(context, context.s.t('press_back_exit'), duration: const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final name = context.select<AuthRepository, String>((a) => a.displayName);
    final maxPreview = MediaQuery.sizeOf(context).height * 0.4;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.t('app_name')),
          actions: [
            IconButton(
              tooltip: s.t('profile'),
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => push(context, const ProfileScreen()),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(s.f('hello', {'name': name}), style: tt.titleMedium),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxPreview, maxWidth: maxPreview),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _PreviewBox(
                      path: _imagePath,
                      busy: _picking,
                      onTap: () => _pick(ImageSource.gallery),
                    ),
                  ),
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => showImageTips(context),
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text(s.t('image_tips')),
                ),
              ),
              Row(children: [
                Expanded(
                  child: ActionCard(
                    icon: Icons.photo_camera_outlined,
                    label: s.t('camera'),
                    semantic: s.t('open_camera'),
                    onTap: _picking ? null : () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActionCard(
                    icon: Icons.photo_library_outlined,
                    label: s.t('gallery'),
                    semantic: s.t('open_gallery'),
                    onTap: _picking ? null : () => _pick(ImageSource.gallery),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _imagePath == null ? null : _predict,
                icon: const Icon(Icons.search),
                label: Text(s.t('predict')),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  ActionCard(
                    icon: Icons.history,
                    label: s.t('history'),
                    onTap: () => push(context, const HistoryScreen()),
                  ),
                  ActionCard(
                    icon: Icons.menu_book_outlined,
                    label: s.t('library'),
                    onTap: () => push(context, const LibraryScreen()),
                  ),
                  ActionCard(
                    icon: Icons.bar_chart_outlined,
                    label: s.t('statistics'),
                    onTap: () => push(context, const StatisticsScreen()),
                  ),
                  ActionCard(
                    icon: Icons.settings_outlined,
                    label: s.t('settings'),
                    onTap: () => push(context, const SettingsScreen()),
                  ),
                  ActionCard(
                    icon: Icons.local_hospital_outlined,
                    label: s.t('find_doctor'),
                    onTap: _findDoctor,
                  ),
                  ActionCard(
                    icon: Icons.help_outline,
                    label: s.t('help'),
                    onTap: () => push(context, const HelpScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.error,
                  side: BorderSide(color: p.error),
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: Text(s.t('logout')),
              ),
              const SizedBox(height: 16),
              Text(s.t('disclaimer_short'),
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.path, required this.busy, required this.onTap});
  final String? path;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget child;
    if (busy) {
      child = const Center(child: CircularProgressIndicator());
    } else if (path != null) {
      child = Semantics(
        label: 'Selected retina image',
        image: true,
        child: LocalImage(path: path, fit: BoxFit.cover),
      );
    } else {
      child = InkWell(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_photo_alternate_outlined, size: 48, color: cs.primary),
          const SizedBox(height: 8),
          Text(s.t('no_image'), style: tt.titleMedium?.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(s.t('no_image_sub'),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]),
      );
    }
    return CustomPaint(
      foregroundPainter: path == null && !busy ? _DashedBorder(cs.outline) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(color: cs.surface, child: child),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(24)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 8), paint);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// Material card with icon + label; ripple; ≥ 48dp target.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.semantic,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semantic ?? label,
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
