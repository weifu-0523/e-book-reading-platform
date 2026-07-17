package dev.zhiyue.zhiyue.tts

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

/// v1.13 TTS service — owns TextToSpeech + MediaSession + AudioFocus +
/// foreground notification. Created on first 「朗读」 click via
/// [ZhiYueTtsPlugin.ensureServiceCreated] → `startForegroundService`.
///
/// Lifecycle:
///   - onCreate: construct TextToSpeech, MediaSession, AudioFocus,
///     PhoneStateListener. **Last step:** startForeground(notification).
///     All in <100ms to meet Android 12+ ANR 5s threshold.
///   - onStartCommand: dispatch SPEAK/PAUSE/RESUME/STOP intents.
///   - onDestroy: release all resources in reverse order.
///
/// T6 skeleton: lifecycle only (no resources). T7 adds TextToSpeech,
/// T8 MediaSession, T9 AudioFocus + PhoneStateListener, T10 startForeground.
class ZhiYueTtsService : Service() {

    override fun onCreate() {
        super.onCreate()
        // T7: TextToSpeech. T8: MediaSession. T9: AudioFocus. T10: FGS.
        Log.i(TAG, "onCreate (T6 skeleton — no resources yet)")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand: ${intent?.action}")
        // T7-T11 implement per-action dispatch.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy")
        // T7-T11 release resources.
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val TAG = "ZhiYueTts"

        const val ACTION_SPEAK = "dev.zhiyue.tts.SPEAK"
        const val ACTION_PAUSE = "dev.zhiyue.tts.PAUSE"
        const val ACTION_RESUME = "dev.zhiyue.tts.RESUME"
        const val ACTION_STOP = "dev.zhiyue.tts.STOP"

        const val EXTRA_TEXT = "text"
        const val EXTRA_LOCALE = "locale"
        const val EXTRA_SENTENCE_INDEX = "sentenceIndex"
        const val EXTRA_UTTERANCE_ID = "utteranceId"
    }
}
