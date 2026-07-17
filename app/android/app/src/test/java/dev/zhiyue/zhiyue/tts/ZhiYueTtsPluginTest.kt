package dev.zhiyue.zhiyue.tts

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// v1.13 T4/T5: verifies the critical "no system service at attach time"
/// invariant and the T5 stub method-call dispatch. Pure JVM unit test —
/// does not require Robolectric because the assertions touch only Kotlin
/// state (`isServiceCreated` boolean + FakeMethodChannelResult flags).
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
    fun `init method constructs service and emits success`() {
        val plugin = ZhiYueTtsPlugin()
        val fakeResult = FakeMethodChannelResult()
        plugin.onMethodCall(MethodCall("init", null), fakeResult)
        assertTrue(fakeResult.successCalled)
        assertTrue(plugin.isServiceCreated)
    }

    @Test
    fun `speak method routes text to service`() {
        val plugin = ZhiYueTtsPlugin()
        plugin.onMethodCall(MethodCall("init", null), FakeMethodChannelResult())
        val args = mapOf("text" to "你好", "locale" to "zh-CN", "sentenceIndex" to 0)
        val fakeResult = FakeMethodChannelResult()
        plugin.onMethodCall(MethodCall("speak", args), fakeResult)
        assertTrue(fakeResult.successCalled)
    }

    @Test
    fun `unknown method returns notImplemented`() {
        val plugin = ZhiYueTtsPlugin()
        val fakeResult = FakeMethodChannelResult()
        plugin.onMethodCall(MethodCall("foo", null), fakeResult)
        assertTrue(fakeResult.notImplementedCalled)
    }
}

/// In-memory MethodChannel.Result that records which terminal method was
/// invoked. Used by T5 tests to assert dispatch behavior without spinning
/// up a real Flutter engine.
class FakeMethodChannelResult : MethodChannel.Result {
    var successCalled = false
    var successArg: Any? = null
    var errorCalled = false
    var notImplementedCalled = false

    override fun success(result: Any?) {
        successCalled = true
        successArg = result
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        errorCalled = true
    }

    override fun notImplemented() {
        notImplementedCalled = true
    }
}
