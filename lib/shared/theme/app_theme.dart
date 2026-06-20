import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../../main.dart'; // import sharedPreferences

// Provider para controlar el modo del tema (Claro/Oscuro/Sistema) de manera global
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final savedMode = sharedPreferences.getString('theme_mode');
    if (savedMode != null) {
      return ThemeMode.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => ThemeMode.dark,
      );
    }
    return ThemeMode.dark;
  }

  @override
  set state(ThemeMode val) {
    super.state = val;
    sharedPreferences.setString('theme_mode', val.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class AppTheme {
  // Colores principales de alta fidelidad (Estética Metálica & Neón Suave)
  static const Color primaryDark = Color(0xFF4A84E6);      // Soft Cyber Metallic Blue
  static const Color secondaryDark = Color(0xFF6B849E);    // Steel Slate Blue
  static const Color tertiaryDark = Color(0xFF8697AB);     // Soft Steel Gray
  static const Color backgroundDark = Color(0xFF1A1F2C);   // Obsidian Slate Black (Slightly lighter/grayer slate black)
  static const Color surfaceDark = Color(0xFF242B3D);      // Floating Card Surface base (Slightly lighter to stand out)

  static const Color primaryLight = Color(0xFF2E61D8);     // Royal Metallic Blue
  static const Color secondaryLight = Color(0xFF55657A);   // Steel Slate
  static const Color tertiaryLight = Color(0xFF708096);    // Slate Gray
  static const Color backgroundLight = Color(0xFFF1F5F9);  // Clean Slate Gray-White
  static const Color surfaceLight = Color(0xFFFFFFFF);     // Pure White Card

  // Colores heredados/compatibilidad
  static const Color primaryColor = Color(0xFF4A84E6);
  static const Color secondaryColor = Color(0xFF6B849E);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF5F5F5); // Mantener temporalmente por compatibilidad
  static const Color textSecondary = Color(0xFFB0B0C0); // Mantener temporalmente por compatibilidad
  static const Color cardColor = Color(0xFF242B3D);
  static const Color surfaceColor = Color(0xFF1A1F2C);

  // Esquema de colores personalizado para FlexColorScheme
  static const FlexSchemeColor _customSchemeDark = FlexSchemeColor(
    primary: primaryDark,
    primaryContainer: Color(0xFF1E3A8A),
    secondary: secondaryDark,
    secondaryContainer: Color(0xFF334155),
    tertiary: tertiaryDark,
    tertiaryContainer: Color(0xFF475569),
    appBarColor: backgroundDark,
    error: errorColor,
  );

  static const FlexSchemeColor _customSchemeLight = FlexSchemeColor(
    primary: primaryLight,
    primaryContainer: Color(0xFFDBEAFE),
    secondary: secondaryLight,
    secondaryContainer: Color(0xFFE2E8F0),
    tertiary: tertiaryLight,
    tertiaryContainer: Color(0xFFF1F5F9),
    appBarColor: backgroundLight,
    error: Color(0xFFEF4444),
  );

  // Tema Claro
  static ThemeData lightTheme() {
    return FlexThemeData.light(
      colors: _customSchemeLight,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: false,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        cardRadius: 20,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 16,
        inputDecoratorFocusedHasBorder: true,
        inputDecoratorUnfocusedHasBorder: true,
        elevatedButtonRadius: 16,
        elevatedButtonSchemeColor: SchemeColor.primary,
        elevatedButtonSecondarySchemeColor: SchemeColor.onPrimary,
      ),
      keyColors: const FlexKeyColors(
        useSecondary: true,
        useTertiary: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: GoogleFonts.outfit().fontFamily,
      scaffoldBackground: backgroundLight,
    ).copyWith(
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceLight.withValues(alpha: 0.8),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.02),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
    );
  }

  // Tema Oscuro
  static ThemeData darkTheme() {
    return FlexThemeData.dark(
      colors: _customSchemeDark,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: false,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        cardRadius: 20,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 16,
        inputDecoratorFocusedHasBorder: true,
        inputDecoratorUnfocusedHasBorder: true,
        elevatedButtonRadius: 16,
        elevatedButtonSchemeColor: SchemeColor.primary,
        elevatedButtonSecondarySchemeColor: SchemeColor.onPrimary,
      ),
      keyColors: const FlexKeyColors(
        useSecondary: true,
        useTertiary: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: GoogleFonts.outfit().fontFamily,
      scaffoldBackground: backgroundDark,
    ).copyWith(
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark.withValues(alpha: 0.65), // Glassmorphic card fill
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)), // Thin reflective border
        ),
      ),
      // Estilo retro-futurista adicional para textos específicos
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFFE2E2EC)),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFFA5A5B5)),
      ),
    );
  }
}

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool isBottomSheet;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.isBottomSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final border = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : primaryColor.withValues(alpha: 0.12),
      width: 1.5,
    );

    final glowShadow = BoxShadow(
      color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
      blurRadius: 30,
      spreadRadius: 2,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: isBottomSheet
            ? BorderRadius.vertical(top: Radius.circular(borderRadius))
            : BorderRadius.circular(borderRadius),
        boxShadow: [glowShadow],
      ),
      child: ClipRRect(
        borderRadius: isBottomSheet
            ? BorderRadius.vertical(top: Radius.circular(borderRadius))
            : BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF2D374E).withValues(alpha: 0.75), // Slate Blue-Gray
                        const Color(0xFF1B2230).withValues(alpha: 0.65), // Dark Slate
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.9),
                        const Color(0xFFE6EDF5).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: isBottomSheet
                  ? BorderRadius.vertical(top: Radius.circular(borderRadius))
                  : BorderRadius.circular(borderRadius),
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
