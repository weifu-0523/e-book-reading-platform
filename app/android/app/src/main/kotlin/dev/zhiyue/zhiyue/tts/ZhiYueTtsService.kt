package dev.zhiyue.zhiyue.tts

import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.IBinder
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
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

    private var mediaSession: MediaSessionCompat? = null

    /// Test-only accessor.
    internal val mediaSessionForTest: MediaSessionCompat?
        get() = mediaSession

    private var audioFocusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var telephonyCallback: TelephonyCallback? = null

    internal var audioFocusRequestedForTest = false
        private set
    internal var phoneStateListenerRegisteredForTest = false
        private set

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
        mediaSession = MediaSessionCompat(this, "zhiyue-tts").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() { handleResume() }
                override fun onPause() { handlePause() }
                override fun onStop() { handleStop(); stopSelf() }
            })
            isActive = true
        }
        updatePlaybackState(PlaybackStateCompat.STATE_NONE)
        setupAudioFocus()
        setupPhoneStateListener()
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
        // Guard: if TTS init failed or isn't ready yet, don't update MediaSession
        // to STATE_PLAYING — that would mislead the lock screen into showing
        // "playing" while no audio is actually being produced.
        if (tts == null) return
        val locale = intent.getStringExtra(EXTRA_LOCALE) ?: "zh-CN"
        val idx = intent.getIntExtra(EXTRA_SENTENCE_INDEX, 0)
        val utteranceId = "sent_$idx"
        tts?.language = Locale.forLanguageTag(locale)
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
        updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
        updateMetadata("智阅朗读", "朗读中")
    }

    private fun handlePause() {
        // Android TextToSpeech has no native pause; stop and let Dart track position.
        tts?.stop()
        updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
    }

    private fun handleResume() {
        // Dart side re-sends SPEAK intent with current sentence index (no native resume).
    }

    private fun handleStop() {
        tts?.stop()
        updatePlaybackState(PlaybackStateCompat.STATE_STOPPED)
        mediaSession?.isActive = false
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        mediaSession?.run {
            isActive = false
            release()
        }
        mediaSession = null
        audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
        audioFocusRequest = null
        audioFocusRequestedForTest = false

        val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        if (tm != null) {
            telephonyCallback?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) tm.unregisterTelephonyCallback(it)
            }
            phoneStateListener?.let {
                @Suppress("DEPRECATION")
                tm.listen(it, PhoneStateListener.LISTEN_NONE)
            }
        }
        telephonyCallback = null
        phoneStateListener = null
        phoneStateListenerRegisteredForTest = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun updatePlaybackState(state: Int) {
        val stateBuilder = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_STOP
            )
            .setState(state, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1.0f)
        mediaSession?.setPlaybackState(stateBuilder.build())
    }

    private fun updateMetadata(title: String, artist: String) {
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .build()
        mediaSession?.setMetadata(metadata)
    }

    private fun setupAudioFocus() {
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attrs)
                .setOnAudioFocusChangeListener { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_LOSS,
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> handlePause()
                        // No auto-resume on focus gain (let user re-click)
                    }
                }
                .build()
            audioManager?.requestAudioFocus(audioFocusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
        audioFocusRequestedForTest = true
    }

    private fun setupPhoneStateListener() {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) {
                    if (state == TelephonyManager.CALL_STATE_RINGING) handlePause()
                }
            }
            tm.registerTelephonyCallback(mainExecutor, telephonyCallback!!)
        } else {
            phoneStateListener = @Suppress("DEPRECATION") object : PhoneStateListener() {
                @Deprecated("deprecated in API 31")
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    if (state == TelephonyManager.CALL_STATE_RINGING) handlePause()
                }
            }
            @Suppress("DEPRECATION")
            tm.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
        }
        phoneStateListenerRegisteredForTest = true
    }

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
