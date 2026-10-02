package aiux.example

import aiux.compose.AIUXSessionStore
import aiux.compose.AIUXFixture
import aiux.compose.components.AIConversation
import aiux.compose.components.AIConversationMode
import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Description
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Catalog of the shared conformance fixtures, shipped as assets. */
fun fixtureNames(context: Context): List<String> =
    context.assets.list("fixtures")?.map { it.removeSuffix(".json") }?.sorted().orEmpty()

suspend fun fixtureEvents(context: Context, name: String): String =
    withContext(Dispatchers.IO) { context.assets.open("fixtures/$name.json").bufferedReader().readText() }

/**
 * Fixture browser: lists the catalog in a bottom sheet; replaying a fixture
 * builds a fresh store and renders its snapshot with the real components.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FixturePickerSheet(onPick: (String) -> Unit, onDismiss: () -> Unit) {
    val names = fixtureNames(LocalContext.current)
    ModalBottomSheet(onDismissRequest = onDismiss) {
        LazyColumn(Modifier.fillMaxWidth()) {
            items(names) { name ->
                ListItem(
                    headlineContent = { Text(name) },
                    leadingContent = { Icon(Icons.Filled.Description, contentDescription = null) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(name) },
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FixtureScreen(name: String, onBack: () -> Unit) {
    val context = LocalContext.current
    var store by remember { mutableStateOf<AIUXSessionStore?>(null) }
    val scope = rememberCoroutineScope()

    DisposableEffect(name) {
        val s = AIUXSessionStore.create("""{"sessionId":"s1"}""")
        store = s
        scope.launch {
            val fixture = AIUXFixture.parse(fixtureEvents(context, name))
            s.dispatchBatch(fixture.eventsJsonArray)
        }
        onDispose { s.close() }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(name, style = MaterialTheme.typography.titleMedium) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        store?.let { s ->
            val snapshot by s.snapshot.collectAsStateWithLifecycle()
            AIConversation(
                snapshot = snapshot,
                mode = AIConversationMode.Embedded,
                showComposer = false,
                onAction = {},
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
            )
        }
    }
}
