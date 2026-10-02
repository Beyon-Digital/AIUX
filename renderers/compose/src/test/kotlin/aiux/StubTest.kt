package aiux

import kotlin.test.Test
import kotlin.test.assertEquals

class StubTest {
    @Test fun version() = assertEquals("0.1.0", Stub.VERSION)
}
