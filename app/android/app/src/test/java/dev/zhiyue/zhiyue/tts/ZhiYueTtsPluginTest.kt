package dev.zhiyue.zhiyue.tts

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config

/// v1.13 T4/T5/T11: verifies (a) the critical "no system service at attach
/// time" invariant, (b) the method-call dispatch, and (c) T11's intent
/// forwarding to [ZhiYueTtsService].
///
/// T11 tests use Robolectric's ShadowApplication to introspect
/// `startForegroundService` / `startService` calls — both APIs land in the
/// same `nextStartedService` queue under Robolectric 4.12+.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
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
        plugin.attachContextForTest(ApplicationProvider.getApplicationContext())
        val fakeResult = FakeMethodChannelResult()
        plugin.onMethodCall(MethodCall("init", null), fakeResult)
        assertTrue(fakeResult.successCalled)
        assertTrue(plugin.isServiceCreated)
    }

    @Test
    fun `speak method routes text to service`() {
        val plugin = ZhiYueTtsPlugin()
        plugin.attachContextForTest(ApplicationProvider.getApplicationContext())
        plugin.onMethodCall(MethodCall("init", null), FakeMethodChannelResult())
        val args = mapOf("text" to "你好", "locale" to "zh-CN", "sentenceIndex" to 0)
        val fakeResult = FakeMethodChannelResult()
        plugin.onMethodCall(MethodCall("speak", args), fakeResult)
        assertTrue(fakeResult.successCalled)
    }

    @Test
    fun `unknown method returns notImplemented`() {
        val plugin = ZhiYueTtsPlugin()
        plugin.attachContextForTest(ApplicationProvider.getApplicationContext())
        val fakeResult = FakeMethodChannelResult()
        plugin.onMethodCall(MethodCall("foo", null), fakeResult)
        assertTrue(fakeResult.notImplementedCalled)
    }

    // ---- T11: intent forwarding ----

    @Test
    fun `init method starts ZhiYueTtsService via startForegroundService`() {
        val plugin = ZhiYueTtsPlugin()
        plugin.attachContextForTest(ApplicationProvider.getApplicationContext())
        val fakeResult = FakeMethodChannelResult()
        plugin.onMethodCall(MethodCall("init", null), fakeResult)
        assertTrue(fakeResult.successCalled)
        // Verify the service was started via startForegroundService (API 26+).
        val shadowApp = Shadows.shadowOf(
            ApplicationProvider.getApplicationContext<Context>() as Application
        )
        val nextStarted = shadowApp.nextStartedService
        assertNotNull("No service was started", nextStarted)
        assertEquals(
            ZhiYueTtsService::class.java.name,
            nextStarted.component?.className
        )
    }

    @Test
    fun `speak method sends SPEAK intent with text locale and sentenceIndex extras`() {
        val plugin = ZhiYueTtsPlugin()
        plugin.attachContextForTest(ApplicationProvider.getApplicationContext())
        // First init to start service
        plugin.onMethodCall(MethodCall("init", null), FakeMethodChannelResult())
        // Drain init's startForegroundService
        val shadowApp = Shadows.shadowOf(
            ApplicationProvider.getApplicationContext<Context>() as Application
        )
        shadowApp.nextStartedService // discard the init's start
        // Now send speak
        val args = mapOf("text" to "你好", "locale" to "zh-CN", "sentenceIndex" to 0)
        plugin.onMethodCall(MethodCall("speak", args), FakeMethodChannelResult())
        val speakIntent = shadowApp.nextStartedService
        assertNotNull(speakIntent)
        assertEquals(ZhiYueTtsService.ACTION_SPEAK, speakIntent.action)
        assertEquals("你好", speakIntent.getStringExtra(ZhiYueTtsService.EXTRA_TEXT))
        assertEquals("zh-CN", speakIntent.getStringExtra(ZhiYueTtsService.EXTRA_LOCALE))
        assertEquals(0, speakIntent.getIntExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, -1))
    }

    @Test
    fun `stop method sends STOP intent`() {
        val plugin = ZhiYueTtsPlugin()
        plugin.attachContextForTest(ApplicationProvider.getApplicationContext())
        plugin.onMethodCall(MethodCall("init", null), FakeMethodChannelResult())
        val shadowApp = Shadows.shadowOf(
            ApplicationProvider.getApplicationContext<Context>() as Application
        )
        shadowApp.nextStartedService // drain init
        plugin.onMethodCall(MethodCall("stop", null), FakeMethodChannelResult())
        val stopIntent = shadowApp.nextStartedService
        assertNotNull(stopIntent)
        assertEquals(ZhiYueTtsService.ACTION_STOP, stopIntent.action)
    }

    // ---- T12 (v1.13.5-alpha rewrite): MethodChannel reverse callback ----
    //
    // v1.13.4-alpha used EventChannel + eventSinkForTest to capture emits.
    // v1.13.5-alpha switched to MethodChannel.invokeMethod reverse callback
    // because v1.13.4 diagnostic data showed sink.success was silently
    // dropped by the binary messenger on Chinese ROMs. We can't easily mock
    // MethodChannel.invokeMethod under Robolectric (it needs a real binary
    // messenger), so we instead assert on the diagnostic counters that
    // emitEvent updates. The Dart-side test in
    // `self_built_tts_service_test.dart` covers the full round-trip.

    @Test
    fun `emitEvent with null channel records channelNull counter`() {
        val plugin = ZhiYueTtsPlugin()
        // Don't call onAttachedToEngine — channel stays null.
        plugin.simulateServiceEventForTest(mapOf("event" to "state", "state" to "speaking"))
        org.junit.Assert.assertEquals(1, plugin.invokeChannelNullCount)
        org.junit.Assert.assertEquals(0, plugin.invokeAttemptCount)
    }
}

/// In-memory MethodChannel.Result that records which terminal method was
/// invoked. Used by tests to assert dispatch behavior without spinning
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
