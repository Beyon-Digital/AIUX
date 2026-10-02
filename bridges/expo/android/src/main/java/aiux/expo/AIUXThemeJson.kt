package aiux.expo

import aiux.compose.AIUXColors
import aiux.compose.AIUXDensityMode
import aiux.compose.AIUXMotion
import aiux.compose.AIUXRadii
import aiux.compose.AIUXSpacing
import aiux.compose.AIUXTheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Maps the JS `AIUXThemeInput` JSON onto `AIUXTheme` roles (plan §7). Colors
 * arrive as CSS-style strings (`#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb()`,
 * `rgba()`); roles missing from the payload keep the renderer's built-in
 * palette for the active scheme.
 */
internal object AIUXThemeJson {

    private val json = Json { ignoreUnknownKeys = true }

    /** `null` → caller uses `AIUXThemeProvider`'s system-scheme default. */
    fun parse(themeJson: String?, dark: Boolean): AIUXTheme? {
        if (themeJson.isNullOrBlank()) return null
        val root = runCatching { json.parseToJsonElement(themeJson).jsonObject }
            .getOrNull() ?: return null

        val base = if (dark) AIUXTheme.dark() else AIUXTheme.light()
        val scheme = root["colorScheme"]?.jsonPrimitive?.content
        val effectiveDark = when (scheme) {
            "light" -> false
            "dark" -> true
            else -> dark
        }
        val themed = if (effectiveDark == dark) base
            else if (effectiveDark) AIUXTheme.dark()
            else AIUXTheme.light()

        return AIUXTheme(
            colors = mergeColors(themed.colors, root["colors"], effectiveDark),
            typography = themed.typography,
            spacing = mergeSpacing(themed.spacing, root["spacing"]),
            radii = mergeRadii(themed.radii, root["radius"]),
            motion = mergeMotion(themed.motion, root["motion"]),
            density = mergeDensity(themed.density, root["density"]),
        )
    }

    /** Flat palette or `{light, dark}` split; missing roles keep the base. */
    private fun mergeColors(
        base: AIUXColors,
        element: JsonElement?,
        dark: Boolean,
    ): AIUXColors {
        val obj = element as? JsonObject ?: return base
        val scoped = obj["light"] is JsonObject || obj["dark"] is JsonObject
        val source = if (scoped) {
            (obj[if (dark) "dark" else "light"] as? JsonObject) ?: return base
        } else {
            obj
        }
        return AIUXColors(
            background = source.colorOr("background") ?: base.background,
            surface = source.colorOr("surface") ?: base.surface,
            surfaceElevated = source.colorOr("surfaceElevated") ?: base.surfaceElevated,
            userSurface = source.colorOr("userSurface") ?: base.userSurface,
            assistantSurface = source.colorOr("assistantSurface") ?: base.assistantSurface,
            accent = source.colorOr("accent") ?: base.accent,
            accentForeground = source.colorOr("accentForeground") ?: base.accentForeground,
            muted = source.colorOr("muted") ?: base.muted,
            mutedForeground = source.colorOr("mutedForeground") ?: base.mutedForeground,
            border = source.colorOr("border") ?: base.border,
            destructive = source.colorOr("destructive") ?: base.destructive,
            destructiveForeground = source.colorOr("destructiveForeground") ?: base.destructiveForeground,
            success = source.colorOr("success") ?: base.success,
            warning = source.colorOr("warning") ?: base.warning,
            foreground = source.colorOr("foreground") ?: base.foreground,
        )
    }

    private fun mergeSpacing(base: AIUXSpacing, element: JsonElement?): AIUXSpacing {
        val obj = element as? JsonObject ?: return base
        return AIUXSpacing(
            xs = obj.dpOr("xs") ?: base.xs,
            sm = obj.dpOr("sm") ?: base.sm,
            md = obj.dpOr("md") ?: base.md,
            lg = obj.dpOr("lg") ?: base.lg,
            xl = obj.dpOr("xl") ?: base.xl,
        )
    }

    private fun mergeRadii(base: AIUXRadii, element: JsonElement?): AIUXRadii {
        val obj = element as? JsonObject ?: return base
        return AIUXRadii(
            sm = obj.dpOr("sm") ?: base.sm,
            md = obj.dpOr("md") ?: base.md,
            lg = obj.dpOr("lg") ?: base.lg,
        )
    }

    private fun mergeMotion(base: AIUXMotion, element: JsonElement?): AIUXMotion {
        if (element?.jsonPrimitive?.content == "reduced") return AIUXMotion.Reduced
        if (element?.jsonPrimitive?.content == "full") return AIUXMotion.Full
        val obj = element as? JsonObject ?: return base
        if (obj["duration"]?.jsonPrimitive?.doubleOrNull == 0.0) return AIUXMotion.Reduced
        return base
    }

    private fun mergeDensity(base: AIUXDensityMode, element: JsonElement?): AIUXDensityMode =
        when (element?.jsonPrimitive?.content) {
            "compact" -> AIUXDensityMode.Compact
            else -> base
        }

    private fun JsonObject.colorOr(role: String): Color? =
        this[role]?.jsonPrimitive?.content?.let(::parseColor)

    private fun JsonObject.dpOr(key: String) =
        this[key]?.jsonPrimitive?.doubleOrNull?.toFloat()?.dp

    /** `#rgb` / `#rrggbb` / `#rrggbbaa` / `rgb(r,g,b)` / `rgba(r,g,b,a)`. */
    internal fun parseColor(value: String): Color? {
        val raw = value.trim()
        if (raw.startsWith("#")) {
            val hex = raw.drop(1)
            val long = when (hex.length) {
                3 -> hex.map { "$it$it" }.joinToString("")
                6, 8 -> hex
                else -> return null
            }
            val argb = if (long.length == 6) "FF$long" else long
            return runCatching {
                Color(android.graphics.Color.parseColor("#$argb"))
            }.getOrNull()
        }
        val match = Regex("""rgba?\(([^)]+)\)""").find(raw) ?: return null
        val parts = match.groupValues[1].split(",").map { it.trim().toFloatOrNull() }
        if (parts.size < 3 || parts.take(3).any { it == null }) return null
        val alpha = (parts.getOrNull(3) ?: 1f).let { if (it!! > 1f) it / 255f else it }
        return Color(
            red = (parts[0]!! / 255f).coerceIn(0f, 1f),
            green = (parts[1]!! / 255f).coerceIn(0f, 1f),
            blue = (parts[2]!! / 255f).coerceIn(0f, 1f),
            alpha = alpha.coerceIn(0f, 1f),
        )
    }
}
