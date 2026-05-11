import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Light scheme: "Sophisticated Navy & Gold" (see Design.md).
/// Dark scheme: "Nocturnal Elegance" (see Dark Mode Design.md).
class AppTheme {
  static const double _radiusSm = 4;
  static const double _radius = 8;
  static const double _radiusLg = 16;

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF031632),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF1A2B48),
    onPrimaryContainer: Color(0xFF8293B5),
    secondary: Color(0xFF775A19),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFED488),
    onSecondaryContainer: Color(0xFF785A1A),
    tertiary: Color(0xFF171713),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF2B2B27),
    onTertiaryContainer: Color(0xFF94928C),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFFBF9F8),
    onSurface: Color(0xFF1B1C1C),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F3F3),
    surfaceContainer: Color(0xFFEFEDED),
    surfaceContainerHigh: Color(0xFFEAE8E7),
    surfaceContainerHighest: Color(0xFFE4E2E2),
    surfaceDim: Color(0xFFDBD9D9),
    surfaceBright: Color(0xFFFBF9F8),
    onSurfaceVariant: Color(0xFF44474D),
    inverseSurface: Color(0xFF303030),
    onInverseSurface: Color(0xFFF2F0F0),
    inversePrimary: Color(0xFFB6C7EB),
    outline: Color(0xFF75777E),
    outlineVariant: Color(0xFFC5C6CE),
    surfaceTint: Color(0xFF4E5F7E),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFB6C7EB),
    onPrimary: Color(0xFF20304E),
    primaryContainer: Color(0xFF1A2B48),
    onPrimaryContainer: Color(0xFF8293B5),
    secondary: Color(0xFFE9C176),
    onSecondary: Color(0xFF412D00),
    secondaryContainer: Color(0xFF604403),
    onSecondaryContainer: Color(0xFFDAB36A),
    tertiary: Color(0xFFD7C4A4),
    onTertiary: Color(0xFF3A2F18),
    tertiaryContainer: Color(0xFF352913),
    onTertiaryContainer: Color(0xFFA19072),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF131315),
    onSurface: Color(0xFFE4E2E5),
    surfaceContainerLowest: Color(0xFF0D0E10),
    surfaceContainerLow: Color(0xFF1B1B1E),
    surfaceContainer: Color(0xFF1F1F22),
    surfaceContainerHigh: Color(0xFF292A2C),
    surfaceContainerHighest: Color(0xFF343537),
    surfaceDim: Color(0xFF131315),
    surfaceBright: Color(0xFF39393B),
    onSurfaceVariant: Color(0xFFC5C6CE),
    inverseSurface: Color(0xFFE4E2E5),
    onInverseSurface: Color(0xFF303033),
    inversePrimary: Color(0xFF4E5F7E),
    outline: Color(0xFF8F9098),
    outlineVariant: Color(0xFF44474D),
    surfaceTint: Color(0xFFB6C7EB),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData get lightTheme => _build(lightColorScheme, _lightTextTheme);
  static ThemeData get darkTheme => _build(darkColorScheme, _darkTextTheme);

  static ThemeData _build(ColorScheme scheme, TextTheme textTheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      textTheme: textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: _filledButtonTheme(scheme),
      elevatedButtonTheme: _elevatedButtonTheme(scheme),
      outlinedButtonTheme: _outlinedButtonTheme(scheme),
      textButtonTheme: _textButtonTheme(scheme),
      inputDecorationTheme: _inputDecorationTheme(scheme),
      chipTheme: _chipTheme(scheme),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onSecondary),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.outline,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusLg)),
        ),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme scheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: 0,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme scheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(double.infinity, 50),
        side: BorderSide(color: scheme.secondary, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(ColorScheme scheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.secondary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.secondary, width: 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, width: 2),
    );
  }

  static ChipThemeData _chipTheme(ColorScheme scheme) {
    return ChipThemeData(
      backgroundColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        color: scheme.secondary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }

  /// Light typography uses Montserrat throughout (Design.md).
  static TextTheme get _lightTextTheme {
    final base = GoogleFonts.montserratTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        height: 48 / 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.32,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Dark typography pairs Playfair Display headlines with Manrope body
  /// (Dark Mode Design.md).
  static TextTheme get _darkTextTheme {
    final headline = GoogleFonts.playfairDisplayTextTheme();
    final body = GoogleFonts.manropeTextTheme();
    return body.copyWith(
      displayLarge: headline.displayLarge?.copyWith(
        fontSize: 48,
        height: 56 / 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.96,
      ),
      headlineLarge: headline.headlineLarge?.copyWith(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: headline.headlineMedium?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: headline.titleLarge?.copyWith(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
      ),
    );
  }
}
