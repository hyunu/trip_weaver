import 'package:flutter/material.dart';

class AppColors {
  static const canvas = Color(0xFFF2F2F7);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C1C1E);
  static const secondary = Color(0xFF636366);
  static const tertiary = Color(0xFF8E8E93);
  static const line = Color(0xFFE5E5EA);
  static const accent = Color(0xFF0E6B5C);
  static const accentSoft = Color(0xFFE5F4EF);
  static const sampleBg = Color(0xFFF8E7A8);
  static const sampleFg = Color(0xFF5C4810);
  static const warningFg = Color(0xFF8A4B08);
  static const warningBg = Color(0xFFFBF3E4);
  static const danger = Color(0xFFB42318);
  static const conflictFg = Color(0xFF9B1C1C);
  static const conflictBg = Color(0xFFFDECEC);
  static const move = Color(0xFF3D5A73);
  static const moveBg = Color(0xFFE7EEF4);
  static const stay = Color(0xFF0E6B5C);
  static const meal = Color(0xFF9A4E2C);
  static const mealBg = Color(0xFFF8EEE6);
  static const rest = Color(0xFF5C5346);
  static const restBg = Color(0xFFF3F1EA);
}

class AppType {
  static const family = 'Pretendard';

  static const largeTitle = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 41 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static const title = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );

  static const footnote = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    color: AppColors.secondary,
  );

  static const footnoteStrong = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, primary: AppColors.accent, surface: AppColors.card);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: AppType.family,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      displaySmall: AppType.largeTitle,
      titleLarge: AppType.title,
      titleMedium: AppType.headline,
      bodyLarge: AppType.body,
      bodyMedium: AppType.body,
      bodySmall: AppType.footnote,
      labelLarge: AppType.headline,
    ),
    dividerColor: AppColors.line,
  );
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final background = destructive
        ? Colors.transparent
        : filled
        ? AppColors.accent
        : const Color(0xFFE5E5EA);
    final foreground = destructive
        ? AppColors.danger
        : filled
        ? Colors.white
        : AppColors.ink;
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: onPressed == null ? AppColors.line : background,
          foregroundColor: onPressed == null ? AppColors.secondary : foreground,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.secondary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: AppType.headline,
        ),
        child: Text(label, style: AppType.headline.copyWith(color: onPressed == null ? AppColors.secondary : foreground)),
      ),
    );
  }
}
