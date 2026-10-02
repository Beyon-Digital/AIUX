package aiux.compose.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import aiux.compose.AIUX
import aiux.compose.model.AIRunStatus
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXSnapshot

/** Presentation modes (plan §14); `Sheet`/`Sidecar`/`Headless` land later. */
enum class AIConversationMode { Fullscreen, Embedded }

/**
 * The complete AI conversation surface: context bar + message stream +
 * composer. `fullscreen` wraps it in a Scaffold with a title bar; `embedded`
 * is just the stream + composer for embedding inside host chrome.
 *
 * All interaction flows upward via [onAction]; the host executes (§23).
 */
@Composable
fun AIConversation(
    snapshot: AIUXSnapshot,
    modifier: Modifier = Modifier,
    mode: AIConversationMode = AIConversationMode.Fullscreen,
    showComposer: Boolean = true,
    showContextBar: Boolean = true,
    onAction: (AIUXAction) -> Unit = {},
) {
    val running = snapshot.activeRun?.status == AIRunStatus.Running
    when (mode) {
        AIConversationMode.Fullscreen -> FullscreenConversation(snapshot, running, showComposer, showContextBar, modifier, onAction)
        AIConversationMode.Embedded -> EmbeddedConversation(snapshot, running, showComposer, showContextBar, modifier, onAction)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FullscreenConversation(
    snapshot: AIUXSnapshot,
    running: Boolean,
    showComposer: Boolean,
    showContextBar: Boolean,
    modifier: Modifier,
    onAction: (AIUXAction) -> Unit,
) {
    val theme = AIUX.theme
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = theme.colors.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        snapshot.session?.title ?: "AIUX",
                        style = theme.typography.title,
                        color = theme.colors.foreground,
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = theme.colors.surface,
                    titleContentColor = theme.colors.foreground,
                ),
            )
        },
        bottomBar = {
            Column(modifier = Modifier.imePadding().navigationBarsPadding()) {
                if (showComposer) {
                    AIComposer(running = running, onAction = onAction)
                }
            }
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            if (showContextBar) {
                AIContextBar(context = snapshot.allContext, onAction = onAction)
            }
            MessageList(snapshot, Modifier.weight(1f), onAction)
        }
    }
}

@Composable
private fun EmbeddedConversation(
    snapshot: AIUXSnapshot,
    running: Boolean,
    showComposer: Boolean,
    showContextBar: Boolean,
    modifier: Modifier,
    onAction: (AIUXAction) -> Unit,
) {
    Column(modifier = modifier.fillMaxSize().imePadding()) {
        if (showContextBar) {
            AIContextBar(context = snapshot.allContext, onAction = onAction)
        }
        MessageList(snapshot, Modifier.weight(1f), onAction)
        if (showComposer) {
            AIComposer(running = running, onAction = onAction)
        }
    }
}

@Composable
private fun MessageList(
    snapshot: AIUXSnapshot,
    modifier: Modifier,
    onAction: (AIUXAction) -> Unit,
) {
    val theme = AIUX.theme
    val listState = rememberLazyListState()

    // Auto-scroll to newest content while streaming/new messages arrive. The
    // parts' content hash keeps text.delta growth scrolling the view —
    // deltas target a part by id, not position, so every part's content is
    // folded into the key, not just the tail.
    val lastMessageKey = snapshot.messages.lastOrNull()
        ?.let { "${it.id}:${it.streaming}:${it.parts.hashCode()}" }
    LaunchedEffect(lastMessageKey, snapshot.messages.size) {
        if (snapshot.messages.isNotEmpty()) {
            listState.animateScrollToItem(snapshot.messages.size - 1)
        }
    }

    if (snapshot.messages.isEmpty()) {
        Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Text(
                "Start the conversation",
                style = theme.typography.caption,
                color = theme.colors.mutedForeground,
                modifier = Modifier.semantics { contentDescription = "empty conversation" },
            )
        }
        return
    }

    LazyColumn(
        state = listState,
        modifier = modifier
            .fillMaxWidth()
            .semantics { contentDescription = "conversation messages" },
        contentPadding = PaddingValues(vertical = theme.spacing.sm),
        verticalArrangement = Arrangement.spacedBy(theme.spacing.xs),
    ) {
        items(
            items = snapshot.messages,
            key = { it.id },
            contentType = { it.role },
        ) { message ->
            AIMessage(message = message, snapshot = snapshot, onAction = onAction)
        }
    }
}
