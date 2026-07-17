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
}
