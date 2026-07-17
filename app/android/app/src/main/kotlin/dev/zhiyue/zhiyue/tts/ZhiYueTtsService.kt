package dev.zhiyue.zhiyue.tts

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
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
import androidx.core.app.NotificationCompat
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

    /// Legacy (API < 26) path uses [AudioManager.OnAudioFocusChangeListener] instead
    /// of [AudioFocusRequest]. Retained to avoid GC and to allow abandon on destroy.
    @Suppress("DEPRECATION")
    private var legacyAudioFocusListener: AudioManager.OnAudioFocusChangeListener? = null

    private var audioManager: AudioManager? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var telephonyCallback: TelephonyCallback? = null

    /// Set by ZhiYueTtsPlugin (or test) to receive state/progress events.
    /// Null until plugin wires it (T13 ServiceConnection binds; for now plugin
    /// could set via reflection or a static singleton — left as TODO).
    internal var eventEmitter: ((Map<String, Any?>) -> Unit)? = null

    private fun emit(event: Map<String, Any?>) {
        eventEmitter?.invoke(event)
    }

    private var isForeground = false

    internal val isForegroundForTest: Boolean
        get() = isForeground

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
                        emit(mapOf("event" to "state", "state" to "speaking", "utteranceId" to (utteranceId ?: "")))
                    }
                    override fun onDone(utteranceId: String?) {
                        Log.d(TAG, "utterance onDone $utteranceId")
                        emit(mapOf("event" to "done", "utteranceId" to (utteranceId ?: "")))
                    }
                    override fun onError(utteranceId: String?) {
                        Log.e(TAG, "utterance onError $utteranceId")
                        emit(mapOf("event" to "error", "utteranceId" to (utteranceId ?: "")))
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
        // LAST: start foreground (must complete within 5s for Android 12+ ANR).
        //国产 ROM (华为/小米/OPPO/vivo) 会在用户没有感知到前台 service 时 kill 进程，
        // 因此 onCreate 末尾立即 startForeground，type 为 MEDIA_PLAYBACK。
        ensureNotificationChannel()
        val notification = buildNotification("智阅朗读", "准备朗读")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isForeground = true
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
        emit(mapOf("event" to "state", "state" to "paused"))
    }

    private fun handleResume() {
        // Dart side re-sends SPEAK intent with current sentence index (no native resume).
    }

    private fun handleStop() {
        tts?.stop()
        updatePlaybackState(PlaybackStateCompat.STATE_STOPPED)
        mediaSession?.isActive = false
        emit(mapOf("event" to "state", "state" to "stopped"))
        if (isForeground) {
            stopForeground(true)
            isForeground = false
        }
    }

    override fun onDestroy() {
        if (isForeground) {
            stopForeground(true)
            isForeground = false
        }
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
        legacyAudioFocusListener?.let { listener ->
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus(listener)
        }
        legacyAudioFocusListener = null
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
            val result = audioManager?.requestAudioFocus(audioFocusRequest!!)
            if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                audioFocusRequestedForTest = true
            } else {
                Log.w(TAG, "AudioFocus request denied: $result")
                audioFocusRequest = null
            }
        } else {
            val legacyListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
                when (focusChange) {
                    AudioManager.AUDIOFOCUS_LOSS,
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> handlePause()
                }
            }
            @Suppress("DEPRECATION")
            val result = audioManager?.requestAudioFocus(
                legacyListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
            if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                audioFocusRequestedForTest = true
                // OnAudioFocusChangeListener target needs to be retained; abandonAudioFocus
                // in onDestroy requires the same listener reference.
                @Suppress("DEPRECATION")
                legacyAudioFocusListener = legacyListener
            } else {
                Log.w(TAG, "Legacy AudioFocus request denied: $result")
            }
        }
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

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "智阅朗读",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "朗读控制通知"
                setShowBadge(false)
            }
            val nm = getSystemService(NOTIFICATION_SERVICE) as? NotificationManager
            nm?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, content: String): Notification {
        // FLAG_IMMUTABLE was added in API 23 (M); on API 21-22 it must be 0
        // (FLAG_MUTABLE was added in API 31, but we don't need mutability).
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE else 0
        val pauseIntent = PendingIntent.getService(
            this, 0,
            Intent(this, ZhiYueTtsService::class.java).setAction(ACTION_PAUSE),
            pendingIntentFlags
        )
        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, ZhiYueTtsService::class.java).setAction(ACTION_STOP),
            pendingIntentFlags
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(content)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_media_pause, "暂停", pauseIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "停止", stopIntent)
            .also { builder ->
                mediaSession?.sessionToken?.let { token ->
                    builder.setStyle(
                        androidx.media.app.NotificationCompat.MediaStyle()
                            .setMediaSession(token)
                    )
                }
            }
            .build()
    }

    companion object {
        private const val TAG = "ZhiYueTts"

        private const val NOTIFICATION_ID = 0x7D00
        private const val CHANNEL_ID = "zhiyue_tts"

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
