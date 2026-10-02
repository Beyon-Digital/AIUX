package aiux.compose

import aiux.AiuxSession
import aiux.compose.model.AIApprovalStatus
import aiux.compose.model.AIUXModelParser
import aiux.compose.model.AIUXPart
import aiux.compose.model.AISurfaceNode
import aiux.compose.model.AIWorkspaceMode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * Phase 3 fixture-catalog coverage (plan §17): replay every conformance
 * fixture through the real UniFFI session, then assert the render model maps
 * every entity/part/surface node to a concrete renderer type — no Unknown
 * nodes on schema-defined fixtures.
 */
class SnapshotMappingTest {

    @Test
    fun everyFixtureProducesRenderableSnapshot() {
        val names = FixtureHarness.fixtureNames()
        assertTrue(names.size >= 20, "expected the conformance catalog (got $names)")

        names.forEach { name ->
            val fixture = FixtureHarness.load(name)
            AiuxSession.create("""{"sessionId":"s1"}""").use { session ->
                session.dispatchBatch(fixture.eventsJsonArray)
                val snapshot = AIUXModelParser.parseSnapshot(session.snapshot())

                // every message part maps to a concrete renderer type
                snapshot.messages.flatMap { it.parts }.forEach { part ->
                    assertTrue(
                        part !is AIUXPart.Unknown,
                        "fixture $name: part ${part.id} parsed as Unknown",
                    )
                }
                // every surface node resolves to a known primitive
                snapshot.surfaces.forEach { surface ->
                    assertNoUnknownNodes(surface.root, "fixture $name surface ${surface.id}")
                }
            }
        }
    }

    @Test
    fun snapshotShapeCoversAllEntityCollections() {
        // Each fixture is a self-contained sequence space — one session each.
        fun snapshotOf(name: String) = AiuxSession.create("""{"sessionId":"s1"}""").use { session ->
            session.dispatchBatch(FixtureHarness.load(name).eventsJsonArray)
            AIUXModelParser.parseSnapshot(session.snapshot())
        }

        val approvals = snapshotOf("approval-accepted")
        assertEquals("s1", approvals.sessionId)
        assertNotNull(approvals.session)
        assertTrue(approvals.approvals.isNotEmpty())
        assertTrue(approvals.runs.isNotEmpty())
        assertEquals(AIApprovalStatus.Executed, approvals.approvals[0].status)

        val surfaces = snapshotOf("surface-created")
        assertTrue(surfaces.surfaces.isNotEmpty())
        assertTrue(surfaces.messages.isNotEmpty())

        val context = snapshotOf("context-injection")
        assertTrue(context.allContext.isNotEmpty())
    }

    @Test
    fun streamingFixtureYieldsCompleteText() {
        AiuxSession.create("""{"sessionId":"s1"}""").use { session ->
            session.dispatchBatch(FixtureHarness.load("streaming-response").eventsJsonArray)
            val snapshot = AIUXModelParser.parseSnapshot(session.snapshot())
            val text = snapshot.messages
                .flatMap { it.parts }
                .filterIsInstance<AIUXPart.Text>()
                .joinToString("") { it.text }
            assertEquals("Hello, streaming world!", text)
        }
    }

    @Test
    fun workspaceModeDefaultsToFullscreen() {
        fun workspaceMode(workspaceJson: String) = AIUXModelParser.parseArtifact(
            Json.parseToJsonElement(
                """{"id":"a1","workspace":$workspaceJson}""",
            ) as JsonObject,
        )?.workspace?.mode

        assertEquals(AIWorkspaceMode.Fullscreen, workspaceMode("{}"))
        assertEquals(AIWorkspaceMode.Fullscreen, workspaceMode("""{"mode":"bogus"}"""))
        assertEquals(AIWorkspaceMode.Detail, workspaceMode("""{"mode":"detail"}"""))
        assertEquals(AIWorkspaceMode.Sheet, workspaceMode("""{"mode":"sheet"}"""))
        assertEquals(AIWorkspaceMode.Fullscreen, workspaceMode("""{"mode":"fullscreen"}"""))
    }

    private fun assertNoUnknownNodes(node: AISurfaceNode, where: String) {
        assertTrue(
            node !is AISurfaceNode.UnknownNode,
            "$where contains UnknownNode ${(node as? AISurfaceNode.UnknownNode)?.type}",
        )
        val children = when (node) {
            is AISurfaceNode.Surface -> node.children
            is AISurfaceNode.Card -> node.children
            is AISurfaceNode.Stack -> node.children
            is AISurfaceNode.Row -> node.children
            is AISurfaceNode.Grid -> node.children
            is AISurfaceNode.ListNode -> node.children
            is AISurfaceNode.Actions -> node.children
            else -> emptyList()
        }
        children.forEach { assertNoUnknownNodes(it, where) }
    }
}
