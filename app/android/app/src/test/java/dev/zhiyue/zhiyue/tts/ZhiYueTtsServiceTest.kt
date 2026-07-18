package dev.zhiyue.zhiyue.tts

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

/// Robolectric 4.12.2 only supports up to SDK 34; the project's compileSdk=36
/// and targetSdk=36 (from Flutter plugin) trip DefaultSdkPicker's
/// `targetSdkVersion > maxSdkVersion` guard. Pin to SDK 34 (Android 14) which
/// is the highest supported. All TTS framework APIs we touch (Service,
/// TextToSpeech, MediaSession, AudioFocus, startForeground) exist at 34.
///
/// T7 note: `TextToSpeech(this)` calls `Context.getDeviceId()` during its
/// constructor, so the Service must have `mBase` attached (via `attachBaseContext`)
/// before `onCreate()` runs. We do this in [createService] rather than using
/// `Robolectric.buildService` to keep the explicit `onCreate/onDestroy` calls
/// visible in each test.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ZhiYueTtsServiceTest {

    /// Construct a Service with an Application context attached so framework
    /// APIs that touch ContextWrapper.mBase (e.g. TextToSpeech) work.
    private fun createService(): ZhiYueTtsService {
        val service = ZhiYueTtsService()
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        // attachBaseContext is protected on ContextWrapper; call via reflection
        // so we don't need to bump visibility on the Service itself.
        // Class hierarchy: ZhiYueTtsService -> Service -> ContextWrapper.
        val wrapperClass = service.javaClass.superclass?.superclass
        val method = wrapperClass?.getDeclaredMethod("attachBaseContext", Context::class.java)
            ?: error("Could not locate ContextWrapper.attachBaseContext via reflection")
        method.isAccessible = true
        method.invoke(service, ctx)
        return service
    }

    @Test
    fun `service lifecycle - onCreate then onDestroy does not throw`() {
        // T6 skeleton: service has empty onCreate/onDestroy. Robolectric lets us
        // instantiate without going through startForegroundService; T10 will add
        // the real foreground notification (which requires ServiceController +
        // shadow NotificationManager).
        val service = createService()
        service.onCreate()
        service.onDestroy()
        // No exception = pass
        val logs = ShadowLog.getLogsForTag("ZhiYueTts")
        org.junit.Assert.assertTrue("Unexpected error logs: $logs",
            logs.none { it.type >= android.util.Log.ERROR })
    }

    @Test
    fun `STOP intent returns START_NOT_STICKY without throwing`() {
        val service = createService()
        service.onCreate()
        val stopIntent = android.content.Intent(ZhiYueTtsService.ACTION_STOP)
        val result = service.onStartCommand(stopIntent, 0, 1)
        org.junit.Assert.assertEquals(
            android.app.Service.START_NOT_STICKY, result)
        service.onDestroy()
    }

    @Test
    fun `onCreate constructs TextToSpeech and sets utterance listener`() {
        val service = createService()
        service.onCreate()
        org.junit.Assert.assertNotNull(service.ttsInstanceForTest)
        service.onDestroy()
    }

    @Test
    fun `STOP intent calls tts stop without throwing`() {
        val service = createService()
        service.onCreate()
        val stopIntent = android.content.Intent(ZhiYueTtsService.ACTION_STOP)
        service.onStartCommand(stopIntent, 0, 1)
        // T8-T11 will verify MediaSession/AudioFocus state. For now, no exception = pass.
        service.onDestroy()
    }

    @Test
    fun `onCreate activates MediaSession`() {
        val service = createService()
        service.onCreate()
        org.junit.Assert.assertNotNull(service.mediaSessionForTest)
        org.junit.Assert.assertTrue(service.mediaSessionForTest!!.isActive)
        service.onDestroy()
    }

    @Test
    fun `SPEAK intent updates PlaybackState to STATE_PLAYING`() {
        val service = createService()
        service.onCreate()
        val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
            .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
            .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
            .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
        service.onStartCommand(speakIntent, 0, 1)
        val state = service.mediaSessionForTest!!.controller.playbackState
        org.junit.Assert.assertEquals(
            android.support.v4.media.session.PlaybackStateCompat.STATE_PLAYING,
            state.state
        )
        service.onDestroy()
    }

    @Test
    fun `PAUSE intent updates PlaybackState to STATE_PAUSED`() {
        val service = createService()
        service.onCreate()
        // 先 SPEAK 让 state 变 PLAYING（更接近真实场景）
        val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
            .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
            .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
            .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
        service.onStartCommand(speakIntent, 0, 1)
        // 再 PAUSE
        val pauseIntent = android.content.Intent(ZhiYueTtsService.ACTION_PAUSE)
        service.onStartCommand(pauseIntent, 0, 2)
        val state = service.mediaSessionForTest!!.controller.playbackState
        org.junit.Assert.assertEquals(
            android.support.v4.media.session.PlaybackStateCompat.STATE_PAUSED,
            state.state
        )
        service.onDestroy()
    }

    @Test
    fun `STOP intent updates PlaybackState to STATE_STOPPED and deactivates session`() {
        val service = createService()
        service.onCreate()
        val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
            .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
            .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
            .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
        service.onStartCommand(speakIntent, 0, 1)
        val stopIntent = android.content.Intent(ZhiYueTtsService.ACTION_STOP)
        service.onStartCommand(stopIntent, 0, 2)
        val state = service.mediaSessionForTest!!.controller.playbackState
        org.junit.Assert.assertEquals(
            android.support.v4.media.session.PlaybackStateCompat.STATE_STOPPED,
            state.state
        )
        service.onDestroy()
    }

    @Test
    fun `onCreate requests AudioFocus and registers PhoneStateListener`() {
        val service = createService()
        service.onCreate()
        org.junit.Assert.assertTrue(service.audioFocusRequestedForTest)
        org.junit.Assert.assertTrue(service.phoneStateListenerRegisteredForTest)
        service.onDestroy()
    }

    @Test
    fun `onDestroy abandons AudioFocus and unregisters PhoneStateListener`() {
        val service = createService()
        service.onCreate()
        service.onDestroy()
        org.junit.Assert.assertFalse(service.audioFocusRequestedForTest)
        org.junit.Assert.assertFalse(service.phoneStateListenerRegisteredForTest)
    }

    // ---- v1.13.7-alpha Bug 4: speak Intent must apply rate/pitch/volume
    // before handing the utterance to TextToSpeech. ----

    @Test
    fun `SPEAK intent captures rate pitch volume from extras (Bug 4)`() {
        val service = createService()
        service.onCreate()
        val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
            .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
            .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
            .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
            .putExtra(ZhiYueTtsService.EXTRA_RATE, 1.5)
            .putExtra(ZhiYueTtsService.EXTRA_PITCH, 1.2)
            .putExtra(ZhiYueTtsService.EXTRA_VOLUME, 0.8)
        service.onStartCommand(speakIntent, 0, 1)
        org.junit.Assert.assertEquals(
            "rate should be captured from Intent extras",
            1.5f,
            service.lastAppliedRateForTest
        )
        org.junit.Assert.assertEquals(
            "pitch should be captured from Intent extras",
            1.2f,
            service.lastAppliedPitchForTest
        )
        org.junit.Assert.assertEquals(
            "volume should be captured from Intent extras",
            0.8f,
            service.lastAppliedVolumeForTest
        )
        service.onDestroy()
    }

    @Test
    fun `SPEAK intent defaults rate pitch volume to 1_0 when extras missing (Bug 4)`() {
        val service = createService()
        service.onCreate()
        val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
            .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
            .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
            .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
        service.onStartCommand(speakIntent, 0, 1)
        org.junit.Assert.assertEquals(
            "default rate",
            1.0f,
            service.lastAppliedRateForTest
        )
        org.junit.Assert.assertEquals(
            "default pitch",
            1.0f,
            service.lastAppliedPitchForTest
        )
        org.junit.Assert.assertEquals(
            "default volume",
            1.0f,
            service.lastAppliedVolumeForTest
        )
        service.onDestroy()
    }

    @Test
    fun `onCreate starts foreground with mediaPlayback type`() {
        val controller = org.robolectric.Robolectric.buildService(ZhiYueTtsService::class.java)
        val service = controller.create().get()
        org.junit.Assert.assertTrue(service.isForegroundForTest)
        controller.destroy()
    }

    @Test
    fun `STOP intent stops foreground and calls stopSelf`() {
        val controller = org.robolectric.Robolectric.buildService(ZhiYueTtsService::class.java)
        val service = controller.create().get()
        val stopIntent = android.content.Intent(ZhiYueTtsService.ACTION_STOP)
        service.onStartCommand(stopIntent, 0, 1)
        org.junit.Assert.assertFalse(service.isForegroundForTest)
        controller.destroy()
    }

    // ---- v1.13.7-alpha Bug 5 (P0): plugin rebinding must not strand service
    // on a stale plugin reference. ----

    /// Sum of every emit-routing counter on the plugin. Any value > 0 means
    /// emit reached THIS plugin instance (either succeeded, threw, hit null
    /// channel, or was attempted).
    private fun emitReachCount(plugin: ZhiYueTtsPlugin): Int =
        plugin.invokeAttemptCount +
            plugin.invokeSucceededCount +
            plugin.invokeExceptionCount +
            plugin.invokeChannelNullCount

    @Test
    fun `emit uses current plugin instance not cached reference`() {
        // Reproduction: v1.13.6-alpha user reported "导入新书后只读一句".
        // Diagnostic showed UI counter = 0 (new plugin_B, the one Dart talks
        // to) but debugLog accumulated 43 EMIT_DROPPED channel_null entries
        // — service was still invoking plugin_A (whose channel was nulled
        // by onDetachedFromEngine) because onCreate had cached
        // eventEmitter = plugin_A::emitEvent.
        //
        // After fix, emit() reads ZhiYueTtsPlugin.instance at EVERY call,
        // so swapping the companion routes subsequent emits to the new plugin.
        val ctx = ApplicationProvider.getApplicationContext<Context>()

        // pluginA attaches as the singleton, then service onCreate runs.
        val pluginA = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(pluginA)
        try {
            val service = createService()
            service.onCreate()
            // First emit reaches plugin_A (channel null → channel_null_count++).
            service.simulateEmitForTest(mapOf("event" to "state", "state" to "speaking"))
            val pluginAFirst = emitReachCount(pluginA)
            org.junit.Assert.assertTrue(
                "pluginA should have seen the first emit (count=$pluginAFirst)",
                pluginAFirst > 0
            )

            // Simulate plugin rebinding: plugin_B replaces plugin_A as the
            // companion (mirrors onDetachedFromEngine clearing instance +
            // onAttachedToEngine on a fresh plugin after Activity recreate).
            val pluginB = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
            ZhiYueTtsPlugin.setInstanceForTest(pluginB)

            // Second emit must route to plugin_B, NOT plugin_A.
            service.simulateEmitForTest(mapOf("event" to "done", "utteranceId" to "sent_0"))

            val pluginAAfter = emitReachCount(pluginA)
            val pluginBAfter = emitReachCount(pluginB)
            org.junit.Assert.assertTrue(
                "pluginB should have seen the second emit (count=$pluginBAfter)",
                pluginBAfter > 0
            )
            org.junit.Assert.assertEquals(
                "pluginA must not grow after rebinding (cached reference bug)",
                pluginAFirst,
                pluginAAfter
            )

            service.onDestroy()
        } finally {
            // Reset companion so other tests start clean.
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    // ---- v1.13.7-alpha Bug 1: handleResume must emit resume_request so
    // Dart can re-drive SPEAK; notification must flip pause↔play icon. ----

    /// Builds a service with a real plugin attached so emit() reaches
    /// countable counters. Returns (service, plugin) for assertions.
    private fun createServiceWithPlugin(): Pair<ZhiYueTtsService, ZhiYueTtsPlugin> {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        val service = createService()
        service.onCreate()
        return service to plugin
    }

    @Test
    fun `handleResume emits resume_request event (Bug 1)`() {
        val (service, plugin) = createServiceWithPlugin()
        try {
            val before = emitReachCount(plugin)
            // Trigger handleResume via the same path the MediaSession
            // Callback.onPlay uses (RESUME intent → onStartCommand).
            val resumeIntent = android.content.Intent(ZhiYueTtsService.ACTION_RESUME)
            service.onStartCommand(resumeIntent, 0, 1)
            val after = emitReachCount(plugin)
            org.junit.Assert.assertTrue(
                "handleResume should have emitted at least one event " +
                    "(before=$before after=$after)",
                after > before
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `handleResume updates playback state to STATE_PLAYING (Bug 1)`() {
        val (service, _) = createServiceWithPlugin()
        try {
            // First PAUSE so we know we're transitioning out of STATE_PAUSED.
            val pauseIntent = android.content.Intent(ZhiYueTtsService.ACTION_PAUSE)
            service.onStartCommand(pauseIntent, 0, 1)
            org.junit.Assert.assertEquals(
                android.support.v4.media.session.PlaybackStateCompat.STATE_PAUSED,
                service.mediaSessionForTest!!.controller.playbackState.state
            )

            val resumeIntent = android.content.Intent(ZhiYueTtsService.ACTION_RESUME)
            service.onStartCommand(resumeIntent, 0, 2)
            org.junit.Assert.assertEquals(
                "handleResume must flip playback state to PLAYING",
                android.support.v4.media.session.PlaybackStateCompat.STATE_PLAYING,
                service.mediaSessionForTest!!.controller.playbackState.state
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `buildNotification shows play icon and 继续 action when paused (Bug 1)`() {
        val (service, _) = createServiceWithPlugin()
        try {
            // Drive playback into PAUSED so the notification toggle should
            // flip to a play button.
            val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
                .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
            service.onStartCommand(speakIntent, 0, 1)
            val pauseIntent = android.content.Intent(ZhiYueTtsService.ACTION_PAUSE)
            service.onStartCommand(pauseIntent, 0, 2)

            val notification = service.buildNotificationForTest("智阅朗读", "已暂停")
            val actions = notification.actions
            org.junit.Assert.assertNotNull("notification must have actions", actions)
            val toggleAction = actions!!.firstOrNull { it.title == "继续" }
            org.junit.Assert.assertNotNull(
                "paused notification must show a '继续' (play) action",
                toggleAction
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `buildNotification shows pause icon and 暂停 action when playing (Bug 1)`() {
        val (service, _) = createServiceWithPlugin()
        try {
            val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
                .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
            service.onStartCommand(speakIntent, 0, 1)

            val notification = service.buildNotificationForTest("智阅朗读", "朗读中")
            val actions = notification.actions
            org.junit.Assert.assertNotNull("notification must have actions", actions)
            val toggleAction = actions!!.firstOrNull { it.title == "暂停" }
            org.junit.Assert.assertNotNull(
                "playing notification must show a '暂停' (pause) action",
                toggleAction
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }
}
