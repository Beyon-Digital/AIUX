package aiux.compose.components

import androidx.compose.runtime.Composable

/**
 * Composer toolbar customization contract (§23): hosts control which
 * built-in controls render and may append custom tools to the controls
 * row. Every control reports upward as an `AIUXAction` — custom tools
 * emit the `id` they were declared with (`aiux.composer.<name>` by
 * convention).
 *
 * ```kotlin
 * AIConversation(
 *     snapshot = snapshot,
 *     composerToolbar = AIComposerToolbar(
 *         dictate = false,
 *         extra = listOf(
 *             AIComposerTool(
 *                 id = "aiux.composer.docs",
 *                 contentDescription = "attach docs",
 *                 glyph = AIComposerGlyph.Document,
 *             ),
 *         ),
 *     ),
 * )
 * ```
 */
data class AIComposerToolbar(
    /** Show the `+` attach control (emits `aiux.composer.attach`). */
    val attach: Boolean = true,
    /** Show the accent-ringed tools toggle (emits `aiux.composer.tools`). */
    val tools: Boolean = true,
    /** Show the outline mic (emits `aiux.composer.dictate`). */
    val dictate: Boolean = true,
    /**
     * Custom tools appended between the built-ins and the action circle.
     * Tapping one emits `AIUXAction(id)` — the host owns the behavior.
     */
    val extra: List<AIComposerTool> = emptyList(),
) {
    companion object {
        val Default = AIComposerToolbar()
    }
}

/**
 * One custom control in the composer toolbar.
 *
 * @param id action id emitted on tap (the host routes it like any other
 *   `AIUXAction` — prefix `aiux.composer.` by convention).
 * @param contentDescription accessibility label (also the uiautomator
 *   selector in tests).
 * @param glyph stock icon to draw when [icon] is null.
 * @param icon optional fully-custom composable icon (overrides [glyph]).
 */
data class AIComposerTool(
    val id: String,
    val contentDescription: String,
    val glyph: AIComposerGlyph = AIComposerGlyph.Sparkle,
    val icon: (@Composable () -> Unit)? = null,
)

/**
 * Stock glyphs a custom tool can pick without shipping its own icon.
 * The same vocabulary is serializable across the Expo boundary.
 */
enum class AIComposerGlyph {
    Sparkle,
    Document,
    Photo,
    Gear,
    Globe,
    Mic,
    Search,
    Plus,
    Star,
}
