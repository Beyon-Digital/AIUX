package aiux.compose

import java.io.File

/**
 * Loads the shared conformance catalog (`conformance/fixtures` JSON files) —
 * the same fixtures every renderer consumes (plan §17). Path is relative to
 * the module dir, same convention as `bindings/kotlin` tests.
 */
object FixtureHarness {
    private val fixturesDir = File("../../conformance/fixtures")

    fun fixtureNames(): List<String> =
        fixturesDir.listFiles { f -> f.extension == "json" }
            ?.map { it.nameWithoutExtension }
            ?.sorted()
            ?: error("conformance fixtures dir not found: ${fixturesDir.absolutePath}")

    fun load(name: String): AIUXFixture =
        AIUXFixture.parse(File(fixturesDir, "$name.json").readText())
}
