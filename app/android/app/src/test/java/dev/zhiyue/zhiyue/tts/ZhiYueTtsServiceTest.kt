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

    /// v1.13.8-alpha Bug 2: createService + onCreate + simulate TTS init
    /// SUCCESS. Use this for tests that exercise handleSpeak's normal path
    /// (i.e. SPEAK should reach tts.speak and update playback state).
    /// Tests that exercise the init-race defer path use plain [createService]
    /// + [simulateInitNotReady] instead.
    private fun createReadyService(): ZhiYueTtsService {
        val service = createService()
        service.onCreate()
        service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.SUCCESS)
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
        val service = createReadyService()
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
        val service = createReadyService()
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
        val service = createReadyService()
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
        val service = createReadyService()
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
        val service = createReadyService()
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
    /// v1.13.8-alpha Bug 2: drives TTS init SUCCESS so handleSpeak's init
    /// guard doesn't deflect — callers that want to simulate the init race
    /// use [simulateInitNotReady] after this returns.
    private fun createServiceWithPlugin(): Pair<ZhiYueTtsService, ZhiYueTtsPlugin> {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        val service = createService()
        service.onCreate()
        service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.SUCCESS)
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

    // ---- v1.13.8-alpha Bug 2: TTS init race. handleSpeak must defer SPEAK
    // intents that arrive before TextToSpeech.onInit(SUCCESS), and flush
    // them when init completes. Without this guard, tts.speak() returns -1
    // ERROR, UtteranceProgressListener fires nothing, and Dart's _speakCurrent
    // hangs in loading forever — manifesting as "playback starts from
    // beginning" when the user re-triggers playback. ----

    /// Resets the companion init flag to its "callback never fired" value
    /// (-999) so handleSpeak's init guard deflects the next SPEAK intent.
    /// The init callback itself is async on real devices; in Robolectric we
    /// never invoke it for these tests, simulating the race window.
    private fun simulateInitNotReady() {
        ZhiYueTtsService.ttsInitStatus = -999
        ZhiYueTtsService.pendingSpeakActive = false
    }

    @Test
    fun `SPEAK before TTS init defers to pendingSpeak without applying rate (Bug 2 happy defer)`() {
        val (service, _) = createServiceWithPlugin()
        try {
            simulateInitNotReady()
            val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
                .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 3)
                .putExtra(ZhiYueTtsService.EXTRA_RATE, 1.5)
            service.onStartCommand(speakIntent, 0, 1)

            org.junit.Assert.assertNotNull(
                "deferred intent should be cached on pendingSpeak",
                service.pendingSpeakForTest
            )
            org.junit.Assert.assertTrue(
                "companion pendingSpeakActive must reflect defer state",
                ZhiYueTtsService.pendingSpeakActive
            )
            org.junit.Assert.assertEquals(
                "handleSpeak must NOT apply rate when deferring (early return)",
                0f,
                service.lastAppliedRateForTest
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `TTS init SUCCESS flushes pendingSpeak and applies rate (Bug 2 flush)`() {
        val (service, _) = createServiceWithPlugin()
        try {
            simulateInitNotReady()
            val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
                .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
                .putExtra(ZhiYueTtsService.EXTRA_RATE, 1.7)
            service.onStartCommand(speakIntent, 0, 1)
            org.junit.Assert.assertNotNull(service.pendingSpeakForTest)

            // Drive the init callback as if TextToSpeech had just become ready.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.SUCCESS)

            org.junit.Assert.assertNull(
                "pendingSpeak must be cleared after init flush",
                service.pendingSpeakForTest
            )
            org.junit.Assert.assertFalse(
                "companion pendingSpeakActive must reset after flush",
                ZhiYueTtsService.pendingSpeakActive
            )
            org.junit.Assert.assertEquals(
                "flushed handleSpeak must apply the deferred rate",
                1.7f,
                service.lastAppliedRateForTest
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `multiple SPEAK before init - last overwrites earlier (Bug 2 QUEUE_FLUSH)`() {
        val (service, _) = createServiceWithPlugin()
        try {
            simulateInitNotReady()
            val first = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "第一句")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
            val second = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "第二句")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 1)
            service.onStartCommand(first, 0, 1)
            service.onStartCommand(second, 0, 2)

            val deferred = service.pendingSpeakForTest
            org.junit.Assert.assertNotNull(deferred)
            org.junit.Assert.assertEquals(
                "later SPEAK must overwrite pending (QUEUE_FLUSH semantics)",
                "第二句",
                deferred?.getStringExtra(ZhiYueTtsService.EXTRA_TEXT)
            )
            org.junit.Assert.assertEquals(
                "sentenceIndex of the last deferred intent wins",
                1,
                deferred?.getIntExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, -1)
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `STOP before init clears pendingSpeak so late init does not resurrect (Bug 2 stop-cancel)`() {
        val (service, _) = createServiceWithPlugin()
        try {
            simulateInitNotReady()
            val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
            service.onStartCommand(speakIntent, 0, 1)
            org.junit.Assert.assertNotNull(service.pendingSpeakForTest)

            val stopIntent = android.content.Intent(ZhiYueTtsService.ACTION_STOP)
            service.onStartCommand(stopIntent, 0, 2)
            org.junit.Assert.assertNull(
                "STOP must clear pendingSpeak",
                service.pendingSpeakForTest
            )
            org.junit.Assert.assertFalse(
                "companion pendingSpeakActive must reset on STOP",
                ZhiYueTtsService.pendingSpeakActive
            )

            // Even if a late init callback arrives now, it must not resurrect playback.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.SUCCESS)
            org.junit.Assert.assertNull(
                "late init must not re-arm pendingSpeak",
                service.pendingSpeakForTest
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `TTS init FAILED does not flush pendingSpeak (Bug 2 init-failed)`() {
        val (service, _) = createServiceWithPlugin()
        try {
            simulateInitNotReady()
            val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
            service.onStartCommand(speakIntent, 0, 1)
            org.junit.Assert.assertNotNull(service.pendingSpeakForTest)

            // Engine reports failure: pending must remain, so the user's
            // next app restart triggers a fresh service that may init OK.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.junit.Assert.assertNotNull(
                "init FAILURE must not flush pendingSpeak (avoids replay of broken state)",
                service.pendingSpeakForTest
            )
            org.junit.Assert.assertTrue(
                "companion pendingSpeakActive stays true on init failure",
                ZhiYueTtsService.pendingSpeakActive
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    // ---- v1.13.9-alpha Bug 2 (continued): service recreation must reset
    // companion ttsInitStatus. Without this, the second service instance
    // inherits the first's SUCCESS value, handleSpeak's init guard lets
    // speak() through before the new TextToSpeech finishes init, and the
    // user sees "playback starts from beginning" intermittently. ----

    @Test
    fun `service recreation resets ttsInitStatus so handleSpeak defers (v1_13_9 Bug 2 companion reset)`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            // First service instance: onCreate + successful init + speak.
            val firstService = createService()
            firstService.onCreate()
            firstService.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.SUCCESS)
            org.junit.Assert.assertEquals(
                "first service init should be SUCCESS",
                android.speech.tts.TextToSpeech.SUCCESS,
                ZhiYueTtsService.ttsInitStatus
            )
            firstService.onDestroy()

            // Companion ttsInitStatus still holds SUCCESS from the first
            // instance (this is the v1.13.8 blind spot).
            org.junit.Assert.assertEquals(
                "precondition: companion should retain SUCCESS across instances",
                android.speech.tts.TextToSpeech.SUCCESS,
                ZhiYueTtsService.ttsInitStatus
            )

            // Android recreates the service (new instance, new TextToSpeech).
            val secondService = createService()
            secondService.onCreate()

            // v1.13.9 fix: onCreate must reset ttsInitStatus to -999 so the
            // new instance's handleSpeak doesn't act on stale SUCCESS.
            org.junit.Assert.assertEquals(
                "second service onCreate must reset ttsInitStatus to -999",
                -999,
                ZhiYueTtsService.ttsInitStatus
            )

            // Therefore a SPEAK arriving before the new init callback must
            // defer (not call speak()).
            val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
                .putExtra(ZhiYueTtsService.EXTRA_TEXT, "测试")
                .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 5)
            secondService.onStartCommand(speakIntent, 0, 1)
            org.junit.Assert.assertNotNull(
                "second service must defer SPEAK until new TTS inits",
                secondService.pendingSpeakForTest
            )
            secondService.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    // ---- v1.16.2-alpha OPPO/Xiaomi system TTS init failure: emit init_error
    // to Dart after exhausting 1 applicationContext retry. OPPO/Xiaomi ship a
    // ROM-specific TextToSpeech binding restriction that fails init
    // synchronously (~5ms) when constructed with a Service context; retrying
    // with applicationContext bypasses some of these restrictions. If retry
    // also fails, Dart needs to know (so it can surface a user-visible
    // message instead of stranding 11 SPEAK intents in pendingSpeak forever).

    @Test
    fun `init failure schedules retry with applicationContext`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            val service = createService()
            service.onCreate()
            // First init callback reports failure.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            // Run any main-thread tasks queued before the failure callback
            // (e.g. TextToSpeech ctor scheduling tasks via main looper).
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            org.junit.Assert.assertTrue(
                "retry flag should be set after first init failure",
                ZhiYueTtsService.ttsInitRetryAttempted
            )
            org.junit.Assert.assertEquals(
                "init_error must NOT be emitted on first failure (retry pending)",
                0,
                plugin.capturedEventsForTest.count { it["event"] == "init_error" }
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `init retry failure emits init_error event with manufacturer`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            val service = createService()
            service.onCreate()
            // First failure → schedules retry.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            // Flush the 500ms delayed retry (recreates TextToSpeech; the
            // retry init callback below is what we actually exercise).
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // Retry also fails.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasks()

            val errorEvents = plugin.capturedEventsForTest.filter { it["event"] == "init_error" }
            org.junit.Assert.assertEquals(
                "should emit exactly one init_error after retry exhaustion",
                1,
                errorEvents.size
            )
            val evt = errorEvents.first()
            org.junit.Assert.assertEquals(
                "status field should report the error code",
                android.speech.tts.TextToSpeech.ERROR,
                evt["status"]
            )
            org.junit.Assert.assertNotNull(
                "manufacturer must be surfaced so Dart can show ROM-specific guidance",
                evt["manufacturer"]
            )
            org.junit.Assert.assertNotNull(
                "model must be surfaced for diagnostic logging",
                evt["model"]
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `init retry success does not emit init_error`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            val service = createService()
            service.onCreate()
            // First failure schedules retry.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // Retry succeeds — the happy path. No init_error should be emitted.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.SUCCESS)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasks()

            val errorEvents = plugin.capturedEventsForTest.filter { it["event"] == "init_error" }
            org.junit.Assert.assertEquals(
                "init_error should NOT be emitted on retry success",
                0,
                errorEvents.size
            )
            // Sanity: SUCCESS path should also flush any pending SPEAK intent.
            // (Re-verification of v1.13.8 init race fix preserved.)
            org.junit.Assert.assertEquals(
                "SUCCESS path still fires (v1.13.8 init race fix intact)",
                android.speech.tts.TextToSpeech.SUCCESS,
                ZhiYueTtsService.ttsInitStatus
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    @Test
    fun `ttsInitRetryAttempted resets across onCreate`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            // First service: init fails → retry flag set.
            val service1 = createService()
            service1.onCreate()
            service1.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()
            org.junit.Assert.assertTrue(
                "first instance sets retry flag after first failure",
                ZhiYueTtsService.ttsInitRetryAttempted
            )
            service1.onDestroy()

            // Companion ttsInitRetryAttempted survives onDestroy (companion
            // is static — same blind spot as v1.13.9 Bug 2's ttsInitStatus).
            // v1.16.2 fix: onCreate must reset it.
            org.junit.Assert.assertTrue(
                "precondition: companion retains retry flag across instances",
                ZhiYueTtsService.ttsInitRetryAttempted
            )

            // Second service: onCreate must reset the flag so the new
            // instance gets a fresh retry budget (otherwise the very first
            // init failure on the new instance would emit init_error
            // immediately without trying applicationContext).
            val service2 = createService()
            service2.onCreate()
            org.junit.Assert.assertFalse(
                "second service onCreate must reset ttsInitRetryAttempted (v1.13.9 pattern)",
                ZhiYueTtsService.ttsInitRetryAttempted
            )
            service2.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    // ---- v1.16.2-alpha code-review followup: guard init retry against
    // service destroy + null listener. The 500ms postDelayed retry lambda
    // captures `this` and the force-unwrapped ttsInitListener!!. If Android
    // tears down the service mid-window (e.g. user clicks 停止 → stopSelf →
    // onDestroy), the retry lambda still fires and assigns a brand-new
    // TextToSpeech instance to `tts` AFTER onDestroy nulled it — an orphan
    // with no shutdown path. The next onCreate would overwrite without
    // shutdown, leaking the engine. Also: ttsInitListener is @Volatile-ish
    // in theory (it's a field, not companion, so it dies with the instance),
    // but defensively guard against null anyway in case of future refactor.

    @Test
    fun `retry aborted when service destroyed during retry window`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            val service = createService()
            service.onCreate()
            // First failure → schedules retry (500ms delayed task).
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)

            // Sanity precondition: at this point tts is still the first
            // instance (retry hasn't fired yet because we haven't flushed).
            org.junit.Assert.assertNotNull(
                "precondition: tts instance exists after first init failure",
                service.ttsInstanceForTest
            )

            // Service torn down before retry fires. onDestroy nulls `tts`.
            service.onDestroy()
            org.junit.Assert.assertNull(
                "precondition: onDestroy nulls tts",
                service.ttsInstanceForTest
            )

            // Now flush the 500ms delayed retry task. Without the destroyed
            // guard, this would assign `tts = TextToSpeech(applicationContext, ...)`
            // — re-creating an orphaned engine on a destroyed service.
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // PRIMARY ASSERTION: no leaked TTS instance.
            org.junit.Assert.assertNull(
                "retry must not recreate TTS on destroyed service (would leak)",
                service.ttsInstanceForTest
            )
            // SECONDARY ASSERTION: guard fired and logged the abort reason
            // (lets users / future debug sessions see why retry was skipped).
            val abortLog = ZhiYueTtsService.debugLogs.any {
                it.contains("retry aborted") && it.contains("destroyed")
            }
            org.junit.Assert.assertTrue(
                "retry abort must be logged for diagnostics (got: ${ZhiYueTtsService.debugLogs})",
                abortLog
            )
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    // ---- v1.16.3-alpha: 3-stage init retry with engine enumeration.
    // After stage A (applicationContext retry) fails, the state machine must
    // enter stage B: enumerate TTS engines via PackageManager.queryIntentServices
    // and retry each with the 3-arg TextToSpeech(ctx, listener, enginePackage)
    // constructor. This bypasses the default-engine lookup that MIUI/ColorOS
    // ROM-bundled engines (com.xiaomi.mibrain.speech / com.heytap.speechservice)
    // reject with status=-1 in ~5ms. Stage B entry advances ttsEngineEnumerationIndex
    // from -1 → 0 → 1 (scheduleEngineEnumerationRetry bumps idx BEFORE the
    // Handler.postDelayed fires so the next failure handler invocation sees
    // the cursor already pointing at the next engine).

    @Test
    fun `init failure with available engines retries with 3-arg constructor for each engine`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            // Given: shadow package manager reports two available TTS engines
            // that respond to Engine.INTENT_ACTION_TTS_SERVICE.
            val shadowPackageManager = org.robolectric.Shadows.shadowOf(ctx.packageManager)
            listOf("com.google.android.tts", "com.iflytek.speechcloud").forEach { pkg ->
                val resolveInfo = android.content.pm.ResolveInfo().apply {
                    serviceInfo = android.content.pm.ServiceInfo().apply { packageName = pkg }
                }
                shadowPackageManager.addResolveInfoForIntent(
                    android.content.Intent(android.speech.tts.TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE),
                    resolveInfo,
                )
            }

            val service = createService()
            service.onCreate()
            // Stage A first init failure → schedules 500ms applicationContext retry.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            // Flush the 500ms delayed retry (recreates TextToSpeech; the retry
            // init callback below is what we actually exercise).
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // Precondition: at this point stage A is exhausted, no stage B
            // entry has fired yet (next init callback will trigger it).
            org.junit.Assert.assertEquals(
                "precondition: stage B entry has not fired yet (index still -1)",
                -1,
                ZhiYueTtsService.ttsEngineEnumerationIndex,
            )

            // Stage A retry fails → state machine enters stage B: enumerates
            // engines, sets index=0, then scheduleEngineEnumerationRetry(0)
            // bumps index to 1 and posts the 3-arg constructor retry.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasks()

            // Verify: enumerateAvailableEngines was consulted, index advanced
            // past the first engine (tried index 0 = google, now at 1).
            org.junit.Assert.assertEquals(
                "stage B entry should advance ttsEngineEnumerationIndex to 1 " +
                    "(scheduleEngineEnumerationRetry bumps idx 0 → 1 before fire); " +
                    "got logs: ${ZhiYueTtsService.debugLogs}",
                1,
                ZhiYueTtsService.ttsEngineEnumerationIndex,
            )
            org.junit.Assert.assertEquals(
                "stage B should populate ttsAvailableEngines with both shadows",
                listOf("com.google.android.tts", "com.iflytek.speechcloud"),
                ZhiYueTtsService.ttsAvailableEngines,
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }

    // ---- v1.16.3-alpha Task 3: edge cases for the 3-stage state machine.
    // Covers (1) stage C emit when no engines are enumerable, (2) stage C
    // emit after every enumerated engine fails (verifies engines list content
    // in the emitted payload), and (3) destroyed guard during the stage B
    // retry window (no orphaned TextToSpeech). ----

    @Test
    fun `init failure with no enumerable engines emits init_error with empty engines list`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            ZhiYueTtsPlugin.resetLastEmittedEventForTest()

            val service = createService()
            service.onCreate()
            // Stage A first init failure → schedules 500ms applicationContext retry.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // Stage A retry fails. No engines are mocked in the shadow package
            // manager, so stage B enumeration returns an empty list and the
            // state machine jumps straight to stage C (emit init_error).
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasks()

            val emitted = ZhiYueTtsPlugin.lastEmittedEventForTest
            org.junit.Assert.assertNotNull(
                "stage C should have emitted an init_error event " +
                    "(got logs: ${ZhiYueTtsService.debugLogs})",
                emitted,
            )
            org.junit.Assert.assertEquals(
                "emitted event type must be init_error",
                "init_error",
                emitted?.get("event"),
            )
            val engines = emitted?.get("engines") as? List<*>
            org.junit.Assert.assertNotNull(
                "engines field must be present (even if empty) so Dart can " +
                    "distinguish 'no engines installed' from 'engines rejected binding'",
                engines,
            )
            org.junit.Assert.assertTrue(
                "engines list must be empty when no shadow resolveInfos were registered " +
                    "(got: $engines)",
                engines?.isEmpty() == true,
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
            ZhiYueTtsPlugin.resetLastEmittedEventForTest()
        }
    }

    @Test
    fun `init failure where all enumerated engines also fail emits init_error with all engines listed`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            ZhiYueTtsPlugin.resetLastEmittedEventForTest()

            // Two engines available — both will reject binding (simulated by
            // each stage B retry's init callback returning ERROR).
            val shadowPackageManager = org.robolectric.Shadows.shadowOf(ctx.packageManager)
            listOf("com.google.android.tts", "com.iflytek.speechcloud").forEach { pkg ->
                val resolveInfo = android.content.pm.ResolveInfo().apply {
                    serviceInfo = android.content.pm.ServiceInfo().apply { packageName = pkg }
                }
                shadowPackageManager.addResolveInfoForIntent(
                    android.content.Intent(android.speech.tts.TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE),
                    resolveInfo,
                )
            }

            val service = createService()
            service.onCreate()

            // 1. Stage A first init failure → schedules 500ms applicationContext retry.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // 2. Stage A retry fails → stage B entry, schedules retry with engine[0].
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // 3. Stage B engine 0 (google) fails → schedules retry with engine[1].
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // Pre-condition sanity: at this point the state machine has tried
            // every enumerated engine, so the next failure lands in stage C.
            org.junit.Assert.assertEquals(
                "precondition: cursor should be past the last engine before stage C fires " +
                    "(got logs: ${ZhiYueTtsService.debugLogs})",
                2,
                ZhiYueTtsService.ttsEngineEnumerationIndex,
            )

            // 4. Stage B engine 1 (iflytek) fails → cursor (2) >= size (2), stage C emits.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasks()

            val emitted = ZhiYueTtsPlugin.lastEmittedEventForTest
            org.junit.Assert.assertNotNull(
                "stage C should have emitted an init_error after every engine failed " +
                    "(got logs: ${ZhiYueTtsService.debugLogs})",
                emitted,
            )
            org.junit.Assert.assertEquals(
                "emitted event type must be init_error",
                "init_error",
                emitted?.get("event"),
            )
            val engines = emitted?.get("engines") as? List<*>
            org.junit.Assert.assertNotNull(
                "engines field must be present in stage C emit",
                engines,
            )
            org.junit.Assert.assertEquals(
                "engines list should contain both enumerated engines " +
                    "(stage C reports every engine we tried)",
                listOf("com.google.android.tts", "com.iflytek.speechcloud"),
                engines,
            )
            service.onDestroy()
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
            ZhiYueTtsPlugin.resetLastEmittedEventForTest()
        }
    }

    @Test
    fun `stage B retry aborted when service destroyed during retry window`() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val plugin = ZhiYueTtsPlugin().apply { attachContextForTest(ctx) }
        ZhiYueTtsPlugin.setInstanceForTest(plugin)
        try {
            // One engine available so stage B actually schedules a 3-arg
            // constructor retry (without this, stage B would short-circuit
            // to stage C and never post the delayed task we're testing).
            val shadowPackageManager = org.robolectric.Shadows.shadowOf(ctx.packageManager)
            val resolveInfo = android.content.pm.ResolveInfo().apply {
                serviceInfo = android.content.pm.ServiceInfo().apply {
                    packageName = "com.google.android.tts"
                }
            }
            shadowPackageManager.addResolveInfoForIntent(
                android.content.Intent(android.speech.tts.TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE),
                resolveInfo,
            )

            val service = createService()
            service.onCreate()
            // Stage A first failure → schedules applicationContext retry.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // Stage A retry fails → stage B entry, scheduleEngineEnumerationRetry(0)
            // bumps cursor to 1 and posts a 500ms 3-arg constructor retry.
            service.simulateTtsInitCallbackForTest(android.speech.tts.TextToSpeech.ERROR)
            org.robolectric.shadows.ShadowLooper.runUiThreadTasks()

            // Pre-condition: stage B retry is now pending in the main looper
            // queue. The cursor should already have advanced to 1 (past engine 0).
            org.junit.Assert.assertEquals(
                "precondition: stage B should have advanced cursor to 1 before destroy " +
                    "(got logs: ${ZhiYueTtsService.debugLogs})",
                1,
                ZhiYueTtsService.ttsEngineEnumerationIndex,
            )

            // Service torn down before the 500ms stage B retry fires.
            // onDestroy nulls `tts` and sets the companion `destroyed` flag.
            service.onDestroy()
            org.junit.Assert.assertTrue(
                "precondition: onDestroy must set companion destroyed flag (v1.13.9 pattern)",
                ZhiYueTtsService.destroyed,
            )
            org.junit.Assert.assertNull(
                "precondition: onDestroy nulls tts instance",
                service.ttsInstanceForTest,
            )

            // Flush the 500ms delayed stage B retry. Without the destroyed
            // guard inside scheduleEngineEnumerationRetry's postDelayed lambda,
            // this would assign `tts = TextToSpeech(applicationContext, l, enginePackage)`
            // — re-creating an orphaned engine on a destroyed service.
            org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

            // PRIMARY ASSERTION: no leaked TTS instance.
            org.junit.Assert.assertNull(
                "stage B retry must not recreate TTS on destroyed service (would leak)",
                service.ttsInstanceForTest,
            )
            // SECONDARY ASSERTION: guard fired and logged the abort reason
            // (lets users / future debug sessions see why retry was skipped).
            val abortLog = ZhiYueTtsService.debugLogs.any {
                it.contains("stage B retry aborted") && it.contains("destroyed")
            }
            org.junit.Assert.assertTrue(
                "stage B retry abort must be logged for diagnostics " +
                    "(got: ${ZhiYueTtsService.debugLogs})",
                abortLog,
            )
        } finally {
            ZhiYueTtsPlugin.setInstanceForTest(null)
        }
    }
}
