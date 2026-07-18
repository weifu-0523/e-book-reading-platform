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

    private fun emit(event: Map<String, Any?>) {
        // v1.13.7-alpha Bug 5 (P0): every emit reads the CURRENT plugin
        // instance via companion lookup. Previously onCreate cached
        // `eventEmitter = plugin::emitEvent` as a method reference holding
        // plugin_A; after plugin rebinding (Activity recreate / Flutter
        // engine restart, triggered e.g. by "导入新书"), plugin_A.channel
        // is nulled out by onDetachedFromEngine but the service kept
        // invoking plugin_A.emitEvent — every event hit the channel_null
        // branch and was silently dropped. Dart's TtsPlaybackController
        // never saw the done event, so multi-sentence playback halted
        // after queue[0].
        //
        // Reading the companion at emit-time guarantees we always reach
        // the latest attached plugin (plugin_B post-rebind).
        ZhiYueTtsPlugin.instance?.emitEvent(event)
            ?: debugLog("EMIT_DROPPED reason=plugin_instance_null event_type=${event["event"]}")
    }

    /// Test-only: invoke [emit] directly to verify routing without spinning
    /// up a real TextToSpeech engine.
    internal fun simulateEmitForTest(event: Map<String, Any?>) {
        emit(event)
    }

    private var isForeground = false

    internal val isForegroundForTest: Boolean
        get() = isForeground

    internal var audioFocusRequestedForTest = false
        private set
    internal var phoneStateListenerRegisteredForTest = false
        private set

    /// v1.13.7-alpha Bug 4: last rate/pitch/volume applied to the engine.
    /// Surfaced for test verification (Robolectric's TextToSpeech shadow
    /// doesn't record setSpeechRate/setPitch calls, so we capture them here).
    internal var lastAppliedRateForTest: Float = 0f
        private set
    internal var lastAppliedPitchForTest: Float = 0f
        private set
    internal var lastAppliedVolumeForTest: Float = 0f
        private set

    override fun onCreate() {
        super.onCreate()
        debugLog("onCreate start")
        try {
            // v1.13.7-alpha Bug 5: emit() reads ZhiYueTtsPlugin.instance at
            // call time (no cached reference), so there is no early-wire
            // step anymore. We still log whether a plugin is currently
            // attached to help diagnose startup-order regressions.
            if (ZhiYueTtsPlugin.instance != null) {
                debugLog("ZhiYueTtsPlugin.instance available; emit() will use companion lookup")
            } else {
                debugLog("WARN: ZhiYueTtsPlugin.instance is null in onCreate")
            }
            debugLog("before TextToSpeech ctor")
            tts = TextToSpeech(this) { status ->
                ttsInitStatus = status
                debugLog("TTS init callback status=$status")
                if (status == TextToSpeech.SUCCESS) {
                    Log.i(TAG, "TextToSpeech engine ready")
                    tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {
                            utteranceCallbacks.add("onStart:$utteranceId")
                            debugLog("utterance onStart $utteranceId")
                            emit(mapOf("event" to "state", "state" to "speaking", "utteranceId" to (utteranceId ?: "")))
                        }
                        override fun onDone(utteranceId: String?) {
                            utteranceCallbacks.add("onDone:$utteranceId")
                            debugLog("utterance onDone $utteranceId")
                            emit(mapOf("event" to "done", "utteranceId" to (utteranceId ?: "")))
                        }
                        override fun onError(utteranceId: String?) {
                            utteranceCallbacks.add("onError:$utteranceId")
                            debugLog("utterance onError $utteranceId")
                            emit(mapOf("event" to "error", "utteranceId" to (utteranceId ?: "")))
                        }
                    })
                } else {
                    debugLog("TTS init FAILED status=$status")
                    Log.e(TAG, "TextToSpeech init failed status=$status")
                }
            }
            debugLog("after TextToSpeech ctor, tts=$tts")
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
            debugLog("MediaSession ready")
            updatePlaybackState(PlaybackStateCompat.STATE_NONE)
            setupAudioFocus()
            debugLog("AudioFocus setup done, requested=$audioFocusRequestedForTest")
            try {
                setupPhoneStateListener()
                debugLog("PhoneStateListener setup done")
            } catch (e: SecurityException) {
                phoneStateListenerSetupSkipped = true
                debugLog("PhoneStateListener setup skipped: SecurityException ${e.message}")
                Log.w(TAG, "PhoneStateListener setup skipped (permission denied)", e)
            }
            // LAST: start foreground (must complete within 5s for Android 12+ ANR).
            ensureNotificationChannel()
            val notification = buildNotification("智阅朗读", "准备朗读")
            debugLog("before startForeground, SDK=${Build.VERSION.SDK_INT}")
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                startForegroundCompleted = true
                isForeground = true
                debugLog("startForeground SUCCESS")
            } catch (e: Exception) {
                debugLog("startForeground FAILED: ${e.javaClass.simpleName}: ${e.message}")
                Log.e(TAG, "startForeground failed", e)
                // Re-throw so the system marks this service creation as failed
                // (otherwise onStartCommand will still be called on a half-broken service).
                throw e
            }
            onCreateCompleted = true
            debugLog("onCreate complete")
        } catch (e: Exception) {
            onCreateException = "${e.javaClass.simpleName}: ${e.message}"
            debugLog("onCreate EXCEPTION: ${e.javaClass.simpleName}: ${e.message}")
            Log.e(TAG, "onCreate exception", e)
            // Don't re-throw: let Android call onStartCommand which will fail
            // gracefully; re-throwing would crash the service process.
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        onStartCommandCount++
        lastStartCommandAction = intent?.action
        debugLog("onStartCommand #$onStartCommandCount action=${intent?.action}")
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
        debugLog("handleSpeak textLen=${text.length} tts=$tts initStatus=$ttsInitStatus")
        if (tts == null) {
            debugLog("handleSpeak ABORT: tts is null")
            return
        }
        val locale = intent.getStringExtra(EXTRA_LOCALE) ?: "zh-CN"
        val idx = intent.getIntExtra(EXTRA_SENTENCE_INDEX, 0)
        // v1.13.7-alpha Bug 4: apply rate/pitch/volume from Intent extras.
        // Dart side piggy-backs cached settings onto each SPEAK intent
        // because Kotlin's setRate/setPitch/setVolume MethodChannel handlers
        // are no-ops (historical v1.13.0 oversight). Coerce to engine-safe
        // ranges to defend against stale/malicious values.
        val rate = intent.getDoubleExtra(EXTRA_RATE, 1.0)
            .toFloat()
            .coerceIn(0.1f, 5.0f)
        val pitch = intent.getDoubleExtra(EXTRA_PITCH, 1.0)
            .toFloat()
            .coerceIn(0.5f, 2.0f)
        val volume = intent.getDoubleExtra(EXTRA_VOLUME, 1.0)
            .toFloat()
            .coerceIn(0.0f, 1.0f)
        lastAppliedRateForTest = rate
        lastAppliedPitchForTest = pitch
        lastAppliedVolumeForTest = volume
        tts?.setSpeechRate(rate)
        tts?.setPitch(pitch)
        applyVolumeToStream(volume)
        debugLog("apply rate=$rate pitch=$pitch volume=$volume")
        val utteranceId = "sent_$idx"
        val langResult = tts?.setLanguage(Locale.forLanguageTag(locale))
        debugLog("setLanguage($locale) -> $langResult (0=ok, -1=missing_data, -2=not_supported)")
        val speakRet = tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId) ?: -99
        ttsLastSpeakReturn = speakRet
        debugLog("speak() returned $speakRet (0=success, -1=error)")
        updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
        updateMetadata("智阅朗读", "朗读中")
    }

    /// v1.13.7-alpha Bug 4: Android TextToSpeech has no setVolume API, so we
    /// scale the system STREAM_MUSIC volume proportionally. Known limitation:
    /// this changes the user's media volume (CHANGELOG'd as a trade-off for
    /// using the platform engine without audio_session).
    private fun applyVolumeToStream(volume: Float) {
        val am = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return
        val target = (max * volume).toInt().coerceIn(0, max)
        am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
    }

    private fun handlePause() {
        // Android TextToSpeech has no native pause; stop and let Dart track position.
        tts?.stop()
        updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
        emit(mapOf("event" to "state", "state" to "paused"))
        // v1.13.7-alpha Bug 1: refresh the notification so the toggle button
        // flips from pause → play while playback is paused.
        refreshNotification(content = "已暂停")
    }

    private fun handleResume() {
        // v1.13.7-alpha Bug 1: previously empty — Kotlin never told Dart to
        // resume, so notification-bar play taps after a pause were lost.
        // Android TextToSpeech has no native resume; we emit a resume_request
        // event and let Dart re-drive SPEAK for the current sentence.
        debugLog("handleResume emit resume_request")
        emit(mapOf("event" to "resume_request"))
        updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
        updateMetadata("智阅朗读", "朗读中")
        // Refresh the notification so the toggle button flips play → pause.
        refreshNotification(content = "朗读中")
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
        // v1.13.7-alpha Bug 1: notification bar toggle button flips between
        // pause (while PLAYING) and play (while PAUSED). Some ROMs auto-flip
        // based on MediaSession state, but most don't — drive it explicitly
        // from the current playback state so users always see the right icon.
        val currentPlayState = mediaSession?.controller?.playbackState?.state
        val isPlaying = currentPlayState == PlaybackStateCompat.STATE_PLAYING
        val toggleAction = if (isPlaying) ACTION_PAUSE else ACTION_RESUME
        val toggleIcon = if (isPlaying) android.R.drawable.ic_media_pause
                         else android.R.drawable.ic_media_play
        val toggleLabel = if (isPlaying) "暂停" else "继续"
        // v1.13.7-alpha Bug 1: combine FLAG_UPDATE_CURRENT with the request
        // code 0 so the toggle PendingIntent's Intent action is updated
        // in-place — without this the first-built intent (whichever action
        // won the race) sticks and the toggle button keeps firing PAUSE
        // even after we flip to PAUSED.
        val toggleIntent = PendingIntent.getService(
            this, 0,
            Intent(this, ZhiYueTtsService::class.java).setAction(toggleAction),
            pendingIntentFlags or PendingIntent.FLAG_UPDATE_CURRENT
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
            .addAction(toggleIcon, toggleLabel, toggleIntent)
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

    /// Test-only: builds a fresh notification with the current playback state
    /// so tests can assert the toggle icon/action label without going through
    /// the full startForeground path.
    internal fun buildNotificationForTest(title: String, content: String): Notification =
        buildNotification(title, content)

    /// v1.13.7-alpha Bug 1: re-posts the notification so the toggle button
    /// reflects the latest playback state after pause/resume. No-op if the
    /// system can't hand back a [NotificationManager] (defensive — should
    /// never happen on a real device).
    private fun refreshNotification(title: String = "智阅朗读", content: String = "朗读中") {
        if (!isForeground) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as? NotificationManager ?: return
        try {
            nm.notify(NOTIFICATION_ID, buildNotification(title, content))
        } catch (e: Exception) {
            debugLog("refreshNotification failed: ${e.javaClass.simpleName}: ${e.message}")
        }
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
        // v1.13.7-alpha Bug 4: speak Intent extras for rate/pitch/volume.
        const val EXTRA_RATE = "rate"
        const val EXTRA_PITCH = "pitch"
        const val EXTRA_VOLUME = "volume"

        // ---- v1.13.1-alpha debug instrumentation ----
        // Companion fields so they survive the service being killed and
        // restarted by Android — the plugin can read them via getDebugState
        // even after onCreate throws.
        val debugLogs = mutableListOf<String>()
        var onCreateCompleted: Boolean = false
        var onCreateException: String? = null
        var startForegroundCompleted: Boolean = false
        var ttsInitStatus: Int = -999  // -999 = callback never fired
        var ttsLastSpeakReturn: Int = -999
        var onStartCommandCount: Int = 0
        var lastStartCommandAction: String? = null
        val utteranceCallbacks = mutableListOf<String>()

        // v1.13.3-alpha: true when setupPhoneStateListener threw SecurityException
        // (READ_PHONE_STATE denied — common on Chinese ROMs). Auto-pause on
        // incoming call is disabled in this case; surfaced via getDebugState so
        // the user can see why multi-sentence playback "used to fail" if it
        // regresses.
        var phoneStateListenerSetupSkipped: Boolean = false

        fun debugLog(msg: String) {
            val ts = System.currentTimeMillis()
            // Take only last 100 entries to bound memory.
            synchronized(debugLogs) {
                debugLogs.add("[$ts] $msg")
                while (debugLogs.size > 100) debugLogs.removeAt(0)
            }
            Log.d(TAG, msg)
        }
    }
}
