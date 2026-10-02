package aiux.expo

import aiux.compose.AIUXThemeProvider
import aiux.compose.components.AIComposerGlyph
import aiux.compose.components.AIComposerTool
import aiux.compose.components.AIComposerToolbar
import aiux.compose.components.AIConversation
import aiux.compose.components.AIConversationMode
import android.content.Context
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView
import kotlinx.coroutines.flow.sample
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject

/**
 * Hosts the complete Compose `AIConversation` surface behind the Expo view
 * boundary. Props are JSON-typed (theme) or scalars (mode/sessionId); every
 * callback crosses back as an event — JS never lays out the UI (plan §10).
 */
class AIConversationView(context: Context, appContext: AppContext) :
    ExpoView(context, appContext) {

    private val onAction by EventDispatcher()
    private val onError by EventDispatcher()
    private val onSnapshot by EventDispatcher()

    private var sessionId by mutableStateOf<String?>(null)
    private var themeJson by mutableStateOf<String?>(null)
    private var mode by mutableStateOf(AIConversationMode.Fullscreen)
    private var showComposer by mutableStateOf(true)
    private var composerToolbarJson by mutableStateOf<String?>(null)

    private val composeView = ComposeView(context).apply {
        setViewCompositionStrategy(
            ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed,
        )
        setContent { AIConversationContent() }
    }

    init {
        addView(
            composeView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
        )
    }

    fun applySessionId(value: String) {
        sessionId = value
    }

    fun applyThemeJson(value: String) {
        themeJson = value
    }

    fun applyMode(value: String) {
        mode = when (value) {
            "embedded" -> AIConversationMode.Embedded
            else -> AIConversationMode.Fullscreen
        }
    }

    fun applyShowComposer(value: Boolean) {
        showComposer = value
    }

    fun applyComposerToolbarJson(value: String) {
        composerToolbarJson = value
    }

    @Composable
    private fun AIConversationContent() {
        val id = sessionId ?: return
        // Re-resolve the store when a restore replaces it for this id —
        // remember(id) alone would keep the pre-restore store forever.
        val generation by AIUXSessionRegistry.generationFlow(id)
            .collectAsStateWithLifecycle()
        val store = androidx.compose.runtime.remember(id, generation) {
            AIUXSessionRegistry.getOrCreate(id)
        }
        val snapshot by store.snapshot.collectAsStateWithLifecycle()
        val dark = isSystemInDarkTheme()
        val theme = androidx.compose.runtime.remember(themeJson, dark) {
            AIUXThemeJson.parse(themeJson, dark)
        }
        val composerToolbar = androidx.compose.runtime.remember(composerToolbarJson) {
            parseComposerToolbar(composerToolbarJson)
        }

        val content: @Composable () -> Unit = {
            AIConversation(
                snapshot = snapshot,
                modifier = Modifier.fillMaxSize(),
                mode = mode,
                showComposer = showComposer,
                composerToolbar = composerToolbar,
                onAction = { action ->
                    onAction(
                        mapOf(
                            "id" to action.id,
                            "payloadJson" to action.payload.toString(),
                        ),
                    )
                },
            )
        }
        // Always wrap — with no `theme` prop the provider's default still
        // follows the system scheme; bare content() would pin light.
        if (theme != null) {
            AIUXThemeProvider(theme = theme, content = content)
        } else {
            AIUXThemeProvider(content = content)
        }

        LaunchedEffect(store) {
            store.snapshotJson.sample(SNAPSHOT_EVENT_THROTTLE_MS).collect { raw ->
                onSnapshot(mapOf("snapshotJson" to raw))
            }
        }
        LaunchedEffect(store) {
            store.lastError.collect { error ->
                if (error != null) {
                    onError(
                        mapOf("code" to error.code, "message" to error.message),
                    )
                }
            }
        }
    }

    companion object {
        /** Native-side coalescing for `onSnapshot` events (plan §10, §22). */
        private const val SNAPSHOT_EVENT_THROTTLE_MS = 150L

        /**
         * `AIUXComposerToolbarSpec` (JSON) → `AIComposerToolbar`. Unknown
         * glyph names fall back to `Sparkle`; malformed input → defaults.
         */
        private fun parseComposerToolbar(json: String?): AIComposerToolbar {
            if (json.isNullOrBlank()) return AIComposerToolbar.Default
            val root = try {
                kotlinx.serialization.json.Json.parseToJsonElement(json)
                    .jsonObject
            } catch (_: Exception) {
                return AIComposerToolbar.Default
            }
            fun flag(name: String) =
                (root[name] as? kotlinx.serialization.json.JsonPrimitive)
                    ?.contentOrNull?.toBooleanStrictOrNull() ?: true
            val extras = (root["extra"] as? kotlinx.serialization.json.JsonArray)
                ?.mapNotNull { el ->
                    val o = el as? kotlinx.serialization.json.JsonObject
                        ?: return@mapNotNull null
                    val id = (o["id"] as? kotlinx.serialization.json.JsonPrimitive)
                        ?.contentOrNull ?: return@mapNotNull null
                    val label =
                        (o["label"] as? kotlinx.serialization.json.JsonPrimitive)
                            ?.contentOrNull ?: id
                    val glyph =
                        (o["glyph"] as? kotlinx.serialization.json.JsonPrimitive)
                            ?.contentOrNull
                    AIComposerTool(
                        id = id,
                        contentDescription = label,
                        glyph = glyphFor(glyph),
                    )
                } ?: emptyList()
            return AIComposerToolbar(
                attach = flag("attach"),
                tools = flag("tools"),
                dictate = flag("dictate"),
                extra = extras,
            )
        }

        private fun glyphFor(name: String?): AIComposerGlyph = when (name) {
            "doc" -> AIComposerGlyph.Document
            "photo" -> AIComposerGlyph.Photo
            "gear" -> AIComposerGlyph.Gear
            "globe" -> AIComposerGlyph.Globe
            "mic" -> AIComposerGlyph.Mic
            "search" -> AIComposerGlyph.Search
            "plus" -> AIComposerGlyph.Plus
            "star" -> AIComposerGlyph.Star
            else -> AIComposerGlyph.Sparkle
        }
    }
}
