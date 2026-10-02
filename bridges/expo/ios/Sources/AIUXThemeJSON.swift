import Foundation
import SwiftUI
import UIKit

/// Maps the JS `AIUXThemeInput` JSON onto `AIUXTheme` roles (plan §7). Colors
/// arrive as CSS-style strings (`#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb()`,
/// `rgba()`); roles missing from the payload keep the renderer's defaults.
enum AIUXThemeJSON {

    private struct Payload: Decodable {
        struct ColorRoles: Decodable {
            var light: [String: String]?
            var dark: [String: String]?
        }

        var colors: Colors?
        var spacing: [String: Double]?
        var radius: [String: Double]?
        var motion: Motion?
        var density: String?
        var colorScheme: String?

        enum Colors: Decodable {
            case flat([String: String])
            case scoped(ColorRoles)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let scoped = try? container.decode(ColorRoles.self),
                    scoped.light != nil || scoped.dark != nil
                {
                    self = .scoped(scoped)
                } else {
                    self = .flat((try? container.decode([String: String].self)) ?? [:])
                }
            }
        }

        enum Motion: Decodable {
            case reduced
            case object(duration: Double?)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(String.self) {
                    self = .reduced
                    return
                }
                let object = try? container.decode([String: Double].self)
                self = .object(duration: object?["duration"])
            }
        }
    }

    static func parse(_ themeJson: String) -> AIUXTheme? {
        guard
            let payload = try? JSONDecoder().decode(
                Payload.self, from: Data(themeJson.utf8)
            )
        else { return nil }

        var theme = AIUXTheme.default
        theme.colors = mergeColors(base: theme.colors, colors: payload.colors)
        theme.spacing = mergeSpacing(base: theme.spacing, values: payload.spacing)
        theme.radius = mergeRadius(base: theme.radius, values: payload.radius)
        if let motion = payload.motion {
            switch motion {
            case .reduced:
                theme.motion = AIUXMotion(duration: 0)
            case .object(let duration):
                if let duration {
                    theme.motion = AIUXMotion(duration: duration)
                }
            }
        }
        if let density = payload.density,
            let parsed = AIUXDensity(rawValue: density)
        {
            theme.density = parsed
        }
        return theme
    }

    // MARK: - Role merging

    private static func mergeColors(
        base: AIUXColorRoles, colors: Payload.Colors?
    ) -> AIUXColorRoles {
        guard let colors else { return base }
        var roles = base

        func roleColor(_ key: String) -> (light: String?, dark: String?) {
            switch colors {
            case .flat(let flat):
                return (flat[key], flat[key])
            case .scoped(let scoped):
                return (scoped.light?[key], scoped.dark?[key])
            }
        }

        for role in [
            "background", "surface", "surfaceElevated", "userSurface",
            "assistantSurface", "accent", "accentForeground", "muted",
            "border", "destructive", "success", "warning",
        ] {
            let (light, dark) = roleColor(role)
            guard light != nil || dark != nil else { continue }
            let color = AIUXColor(
                light: parseColor(light ?? dark!) ?? Color.primary,
                dark: parseColor(dark ?? light!) ?? Color.primary
            )
            switch role {
            case "background": roles.background = color
            case "surface": roles.surface = color
            case "surfaceElevated": roles.surfaceElevated = color
            case "userSurface": roles.userSurface = color
            case "assistantSurface": roles.assistantSurface = color
            case "accent": roles.accent = color
            case "accentForeground": roles.accentForeground = color
            case "muted": roles.muted = color
            case "border": roles.border = color
            case "destructive": roles.destructive = color
            case "success": roles.success = color
            case "warning": roles.warning = color
            default: break
            }
        }
        return roles
    }

    private static func mergeSpacing(
        base: AIUXSpacing, values: [String: Double]?
    ) -> AIUXSpacing {
        guard let values else { return base }
        var spacing = base
        spacing.xs = values["xs"].map(CGFloat.init) ?? spacing.xs
        spacing.sm = values["sm"].map(CGFloat.init) ?? spacing.sm
        spacing.md = values["md"].map(CGFloat.init) ?? spacing.md
        spacing.lg = values["lg"].map(CGFloat.init) ?? spacing.lg
        spacing.xl = values["xl"].map(CGFloat.init) ?? spacing.xl
        return spacing
    }

    private static func mergeRadius(
        base: AIUXRadiusTokens, values: [String: Double]?
    ) -> AIUXRadiusTokens {
        guard let values else { return base }
        var radius = base
        radius.sm = values["sm"].map(CGFloat.init) ?? radius.sm
        radius.md = values["md"].map(CGFloat.init) ?? radius.md
        radius.lg = values["lg"].map(CGFloat.init) ?? radius.lg
        radius.full = values["full"].map(CGFloat.init) ?? radius.full
        return radius
    }

    // MARK: - Color parsing

    /// `#rgb` / `#rrggbb` / `#rrggbbaa` / `rgb(r,g,b)` / `rgba(r,g,b,a)`.
    static func parseColor(_ value: String) -> Color? {
        let raw = value.trimmingCharacters(in: .whitespaces)
        if raw.hasPrefix("#") {
            var hex = String(raw.dropFirst())
            if hex.count == 3 {
                hex = hex.map { "\($0)\($0)" }.joined()
            }
            guard hex.count == 6 || hex.count == 8,
                let bits = UInt64(hex, radix: 16)
            else { return nil }
            let hasAlpha = hex.count == 8
            let r = Double((bits >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
            let g = Double((bits >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
            let b = Double((bits >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
            let a = hasAlpha ? Double(bits & 0xFF) / 255 : 1
            return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        }
        let pattern = #"rgba?\(([^)]+)\)"#
        guard let match = raw.range(of: pattern, options: .regularExpression)
        else { return nil }
        let parts = String(raw[match])
            .trimmingCharacters(in: CharacterSet(charactersIn: "rgba()"))
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 3 else { return nil }
        let alpha = parts.count > 3 ? (parts[3] > 1 ? parts[3] / 255 : parts[3]) : 1
        return Color(
            .sRGB,
            red: parts[0] / 255, green: parts[1] / 255, blue: parts[2] / 255,
            opacity: alpha
        )
    }
}
