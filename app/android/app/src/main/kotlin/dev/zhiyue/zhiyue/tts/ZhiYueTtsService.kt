package dev.zhiyue.zhiyue.tts

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.util.Locale

/// v1.13 TTS service — owns TextToSpeech + MediaSession + AudioFocus +
/// foreground notification. Created on first 「朗读」 click via
/// [ZhiYueTtsPlugin.ensureServiceCreated] → `startForegroundService`.
///
/// T7 state: owns TextToSpeech + UtteranceProgressListener.
/// T8 will add MediaSession; T9 AudioFocus + PhoneStateListener; T10 startForeground.
class ZhiYueTtsService : Service() {

    private var tts: TextToSpeech? = null

    /// Test-only accessor.
    internal val ttsInstanceForTest: TextToSpeech?
        get() = tts

    override fun onCreate() {
        super.onCreate()
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                Log.i(TAG, "TextToSpeech engine ready")
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        Log.d(TAG, "utterance onStart $utteranceId")
                    }
                    override fun onDone(utteranceId: String?) {
                        Log.d(TAG, "utterance onDone $utteranceId")
                    }
                    override fun onError(utteranceId: String?) {
                        Log.e(TAG, "utterance onError $utteranceId")
                    }
                })
            } else {
                Log.e(TAG, "TextToSpeech init failed status=$status")
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand: ${intent?.action}")
        when (intent?.action) {
            ACTION_SPEAK -> handleSpeak(intent)
            ACTION_PAUSE -> handlePause()
            ACTION_RESUME -> handleResume()
            ACTION_STOP -> {
                handleStop()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun handleSpeak(intent: Intent) {
        val text = intent.getStringExtra(EXTRA_TEXT) ?: return
        val locale = intent.getStringExtra(EXTRA_LOCALE) ?: "zh-CN"
        val idx = intent.getIntExtra(EXTRA_SENTENCE_INDEX, 0)
        val utteranceId = "sent_$idx"
        tts?.language = Locale.forLanguageTag(locale)
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    private fun handlePause() {
        // Android TextToSpeech has no native pause; stop and let Dart track position.
        tts?.stop()
    }

    private fun handleResume() {
        // Dart side re-sends SPEAK intent with current sentence index (no native resume).
    }

    private fun handleStop() {
        tts?.stop()
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
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
