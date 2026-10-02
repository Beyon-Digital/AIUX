package aiux.expo

import aiux.compose.AIUXThemeProvider
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

    @Composable
    private fun AIConversationContent() {
        val id = sessionId ?: return
        val store = androidx.compose.runtime.remember(id) {
            AIUXSessionRegistry.getOrCreate(id)
        }
        val snapshot by store.snapshot.collectAsStateWithLifecycle()
        val dark = isSystemInDarkTheme()
        val theme = androidx.compose.runtime.remember(themeJson, dark) {
            AIUXThemeJson.parse(themeJson, dark)
        }

        val content: @Composable () -> Unit = {
            AIConversation(
                snapshot = snapshot,
                modifier = Modifier.fillMaxSize(),
                mode = mode,
                showComposer = showComposer,
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
        if (theme != null) {
            AIUXThemeProvider(theme = theme, content = content)
        } else {
            content()
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
    }
}
