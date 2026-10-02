package aiux.compose

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * AIUX theme contract (plan §7) mapped onto Material3 primitives.
 *
 * Apps supply role values; the renderer translates them to platform
 * primitives. Dark/light ship from day one via [AIUXThemeProvider].
 * Font sizes use `sp`, so system large-font accessibility scaling applies
 * automatically; layout honors [AIUXDensity].
 */

@Immutable
data class AIUXColors(
    val background: Color,
    val surface: Color,
    val surfaceElevated: Color,
    val userSurface: Color,
    val assistantSurface: Color,
    val accent: Color,
    val accentForeground: Color,
    val muted: Color,
    val mutedForeground: Color,
    val border: Color,
    val destructive: Color,
    val destructiveForeground: Color,
    val success: Color,
    val warning: Color,
    val foreground: Color,
)

@Immutable
data class AIUXTypography(
    val body: TextStyle,
    val caption: TextStyle,
    val label: TextStyle,
    val heading: TextStyle,
    val title: TextStyle,
    val code: TextStyle,
)

@Immutable
data class AIUXSpacing(
    val xs: Dp = 4.dp,
    val sm: Dp = 8.dp,
    val md: Dp = 12.dp,
    val lg: Dp = 16.dp,
    val xl: Dp = 24.dp,
) {
    fun gap(name: String?): Dp = when (name) {
        "xs" -> xs; "sm" -> sm; "md" -> md; "lg" -> lg; "xl" -> xl; else -> md
    }
    fun padding(name: String?): Dp = when (name) {
        "none" -> 0.dp; "xs" -> xs; "sm" -> sm; "md" -> md; "lg" -> lg; else -> md
    }
}

@Immutable
data class AIUXRadii(
    val sm: Dp = 8.dp,
    val md: Dp = 12.dp,
    val lg: Dp = 20.dp,
) {
    fun radius(name: String?): Dp = when (name) {
        "sm" -> sm; "md" -> md; "lg" -> lg; "full" -> 999.dp; else -> md
    }
}

enum class AIUXMotion { Full, Reduced }

enum class AIUXDensityMode { Compact, Comfortable }

@Immutable
data class AIUXTheme(
    val colors: AIUXColors,
    val typography: AIUXTypography,
    val spacing: AIUXSpacing = AIUXSpacing(),
    val radii: AIUXRadii = AIUXRadii(),
    val motion: AIUXMotion = AIUXMotion.Full,
    val density: AIUXDensityMode = AIUXDensityMode.Comfortable,
) {
    companion object {
        private val m3Light = lightColorScheme()
        private val m3Dark = darkColorScheme()

        fun light(): AIUXTheme = fromM3(m3Light)
        fun dark(): AIUXTheme = fromM3(m3Dark)

        /** Map role defaults from a Material3 color scheme (plan §7 roles). */
        fun fromM3(c: androidx.compose.material3.ColorScheme): AIUXTheme = AIUXTheme(
            colors = AIUXColors(
                background = c.background,
                surface = c.surface,
                surfaceElevated = c.surfaceContainerHigh,
                userSurface = c.primaryContainer,
                assistantSurface = c.surfaceContainerHigh,
                accent = c.primary,
                accentForeground = c.onPrimary,
                muted = c.surfaceVariant,
                mutedForeground = c.onSurfaceVariant,
                border = c.outlineVariant,
                destructive = c.error,
                destructiveForeground = c.onError,
                success = Color(0xFF2E7D32).takeIf { c == m3Light } ?: Color(0xFF81C784),
                warning = Color(0xFFF9A825).takeIf { c == m3Light } ?: Color(0xFFFFD54F),
                foreground = c.onSurface,
            ),
            typography = AIUXTypography(
                body = TextStyle(fontSize = 15.sp, lineHeight = 22.sp),
                caption = TextStyle(fontSize = 12.sp, lineHeight = 16.sp),
                label = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
                heading = TextStyle(fontSize = 20.sp, lineHeight = 26.sp),
                title = TextStyle(fontSize = 17.sp, lineHeight = 23.sp),
                code = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 13.sp, lineHeight = 19.sp),
            ),
        )
    }
}

val LocalAIUXTheme = staticCompositionLocalOf { AIUXTheme.light() }

object AIUX {
    val theme: AIUXTheme
        @Composable get() = LocalAIUXTheme.current
}

/**
 * Installs the AIUX theme. Wraps content in [MaterialTheme] mapped from the
 * role colors so stock M3 components inside AI surfaces stay consistent.
 */
@Composable
fun AIUXThemeProvider(
    theme: AIUXTheme = if (isSystemInDarkTheme()) AIUXTheme.dark() else AIUXTheme.light(),
    content: @Composable () -> Unit,
) {
    val c = theme.colors
    val scheme = if (c.background.luminance() < 0.5f) darkColorScheme() else lightColorScheme()
    MaterialTheme(
        colorScheme = scheme.copy(
            background = c.background,
            surface = c.surface,
            surfaceContainerHigh = c.surfaceElevated,
            primary = c.accent,
            onPrimary = c.accentForeground,
            primaryContainer = c.userSurface,
            onSurface = c.foreground,
            surfaceVariant = c.muted,
            onSurfaceVariant = c.mutedForeground,
            outlineVariant = c.border,
            error = c.destructive,
            onError = c.destructiveForeground,
        ),
        content = { CompositionLocalProvider(LocalAIUXTheme provides theme, content = content) },
    )
}

private fun Color.luminance(): Float {
    // Relative luminance approximation for light/dark scheme selection.
    return (0.2126f * red + 0.7152f * green + 0.0722f * blue)
}
