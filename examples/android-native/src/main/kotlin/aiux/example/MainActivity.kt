package aiux.example

import aiux.compose.AIUXThemeProvider
import aiux.compose.components.AIConversation
import aiux.compose.components.AIConversationMode
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle

class MainActivity : ComponentActivity() {
    private val controller = DemoController()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AIUXThemeProvider {
                DemoApp(controller)
            }
        }
    }

    override fun onDestroy() {
        controller.close()
        super.onDestroy()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DemoApp(controller: DemoController) {
    val snapshot by controller.store.snapshot.collectAsStateWithLifecycle()
    val fixture by controller.fixture.collectAsStateWithLifecycle()
    var showFixturePicker by remember { mutableStateOf(false) }

    fixture?.let { name ->
        BackHandler { controller.closeFixture() }
        FixtureScreen(name = name, onBack = controller::closeFixture)
        return
    }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(onClick = { showFixturePicker = true }) {
                Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = "Open fixture catalog")
            }
        },
    ) { padding ->
        AIConversation(
            snapshot = snapshot,
            mode = AIConversationMode.Fullscreen,
            onAction = controller::onAction,
            modifier = Modifier.padding(padding),
        )
    }

    if (showFixturePicker) {
        FixturePickerSheet(
            onPick = {
                showFixturePicker = false
                controller.openFixture(it)
            },
            onDismiss = { showFixturePicker = false },
        )
    }
}
