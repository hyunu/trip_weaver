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
  static const markerBg = Color(0xFFF3E0B8);
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
  static const offlineBg = moveBg;
  static const offlineFg = move;
}

class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const page = 16.0;
}

class AppRadii {
  static const chip = 8.0;
  static const control = 12.0;
  static const card = 14.0;
  static const map = 16.0;
}

class AppDecor {
  static BoxDecoration card({Color? borderColor, double borderWidth = 1}) {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: borderColor ?? AppColors.line, width: borderWidth),
    );
  }
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

  static const cardTitle = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
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

  static const section = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.secondary,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondary,
  );

  static const banner = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
}

class AppFields {
  static InputDecoration decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppType.body.copyWith(color: AppColors.tertiary),
      filled: true,
      fillColor: AppColors.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.sm),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, primary: AppColors.accent, surface: AppColors.card);
  final field = AppFields.decoration('');
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
      labelMedium: AppType.footnoteStrong,
      labelSmall: AppType.caption,
    ),
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: field.hintStyle,
      filled: true,
      fillColor: AppColors.card,
      isDense: true,
      contentPadding: field.contentPadding,
      enabledBorder: field.enabledBorder,
      focusedBorder: field.focusedBorder,
      disabledBorder: field.disabledBorder,
      errorBorder: field.errorBorder,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      titleTextStyle: AppType.headline,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: AppType.headline,
        minimumSize: const Size(44, 44),
      ),
    ),
  );
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.destructive = false,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    late final Color background;
    late final Color foreground;
    late final BorderSide side;
    if (!enabled) {
      background = AppColors.canvas;
      foreground = AppColors.tertiary;
      side = const BorderSide(color: AppColors.line);
    } else if (destructive) {
      background = selected ? AppColors.conflictBg : AppColors.card;
      foreground = AppColors.danger;
      side = const BorderSide(color: AppColors.danger);
    } else if (selected) {
      background = AppColors.accentSoft;
      foreground = AppColors.accent;
      side = const BorderSide(color: AppColors.accent);
    } else if (filled) {
      background = AppColors.accent;
      foreground = Colors.white;
      side = BorderSide.none;
    } else {
      background = AppColors.card;
      foreground = AppColors.ink;
      side = const BorderSide(color: AppColors.line);
    }
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.canvas,
          disabledForegroundColor: AppColors.tertiary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.control)),
          side: side,
          textStyle: AppType.headline,
        ),
        child: Text(label, style: AppType.headline.copyWith(color: foreground)),
      ),
    );
  }
}
