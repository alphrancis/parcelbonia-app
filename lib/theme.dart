import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens copied from the website's dashboard.css
/// (`:root`, `[data-theme='light']` and the --mode-* variables).
@immutable
class PB extends ThemeExtension<PB> {
  final Color ink, surface, surfaceRaised, line, muted, text, paper;
  final Color accent, accentHover, accentDim, danger;
  final Color modeAuto, modeMaintenance, modeSleep;
  final bool isDark;

  const PB({
    required this.ink,
    required this.surface,
    required this.surfaceRaised,
    required this.line,
    required this.muted,
    required this.text,
    required this.accentDim,
    required this.modeAuto,
    required this.modeMaintenance,
    required this.modeSleep,
    required this.isDark,
    this.paper = const Color(0xFFF0EBE1),
    this.accent = const Color(0xFF22C55E),
    this.accentHover = const Color(0xFF29D868),
    this.danger = const Color(0xFFF97316),
  });

  // Liquid glass palette: `surface` and `line` are translucent so every
  // container lets the ambient backdrop show through; `surfaceRaised` is a
  // near-opaque frosted tone for menus, dialogs and toasts.
  static const dark = PB(
    ink: Color(0xFF06080B),
    surface: Color(0x17FFFFFF),
    surfaceRaised: Color(0xEB1C1F24),
    line: Color(0x1FFFFFFF),
    muted: Color(0xFF9B9BA3),
    text: Color(0xFFF5F5F7),
    accentDim: Color(0x2930D158),
    modeAuto: Color(0xFF30D158),
    modeMaintenance: Color(0xFFFF9F0A),
    modeSleep: Color(0xFFFF453A),
    isDark: true,
    accent: Color(0xFF30D158),
    accentHover: Color(0xFF4ADE6D),
    danger: Color(0xFFFF6B3D),
  );

  static const light = PB(
    ink: Color(0xFFEDF1F6),
    surface: Color(0x99FFFFFF),
    surfaceRaised: Color(0xF5FBFBFD),
    line: Color(0x17000000),
    muted: Color(0xFF6E6E76),
    text: Color(0xFF1C1C1E),
    accentDim: Color(0x2224B04A),
    modeAuto: Color(0xFF1FA046),
    modeMaintenance: Color(0xFFD97706),
    modeSleep: Color(0xFFE5342B),
    isDark: false,
    accent: Color(0xFF24B04A),
    accentHover: Color(0xFF2CC556),
    danger: Color(0xFFE5562B),
  );

  /// CSS `color-mix(in srgb, a p%, b)`.
  static Color mix(Color a, double p, Color b) => Color.lerp(b, a, p)!;

  /// `color-mix(in srgb, c p%, transparent)`.
  static Color tint(Color c, double p) => c.withValues(alpha: c.a * p);

  @override
  PB copyWith() => this;

  @override
  PB lerp(PB? other, double t) => t < .5 ? this : (other ?? this);
}

extension PBContext on BuildContext {
  PB get pb => Theme.of(this).extension<PB>()!;
}

/// Headings and numbers — Inter Display-style tight tracking, close to SF Pro.
TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w700, double spacing = -.035}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, letterSpacing: size * spacing, height: 1.12);

/// Inter — body copy (`--font-body`).
TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w400, double? spacing, double? height}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: height);

ThemeData buildTheme(bool dark) {
  final pb = dark ? PB.dark : PB.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: pb.accent,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: pb.accent, onPrimary: const Color(0xFF07150B), surface: pb.surface, onSurface: pb.text);
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: pb.ink,
    splashFactory: InkSparkle.splashFactory,
    popupMenuTheme: PopupMenuThemeData(
      color: pb.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: pb.line)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pb.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: pb.line)),
    ),
    dividerColor: pb.line,
    textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: dark ? Brightness.dark : Brightness.light).textTheme)
        .apply(bodyColor: pb.text, displayColor: pb.text),
    textSelectionTheme: TextSelectionThemeData(cursorColor: pb.accent, selectionColor: pb.accentDim),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: pb.surfaceRaised,
      contentTextStyle: body(12, color: pb.text, weight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: pb.line)),
    ),
    extensions: [pb],
  );
}
