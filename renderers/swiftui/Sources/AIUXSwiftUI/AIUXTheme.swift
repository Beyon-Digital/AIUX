import SwiftUI

// MARK: - Theme contract (plan §7)
//
// Theme is platform-neutral: hosts supply semantic *roles*, never literal
// component styling. `AIUXTheme` carries the full role contract — colors,
// typography, spacing, radius, motion, density — with separate light and
// dark palettes so both appearances work from day one.

/// A color that adapts to light/dark appearance.
public struct AIUXColor {
    public var light: Color
    public var dark: Color

    public init(light: Color, dark: Color) {
        self.light = light
        self.dark = dark
    }

    /// One color for both appearances.
    public init(_ color: Color) {
        self.init(light: color, dark: color)
    }

    /// Build from 8-bit sRGB channels per appearance.
    public init(
        light: (r: Double, g: Double, b: Double, a: Double),
        dark: (r: Double, g: Double, b: Double, a: Double)
    ) {
        self.init(
            light: Color(.sRGB, red: light.r, green: light.g, blue: light.b, opacity: light.a),
            dark: Color(.sRGB, red: dark.r, green: dark.g, blue: dark.b, opacity: dark.a)
        )
    }

    public func resolve(in scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }
}

/// The §7 color roles, mapped onto SwiftUI `Color`s per appearance.
public struct AIUXColorRoles {
    public var background: AIUXColor
    public var surface: AIUXColor
    public var surfaceElevated: AIUXColor
    public var userSurface: AIUXColor
    public var assistantSurface: AIUXColor
    public var accent: AIUXColor
    public var accentForeground: AIUXColor
    public var muted: AIUXColor
    public var border: AIUXColor
    public var destructive: AIUXColor
    public var success: AIUXColor
    public var warning: AIUXColor

    /// Secondary text/icon tone derived from `muted` by default.
    public func foreground(in scheme: ColorScheme) -> Color {
        muted.resolve(in: scheme)
    }
}

/// The §7 typography roles, mapped onto SwiftUI `Font`s. All defaults use
/// dynamic text styles so Dynamic Type scaling works unchanged.
public struct AIUXTypography {
    public var body: Font
    public var caption: Font
    public var label: Font
    public var heading: Font
    public var title: Font
    public var code: Font
}

/// The §7 spacing scale. Semantic tokens only — host supplies point values.
public struct AIUXSpacing: Equatable, Sendable {
    public var xs: CGFloat
    public var sm: CGFloat
    public var md: CGFloat
    public var lg: CGFloat
    public var xl: CGFloat

    public func gap(_ token: AIUXGap) -> CGFloat {
        switch token {
        case .xs: return xs
        case .sm: return sm
        case .md: return md
        case .lg: return lg
        case .xl: return xl
        }
    }

    public func padding(_ token: AIUXPadding) -> CGFloat {
        switch token {
        case .none: return 0
        case .xs: return xs
        case .sm: return sm
        case .md: return md
        case .lg: return lg
        }
    }
}

/// The §7 radius scale. `full` yields capsule geometry.
public struct AIUXRadiusTokens: Equatable, Sendable {
    public var sm: CGFloat
    public var md: CGFloat
    public var lg: CGFloat
    /// Applied to `Capsule`-style elements; a large finite value so it also
    /// works as a `RoundedRectangle` radius.
    public var full: CGFloat

    public func radius(_ token: AIUXRadius?) -> CGFloat {
        switch token {
        case .none: return 0
        case .sm: return sm
        case .md: return md
        case .lg: return lg
        case .full: return full
        }
    }
}

/// The §7 motion contract. All animations key off `duration` and must be
/// gated by `accessibilityReduceMotion` at the call site.
public struct AIUXMotion {
    /// Base transition duration in seconds.
    public var duration: Double

    /// The standard AIUX transition (streaming deltas, surface updates).
    public var standard: Animation {
        .easeOut(duration: duration)
    }

    /// A motion-respecting variant of `animation(_:value:)`.
    public func animation<V: Equatable>(reduced: Bool, value: V) -> Animation? {
        reduced ? nil : standard
    }
}

/// The §7 density scale — multiplies the spacing scale.
public enum AIUXDensity: String, Equatable, Sendable {
    case compact, regular, spacious

    public var factor: CGFloat {
        switch self {
        case .compact: return 0.8
        case .regular: return 1.0
        case .spacious: return 1.25
        }
    }
}

/// The complete AIUX theme. Views read it via `@Environment(\.aiuxTheme)` and
/// resolve colors against `@Environment(\.colorScheme)`.
public struct AIUXTheme {
    public var colors: AIUXColorRoles
    public var typography: AIUXTypography
    public var spacing: AIUXSpacing
    public var radius: AIUXRadiusTokens
    public var motion: AIUXMotion
    public var density: AIUXDensity

    /// The palette for a given appearance.
    public func colors(for scheme: ColorScheme) -> AIUXResolvedColors {
        AIUXResolvedColors(roles: colors, scheme: scheme)
    }

    /// Density-scaled spacing lookup.
    public func space(_ token: AIUXGap) -> CGFloat {
        spacing.gap(token) * density.factor
    }

    /// Density-scaled padding lookup.
    public func padding(_ token: AIUXPadding?) -> CGFloat {
        spacing.padding(token ?? .none) * density.factor
    }
}

/// The color roles already resolved for one appearance — what views consume.
public struct AIUXResolvedColors {
    public var background: Color
    public var surface: Color
    public var surfaceElevated: Color
    public var userSurface: Color
    public var assistantSurface: Color
    public var accent: Color
    public var accentForeground: Color
    public var muted: Color
    public var border: Color
    public var destructive: Color
    public var success: Color
    public var warning: Color

    init(roles: AIUXColorRoles, scheme: ColorScheme) {
        background = roles.background.resolve(in: scheme)
        surface = roles.surface.resolve(in: scheme)
        surfaceElevated = roles.surfaceElevated.resolve(in: scheme)
        userSurface = roles.userSurface.resolve(in: scheme)
        assistantSurface = roles.assistantSurface.resolve(in: scheme)
        accent = roles.accent.resolve(in: scheme)
        accentForeground = roles.accentForeground.resolve(in: scheme)
        muted = roles.muted.resolve(in: scheme)
        border = roles.border.resolve(in: scheme)
        destructive = roles.destructive.resolve(in: scheme)
        success = roles.success.resolve(in: scheme)
        warning = roles.warning.resolve(in: scheme)
    }
}

// MARK: - Defaults

extension AIUXTheme {
    /// The stock AIUX theme — neutral surfaces, a restrained accent, platform
    /// text styles. Hosts replace roles wholesale; they never restyle parts.
    public static let `default` = AIUXTheme(
        colors: AIUXColorRoles(
            background: AIUXColor(
                light: (1.0, 1.0, 1.0, 1.0),
                dark: (0.129, 0.129, 0.129, 1.0)
            ),
            surface: AIUXColor(
                light: (0.957, 0.957, 0.961, 1.0),
                dark: (0.188, 0.188, 0.188, 1.0)
            ),
            surfaceElevated: AIUXColor(
                light: (1.0, 1.0, 1.0, 1.0),
                dark: (0.208, 0.208, 0.22, 1.0)
            ),
            userSurface: AIUXColor(
                light: (0.925, 0.925, 0.945, 1.0),
                dark: (0.227, 0.227, 0.227, 1.0)
            ),
            assistantSurface: AIUXColor(.clear),
            accent: AIUXColor(
                light: (0.05, 0.05, 0.05, 1.0),
                dark: (1.0, 1.0, 1.0, 1.0)
            ),
            accentForeground: AIUXColor(
                light: (1.0, 1.0, 1.0, 1.0),
                dark: (0.05, 0.05, 0.05, 1.0)
            ),
            muted: AIUXColor(
                light: (0.44, 0.44, 0.44, 1.0),
                dark: (0.706, 0.706, 0.706, 1.0)
            ),
            border: AIUXColor(
                light: (0.902, 0.902, 0.902, 1.0),
                dark: (0.259, 0.259, 0.259, 1.0)
            ),
            destructive: AIUXColor(
                light: (0.851, 0.176, 0.125, 1.0),
                dark: (0.976, 0.439, 0.4, 1.0)
            ),
            success: AIUXColor(
                light: (0.16, 0.60, 0.34, 1.0),
                dark: (0.36, 0.76, 0.50, 1.0)
            ),
            warning: AIUXColor(
                light: (0.80, 0.52, 0.10, 1.0),
                dark: (0.95, 0.70, 0.25, 1.0)
            )
        ),
        typography: AIUXTypography(
            body: .body,
            caption: .caption,
            label: .callout.weight(.medium),
            heading: .headline,
            title: .title3.weight(.semibold),
            code: .callout.monospaced()
        ),
        spacing: AIUXSpacing(xs: 4, sm: 8, md: 12, lg: 16, xl: 24),
        radius: AIUXRadiusTokens(sm: 6, md: 10, lg: 16, full: 999),
        motion: AIUXMotion(duration: 0.18),
        density: .regular
    )
}

// MARK: - Environment

private struct AIUXThemeKey: EnvironmentKey {
    static let defaultValue: AIUXTheme = .default
}

extension EnvironmentValues {
    /// The active AIUX theme; set with `.aiuxTheme(_:)`.
    public var aiuxTheme: AIUXTheme {
        get { self[AIUXThemeKey.self] }
        set { self[AIUXThemeKey.self] = newValue }
    }
}

extension View {
    /// Apply an AIUX theme to a subtree.
    public func aiuxTheme(_ theme: AIUXTheme) -> some View {
        environment(\.aiuxTheme, theme)
    }
}
