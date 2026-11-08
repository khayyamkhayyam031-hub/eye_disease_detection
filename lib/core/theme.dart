import 'package:flutter/material.dart';

/// Design tokens from UI_UX.md §2.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1E5AA8);
  static const primaryDark = Color(0xFF154073);
  static const secondary = Color(0xFF14A098);
  static const background = Color(0xFFF7F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1B1F24);
  static const textSecondary = Color(0xFF5F6B7A);
  static const divider = Color(0xFFE3E8EF);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFB7791F);
  static const error = Color(0xFFC62828);

  static const primaryN = Color(0xFF8AB4F8);
  static const primaryDarkN = Color(0xFF5C8FD6);
  static const secondaryN = Color(0xFF4FD1C5);
  static const backgroundN = Color(0xFF121417);
  static const surfaceN = Color(0xFF1E2227);
  static const textPrimaryN = Color(0xFFE8EAED);
  static const textSecondaryN = Color(0xFFA9B1BC);
  static const dividerN = Color(0xFF2C323A);
  static const successN = Color(0xFF81C995);
  static const warningN = Color(0xFFF6C26B);
  static const errorN = Color(0xFFF28B82);
}

/// Semantic colours that are not part of [ColorScheme].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.textSecondary,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color textSecondary;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => other ?? this;
}

/// Result badge colours (UI_UX.md §2.2).
class ResultStyle {
  const ResultStyle(this.color, this.icon);
  final Color color;
  final IconData icon;

  static ResultStyle of(String? label, {bool dark = false}) {
    switch (label) {
      case 'normal':
        return ResultStyle(
            dark ? AppColors.successN : AppColors.success, Icons.check_circle_outline);
      case 'cataract':
        return ResultStyle(
            dark ? AppColors.warningN : AppColors.warning, Icons.cloud_outlined);
      case 'glaucoma':
        return ResultStyle(dark ? const Color(0xFFFFA36B) : const Color(0xFFD9480F),
            Icons.radio_button_checked);
      case 'diabetic_retinopathy':
        return ResultStyle(
            dark ? AppColors.errorN : AppColors.error, Icons.blur_on);
      default:
        return ResultStyle(dark ? AppColors.textSecondaryN : AppColors.textSecondary,
            Icons.hide_image_outlined);
    }
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        background: AppColors.background,
        surface: AppColors.surface,
        text: AppColors.textPrimary,
        palette: const AppPalette(
          textSecondary: AppColors.textSecondary,
          divider: AppColors.divider,
          success: AppColors.success,
          warning: AppColors.warning,
          error: AppColors.error,
        ),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        primary: AppColors.primaryN,
        secondary: AppColors.secondaryN,
        background: AppColors.backgroundN,
        surface: AppColors.surfaceN,
        text: AppColors.textPrimaryN,
        palette: const AppPalette(
          textSecondary: AppColors.textSecondaryN,
          divider: AppColors.dividerN,
          success: AppColors.successN,
          warning: AppColors.warningN,
          error: AppColors.errorN,
        ),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color text,
    required AppPalette palette,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: dark ? const Color(0xFF0B1B33) : Colors.white,
      secondary: secondary,
      onSecondary: dark ? const Color(0xFF00201E) : Colors.white,
      error: palette.error,
      onError: dark ? const Color(0xFF370B07) : Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.divider,
      outlineVariant: palette.divider,
      surfaceContainerHighest: dark ? const Color(0xFF262B31) : const Color(0xFFEFF3F8),
      primaryContainer: dark ? const Color(0xFF1D3557) : const Color(0xFFDCE8F8),
      onPrimaryContainer: dark ? AppColors.textPrimaryN : AppColors.primaryDark,
    );

    const radius10 = BorderRadius.all(Radius.circular(10));
    final textTheme = (dark ? Typography.material2021().white : Typography.material2021().black)
        .copyWith(
          displaySmall: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          bodyLarge: const TextStyle(fontSize: 16),
          bodyMedium: const TextStyle(fontSize: 14),
          bodySmall: const TextStyle(fontSize: 12),
          labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        )
        .apply(bodyColor: text, displayColor: text);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 20),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: dark ? 0 : 2,
        shadowColor: Colors.black26,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(borderRadius: radius10),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: radius10),
          side: BorderSide(color: primary),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: const OutlineInputBorder(borderRadius: radius10),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius10, borderSide: BorderSide(color: palette.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius10, borderSide: BorderSide(color: primary, width: 2)),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: palette.divider, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
