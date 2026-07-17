package dev.zhiyue.zhiyue.tts

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
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ZhiYueTtsServiceTest {

    @Test
    fun `service lifecycle - onCreate then onDestroy does not throw`() {
        // T6 skeleton: service has empty onCreate/onDestroy. Robolectric lets us
        // instantiate without going through startForegroundService; T10 will add
        // the real foreground notification (which requires ServiceController +
        // shadow NotificationManager).
        val service = ZhiYueTtsService()
        service.onCreate()
        service.onDestroy()
        // No exception = pass
        val logs = ShadowLog.getLogsForTag("ZhiYueTts")
        org.junit.Assert.assertTrue("Unexpected error logs: $logs",
            logs.none { it.type >= android.util.Log.ERROR })
    }

    @Test
    fun `STOP intent returns START_NOT_STICKY without throwing`() {
        val service = ZhiYueTtsService()
        service.onCreate()
        val stopIntent = android.content.Intent(ZhiYueTtsService.ACTION_STOP)
        val result = service.onStartCommand(stopIntent, 0, 1)
        org.junit.Assert.assertEquals(
            android.app.Service.START_NOT_STICKY, result)
        service.onDestroy()
    }
}
