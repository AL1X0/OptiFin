import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Échelle typographique. Sur iOS, `fontFamily: null` = SF Pro système ;
/// sur Android on s'appuie sur Roboto/Inter si embarquée (phase polish).
abstract final class OFTypography {
  static const display = TextStyle(fontSize: 34, height: 40 / 34, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const title1 = TextStyle(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static const title2 = TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  static const headline = TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400);
  static const callout = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500);
  static const caption = TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500);
}

abstract final class OFTheme {
  static ThemeData dark({Color accent = OFColors.accentFallback}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      surface: OFColors.surface,
      onSurface: OFColors.textPrimary,
      error: OFColors.danger,
    );

    const textTheme = TextTheme(
      displaySmall: OFTypography.display,
      headlineSmall: OFTypography.title1,
      titleLarge: OFTypography.title2,
      titleMedium: OFTypography.headline,
      bodyLarge: OFTypography.body,
      bodyMedium: OFTypography.callout,
      labelSmall: OFTypography.caption,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: OFColors.background,
      canvasColor: OFColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: textTheme.apply(
        bodyColor: OFColors.textPrimary,
        displayColor: OFColors.textPrimary,
      ),
      dividerTheme: const DividerThemeData(color: OFColors.stroke, thickness: 0.5, space: 0.5),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent, linearTrackColor: OFColors.stroke),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: OFColors.surfaceRaised,
        contentTextStyle: TextStyle(color: OFColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: OFRadius.mdAll),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.dark),
    );
  }
}
