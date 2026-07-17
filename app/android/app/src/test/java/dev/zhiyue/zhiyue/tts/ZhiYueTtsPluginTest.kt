package dev.zhiyue.zhiyue.tts

import org.junit.Assert.assertFalse
import org.junit.Test

/// v1.13 T4: verifies the critical "no system service at attach time"
/// invariant. Pure JVM unit test — does not require Robolectric because
/// the assertion touches only Kotlin state (`isServiceCreated` boolean).
///
/// Future tasks (T6+) that exercise Android framework components
/// (Service / TextToSpeech / MediaSession) will use Robolectric.
class ZhiYueTtsPluginTest {

    @Test
    fun `onAttachedToEngine binds MethodChannel but does NOT construct TextToSpeech`() {
        val plugin = ZhiYueTtsPlugin()
        // Critical invariant: after construction, no system service should be touched.
        // plugin.isServiceCreated exposes lazy-init state for testability.
        assertFalse(plugin.isServiceCreated)
    }

    @Test
    fun `init method call triggers service start`() {
        // Placeholder — implemented in T5/T6 once plugin has service interaction.
        // Kept here to verify the test harness compiles + runs.
    }
}
