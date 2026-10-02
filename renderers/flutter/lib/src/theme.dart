import 'package:flutter/material.dart';

import 'models.dart';
import 'surface_node.dart';

// MARK: - Theme contract (PLAN §7)
//
// Theme is platform-neutral: hosts supply semantic *roles*, never literal
// component styling. `AiuxThemeData` carries the full role contract — colors,
// typography, spacing, radius, motion, density — with separate light and
// dark palettes so both appearances work from day one.

/// The §7 color roles resolved for one appearance — what views consume.
class AiuxColors {
  const AiuxColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.userSurface,
    required this.assistantSurface,
    required this.accent,
    required this.accentForeground,
    required this.muted,
    required this.border,
    required this.destructive,
    required this.success,
    required this.warning,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color userSurface;
  final Color assistantSurface;
  final Color accent;
  final Color accentForeground;
  final Color muted;
  final Color border;
  final Color destructive;
  final Color success;
  final Color warning;

  /// Map a semantic tone onto a palette color.
  Color tone(AiuxTone? tone) => switch (tone) {
        AiuxTone.accent => accent,
        AiuxTone.success => success,
        AiuxTone.warning => warning,
        AiuxTone.destructive => destructive,
        _ => muted,
      };

  /// Map a status severity onto a palette color.
  Color statusLevel(AiuxStatusLevel? level) => switch (level) {
        AiuxStatusLevel.success => success,
        AiuxStatusLevel.warning => warning,
        AiuxStatusLevel.error => destructive,
        _ => accent,
      };
}

/// A color that adapts to light/dark appearance.
class AiuxColor {
  const AiuxColor({required this.light, required this.dark});

  const AiuxColor.same(Color color) : this(light: color, dark: color);

  final Color light;
  final Color dark;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// The §7 color roles, one adaptive value each.
class AiuxColorRoles {
  const AiuxColorRoles({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.userSurface,
    required this.assistantSurface,
    required this.accent,
    required this.accentForeground,
    required this.muted,
    required this.border,
    required this.destructive,
    required this.success,
    required this.warning,
  });

  final AiuxColor background;
  final AiuxColor surface;
  final AiuxColor surfaceElevated;
  final AiuxColor userSurface;
  final AiuxColor assistantSurface;
  final AiuxColor accent;
  final AiuxColor accentForeground;
  final AiuxColor muted;
  final AiuxColor border;
  final AiuxColor destructive;
  final AiuxColor success;
  final AiuxColor warning;

  AiuxColors resolve(Brightness brightness) => AiuxColors(
        background: background.resolve(brightness),
        surface: surface.resolve(brightness),
        surfaceElevated: surfaceElevated.resolve(brightness),
        userSurface: userSurface.resolve(brightness),
        assistantSurface: assistantSurface.resolve(brightness),
        accent: accent.resolve(brightness),
        accentForeground: accentForeground.resolve(brightness),
        muted: muted.resolve(brightness),
        border: border.resolve(brightness),
        destructive: destructive.resolve(brightness),
        success: success.resolve(brightness),
        warning: warning.resolve(brightness),
      );
}

/// The §7 typography roles, mapped onto `TextStyle`s.
class AiuxTypography {
  const AiuxTypography({
    required this.body,
    required this.caption,
    required this.label,
    required this.heading,
    required this.title,
    required this.code,
  });

  final TextStyle body;
  final TextStyle caption;
  final TextStyle label;
  final TextStyle heading;
  final TextStyle title;
  final TextStyle code;
}

/// The §7 spacing scale. Semantic tokens only — host supplies point values.
class AiuxSpacing {
  const AiuxSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  double gap(AiuxGap token) => switch (token) {
        AiuxGap.xs => xs,
        AiuxGap.sm => sm,
        AiuxGap.md => md,
        AiuxGap.lg => lg,
        AiuxGap.xl => xl,
      };

  double padding(AiuxPadding token) => switch (token) {
        AiuxPadding.none => 0,
        AiuxPadding.xs => xs,
        AiuxPadding.sm => sm,
        AiuxPadding.md => md,
        AiuxPadding.lg => lg,
      };
}

/// The §7 radius scale. `full` yields capsule geometry.
class AiuxRadiusTokens {
  const AiuxRadiusTokens(
      {this.sm = 6, this.md = 10, this.lg = 16, this.full = 999});

  final double sm;
  final double md;
  final double lg;
  final double full;

  double radius(AiuxRadius? token) => switch (token) {
        AiuxRadius.sm => sm,
        AiuxRadius.md => md,
        AiuxRadius.lg => lg,
        AiuxRadius.full => full,
        _ => 0,
      };
}

/// The §7 density scale — multiplies the spacing scale.
enum AiuxDensity {
  compact(0.8),
  regular(1.0),
  spacious(1.25);

  const AiuxDensity(this.factor);
  final double factor;
}

/// The complete AIUX theme. Views read it via `AiuxTheme.of(context)` and
/// resolve colors against the ambient `Theme` brightness.
class AiuxThemeData {
  const AiuxThemeData({
    required this.colors,
    required this.typography,
    this.spacing = const AiuxSpacing(),
    this.radius = const AiuxRadiusTokens(),
    this.motionDuration = const Duration(milliseconds: 180),
    this.density = AiuxDensity.regular,
  });

  final AiuxColorRoles colors;
  final AiuxTypography typography;
  final AiuxSpacing spacing;
  final AiuxRadiusTokens radius;

  /// Base transition duration (§7 motion). Every AIUX animation keys off it
  /// and is gated by `MediaQuery.disableAnimations`/reduce-motion at the
  /// call site.
  final Duration motionDuration;
  final AiuxDensity density;

  /// The palette for a given appearance.
  AiuxColors colorsFor(Brightness brightness) => colors.resolve(brightness);

  /// Density-scaled spacing lookup.
  double space(AiuxGap token) => spacing.gap(token) * density.factor;

  /// Density-scaled padding lookup.
  double padding(AiuxPadding? token) =>
      spacing.padding(token ?? AiuxPadding.none) * density.factor;

  /// The stock AIUX theme — neutral surfaces, a restrained accent, platform
  /// text styles. Hosts replace roles wholesale; they never restyle parts.
  static AiuxThemeData standard() {
    TextStyle ts(double size, {FontWeight? weight, bool mono = false}) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          fontFamily: mono ? 'monospace' : null,
        );
    return AiuxThemeData(
      colors: const AiuxColorRoles(
        background: AiuxColor(
          light: Color(0xFFFFFFFF),
          dark: Color(0xFF1A1A1C),
        ),
        surface: AiuxColor(
          light: Color(0xFFF5F5F7),
          dark: Color(0xFF29292E),
        ),
        surfaceElevated: AiuxColor(
          light: Color(0xFFFFFFFF),
          dark: Color(0xFF36363D),
        ),
        userSurface: AiuxColor(
          light: Color(0xFFE0EBFF),
          dark: Color(0xFF294070),
        ),
        assistantSurface: AiuxColor(
          light: Color(0xFFF0F0F5),
          dark: Color(0xFF303036),
        ),
        accent: AiuxColor(
          light: Color(0xFF336BDB),
          dark: Color(0xFF6699FA),
        ),
        accentForeground: AiuxColor(
          light: Color(0xFFFFFFFF),
          dark: Color(0xFF0F172B),
        ),
        muted: AiuxColor(
          light: Color(0xFF6B7079),
          dark: Color(0xFF9EA3AD),
        ),
        border: AiuxColor(
          light: Color(0xFFDBDDE3),
          dark: Color(0xFF52545C),
        ),
        destructive: AiuxColor(
          light: Color(0xFFD43D36),
          dark: Color(0xFFF0635C),
        ),
        success: AiuxColor(
          light: Color(0xFF299956),
          dark: Color(0xFF5CC280),
        ),
        warning: AiuxColor(
          light: Color(0xFFCC841A),
          dark: Color(0xFFF2B240),
        ),
      ),
      typography: AiuxTypography(
        body: ts(16),
        caption: ts(12),
        label: ts(15, weight: FontWeight.w500),
        heading: ts(17, weight: FontWeight.w600),
        title: ts(20, weight: FontWeight.w600),
        code: ts(14, mono: true),
      ),
    );
  }
}

/// Inherited theme scope. Wrap a subtree with `AiuxTheme(data: ..., child:)`
/// or rely on [AiuxThemeData.standard] when none is present.
class AiuxTheme extends InheritedWidget {
  const AiuxTheme({super.key, required this.data, required super.child});

  final AiuxThemeData data;

  static AiuxThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AiuxTheme>()?.data ??
      AiuxThemeData.standard();

  /// Resolved palette for the ambient brightness — the call every view makes.
  static AiuxColors colorsOf(BuildContext context) =>
      of(context).colorsFor(Theme.of(context).brightness);

  @override
  bool updateShouldNotify(AiuxTheme oldWidget) => data != oldWidget.data;
}
