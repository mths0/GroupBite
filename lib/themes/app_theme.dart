import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand-specific semantic colors that don't fit Material's ColorScheme.
/// Access with `Theme.of(context).extension<BrandColors>()!`.
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.offer,
    required this.onOffer,
    required this.openStatus,
    required this.onOpenStatus,
    required this.success,
    required this.onSuccess,
    required this.accepted,
    required this.onAccepted,
    required this.assigned,
    required this.onAssigned,
    required this.pickedUp,
    required this.onPickedUp,
  });

  final Color offer;
  final Color onOffer;
  final Color openStatus;
  final Color onOpenStatus;
  final Color success;
  final Color onSuccess;
  final Color accepted;
  final Color onAccepted;
  final Color assigned;
  final Color onAssigned;
  final Color pickedUp;
  final Color onPickedUp;

  static const BrandColors light = BrandColors(
    offer: Color(0xFFFFF1C9),
    onOffer: Color(0xFF7A5500),
    openStatus: Color(0xFFD7F0DC),
    onOpenStatus: Color(0xFF1A5E2A),
    success: Color(0xFF1A5E2A),
    onSuccess: Color(0xFFFFFFFF),
    accepted: Color(0xFFDDEBFF),
    onAccepted: Color(0xFF1A3D7A),
    assigned: Color(0xFFD4EEF1),
    onAssigned: Color(0xFF0F5E66),
    pickedUp: Color(0xFFFFDDB5),
    onPickedUp: Color(0xFF7A3E00),
  );

  static const BrandColors dark = BrandColors(
    offer: Color(0xFF6A4E1A),
    onOffer: Color(0xFFFFE7B3),
    openStatus: Color(0xFF214D3C),
    onOpenStatus: Color(0xFFC8F2DD),
    success: Color(0xFF2F7D4F),
    onSuccess: Color(0xFFFFFFFF),
    accepted: Color(0xFF263B66),
    onAccepted: Color(0xFFD6E4FF),
    assigned: Color(0xFF1D4C58),
    onAssigned: Color(0xFFBCECF5),
    pickedUp: Color(0xFF65401D),
    onPickedUp: Color(0xFFFFD9B0),
  );

  @override
  BrandColors copyWith({
    Color? offer,
    Color? onOffer,
    Color? openStatus,
    Color? onOpenStatus,
    Color? success,
    Color? onSuccess,
    Color? accepted,
    Color? onAccepted,
    Color? assigned,
    Color? onAssigned,
    Color? pickedUp,
    Color? onPickedUp,
  }) {
    return BrandColors(
      offer: offer ?? this.offer,
      onOffer: onOffer ?? this.onOffer,
      openStatus: openStatus ?? this.openStatus,
      onOpenStatus: onOpenStatus ?? this.onOpenStatus,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      accepted: accepted ?? this.accepted,
      onAccepted: onAccepted ?? this.onAccepted,
      assigned: assigned ?? this.assigned,
      onAssigned: onAssigned ?? this.onAssigned,
      pickedUp: pickedUp ?? this.pickedUp,
      onPickedUp: onPickedUp ?? this.onPickedUp,
    );
  }

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      offer: Color.lerp(offer, other.offer, t)!,
      onOffer: Color.lerp(onOffer, other.onOffer, t)!,
      openStatus: Color.lerp(openStatus, other.openStatus, t)!,
      onOpenStatus: Color.lerp(onOpenStatus, other.onOpenStatus, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      accepted: Color.lerp(accepted, other.accepted, t)!,
      onAccepted: Color.lerp(onAccepted, other.onAccepted, t)!,
      assigned: Color.lerp(assigned, other.assigned, t)!,
      onAssigned: Color.lerp(onAssigned, other.onAssigned, t)!,
      pickedUp: Color.lerp(pickedUp, other.pickedUp, t)!,
      onPickedUp: Color.lerp(onPickedUp, other.onPickedUp, t)!,
    );
  }
}

/// Light scheme: "Sophisticated Navy & Gold" (see Design.md).
/// Dark scheme: "Lively Night Market".
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
    shadow: Color(0xFF1A2B48),
    scrim: Color(0xFF1A2B48),
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFD48A),
    onPrimary: Color(0xFF4B330A),
    primaryContainer: Color(0xFFFFE3AC),
    onPrimaryContainer: Color(0xFF4B330A),
    secondary: Color(0xFF9FDCC7),
    onSecondary: Color(0xFF143B31),
    secondaryContainer: Color(0xFF173B32),
    onSecondaryContainer: Color(0xFFBDEEDC),
    tertiary: Color(0xFFB9C8F6),
    onTertiary: Color(0xFF182647),
    tertiaryContainer: Color(0xFF25365E),
    onTertiaryContainer: Color(0xFFDCE6FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF282B33),
    onSurface: Color(0xFFFFF8EE),
    surfaceContainerLowest: Color(0xFF20242B),
    surfaceContainerLow: Color(0xFF2E323A),
    surfaceContainer: Color(0xFF343943),
    surfaceContainerHigh: Color(0xFF3C424D),
    surfaceContainerHighest: Color(0xFF464C57),
    surfaceDim: Color(0xFF22262E),
    surfaceBright: Color(0xFF505662),
    onSurfaceVariant: Color(0xFFE0D8CE),
    inverseSurface: Color(0xFFFFF8EE),
    onInverseSurface: Color(0xFF353943),
    inversePrimary: Color(0xFF775A19),
    outline: Color(0xFFADA69B),
    outlineVariant: Color(0xFF5E646F),
    surfaceTint: Color(0xFFFFD48A),
    shadow: Color(0xFF2A3140),
    scrim: Color(0xFF2A3140),
  );

  static ThemeData get lightTheme =>
      _build(lightColorScheme, _lightTextTheme, BrandColors.light);

  static ThemeData get darkTheme =>
      _build(darkColorScheme, _darkTextTheme, BrandColors.dark);

  static ThemeData _build(
    ColorScheme scheme,
    TextTheme textTheme,
    BrandColors brandColors,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      extensions: <ThemeExtension<dynamic>>[brandColors],
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 48),
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
        minimumSize: const Size(0, 48),
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
        minimumSize: const Size(0, 48),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      backgroundColor: scheme.surfaceContainerHigh,
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  /// Montserrat scale shared by light and dark themes — the dark theme is a
  /// tonal sibling of light (see DESIGN_lightmode.md, DESIGN_darkmode.md).
  static TextTheme get _lightTextTheme => _montserratTextTheme;
  static TextTheme get _darkTextTheme => _montserratTextTheme;

  static TextTheme get _montserratTextTheme {
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
}
