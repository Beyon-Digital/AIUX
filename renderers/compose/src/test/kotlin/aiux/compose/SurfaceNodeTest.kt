package aiux.compose

import aiux.compose.model.AIGap
import aiux.compose.model.AIPadding
import aiux.compose.model.AIRadius
import aiux.compose.model.AISurfaceNode
import aiux.compose.model.AIButtonVariant
import aiux.compose.model.AITone
import aiux.compose.model.SurfaceNodeParser
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import kotlinx.serialization.json.Json

/** Node-resolution coverage: every §6 primitive parses; unknown → placeholder. */
class SurfaceNodeTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun node(src: String): AISurfaceNode =
        SurfaceNodeParser.parse(json.parseToJsonElement(src) as kotlinx.serialization.json.JsonObject)
            ?: error("failed to parse node: $src")

    @Test
    fun parsesFullPrimitiveSet() {
        val cases = mapOf(
            """{"type":"surface","children":[]}""" to AISurfaceNode.Surface::class,
            """{"type":"card","title":"T","children":[]}""" to AISurfaceNode.Card::class,
            """{"type":"stack","direction":"horizontal","children":[]}""" to AISurfaceNode.Stack::class,
            """{"type":"row","children":[]}""" to AISurfaceNode.Row::class,
            """{"type":"grid","columns":3,"children":[]}""" to AISurfaceNode.Grid::class,
            """{"type":"heading","text":"H","level":2}""" to AISurfaceNode.Heading::class,
            """{"type":"text","text":"t","variant":"muted"}""" to AISurfaceNode.Text::class,
            """{"type":"markdown","markdown":"**b**"}""" to AISurfaceNode.Markdown::class,
            """{"type":"code","code":"x=1","language":"py"}""" to AISurfaceNode.Code::class,
            """{"type":"icon","name":"check","size":"lg"}""" to AISurfaceNode.Icon::class,
            """{"type":"image","src":"aiux://i/1","alt":"a"}""" to AISurfaceNode.Image::class,
            """{"type":"badge","text":"b","tone":"success"}""" to AISurfaceNode.Badge::class,
            """{"type":"divider"}""" to AISurfaceNode.Divider::class,
            """{"type":"spacer","size":"lg"}""" to AISurfaceNode.Spacer::class,
            """{"type":"keyValue","items":[{"key":"k","value":"v"}]}""" to AISurfaceNode.KeyValue::class,
            """{"type":"list","ordered":true,"children":[]}""" to AISurfaceNode.ListNode::class,
            """{"type":"table","headers":["a"],"rows":[["1"]]}""" to AISurfaceNode.Table::class,
            """{"type":"button","label":"Go","action":{"id":"go"},"variant":"destructive"}""" to AISurfaceNode.Button::class,
            """{"type":"menu","label":"M","items":[{"label":"i","action":{"id":"i"}}]}""" to AISurfaceNode.Menu::class,
            """{"type":"progress","value":0.5,"max":1.0}""" to AISurfaceNode.Progress::class,
            """{"type":"status","text":"ok","tone":"warning"}""" to AISurfaceNode.Status::class,
            """{"type":"input","name":"n","inputType":"email"}""" to AISurfaceNode.Input::class,
            """{"type":"textarea","name":"n","rows":4}""" to AISurfaceNode.TextArea::class,
            """{"type":"select","name":"s","options":[{"label":"L","value":"v"}]}""" to AISurfaceNode.Select::class,
            """{"type":"checkbox","name":"c","label":"L","checked":true}""" to AISurfaceNode.Checkbox::class,
            """{"type":"radio","name":"r","options":[{"value":"a","label":"A"}]}""" to AISurfaceNode.Radio::class,
            """{"type":"field","label":"L","children":[{"type":"input","name":"n"}]}""" to AISurfaceNode.Field::class,
            """{"type":"form","submit":{"id":"f.submit"},"children":[]}""" to AISurfaceNode.Form::class,
            """{"type":"listItem","title":"t","action":{"id":"open"}}""" to AISurfaceNode.ListItem::class,
            """{"type":"custom","kind":"beyondigital.chart","props":{"y":1}}""" to AISurfaceNode.Custom::class,
            """{"type":"actions","children":[]}""" to AISurfaceNode.Actions::class,
        )
        cases.forEach { (src, klass) ->
            assertEquals(klass, node(src)::class, "node type mismatch for $src")
        }
    }

    @Test
    fun unknownNodeTypeDegradesToPlaceholder() {
        val n = node("""{"type":"hologram","children":[]}""")
        assertIs<AISurfaceNode.UnknownNode>(n)
        assertEquals("hologram", (n as AISurfaceNode.UnknownNode).type)
    }

    @Test
    fun semanticLayoutValuesParse() {
        val n = node("""{"type":"stack","gap":"xl","padding":"lg","radius":"full","alignment":"center","distribution":"spaceBetween","children":[]}""")
        assertEquals(AIGap.Xl, n.style.gap)
        assertEquals(AIPadding.Lg, n.style.padding)
        assertEquals(AIRadius.Full, n.style.radius)
    }

    @Test
    fun buttonActionIsSemanticData() {
        val n = node("""{"type":"button","label":"Approve","variant":"primary","action":{"id":"invoice.approve","payload":{"id":"inv-9"}}}""")
        assertIs<AISurfaceNode.Button>(n)
        val b = n as AISurfaceNode.Button
        assertEquals("invoice.approve", b.action.id)
        assertEquals(AIButtonVariant.Primary, b.variant)
        assertEquals("inv-9", b.action.payload["id"]?.toString()?.trim('"'))
    }

    @Test
    fun tonesAndVariantsParse() {
        assertEquals(AITone.Warning, (node("""{"type":"status","text":"w","tone":"warning"}""") as AISurfaceNode.Status).tone)
    }
}
