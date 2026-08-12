package dev.zhiyue.zhiyue.tts

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// v1.13 Android TTS plugin — replaces audio_service + audio_session +
/// flutter_tts (which trigger Chinese ROM startup kill when registered
/// automatically via GeneratedPluginRegistrant).
///
/// **CRITICAL INVARIANT (v1.12.3-alpha 4-attempt lesson):**
/// `onAttachedToEngine` MUST be empty. No system service construction,
/// no MediaSession, no AudioFocus, no startForeground. All system
/// bindings happen inside [ZhiYueTtsService.onCreate], which only runs
/// after the user clicks 「朗读」 (user-gesture exemption for Android 12+).
///
/// DO NOT add any `init {}` block or top-level val that touches Android
/// framework singletons. This is the #1 rule of this file.
///
/// **v1.13.5-alpha pipeline rewrite:** replaced EventChannel with
/// MethodChannel reverse callbacks. v1.13.4-alpha diagnostic data showed
/// `emitCount=2, dartReceivedCount=0` — `sink.success()` returned without
/// throwing on the Kotlin side, but the binary messenger silently dropped
/// the envelope before it reached Dart's `_handleEvent`. EventChannel and
/// MethodChannel share the same binary messenger, but the invokeMethod
/// path goes through different code paths in Flutter's runtime; using
/// `channel.invokeMethod("onTtsEvent", event)` lets us detect failures
/// via try/catch + new counters instead of silent drops.
class ZhiYueTtsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    /// Test-only: whether [ZhiYueTtsService] has been created via init call.
    /// Production code shouldn't read this; tests verify the lazy invariant.
    internal var isServiceCreated: Boolean = false
        private set

    /// v1.13.1-alpha debug: last exception message from [ensureServiceStarted].
    /// Surfaced to Dart via `getDebugState` so the user can paste it back
    /// without needing adb / logcat.
    internal var lastStartError: String? = null
        private set

    /// v1.13.1-alpha debug: how many times `init` / `speak` have been invoked
    /// from Dart. Lets us confirm the MethodChannel actually received calls.
    internal var initCallCount: Int = 0
        private set
    internal var speakCallCount: Int = 0
        private set

    /// v1.13.5-alpha pipeline instrumentation (replaces v1.13.4 counters).
    ///
    /// v1.13.4 diagnostic data confirmed `emitCount=2, dartReceivedCount=0`
    /// — Kotlin `sink.success()` returned cleanly but events never arrived
    /// at Dart's `_handleEvent`. This pointed to EventChannel binary
    /// messenger loss on certain Chinese ROMs. v1.13.5 switches to
    /// MethodChannel reverse callbacks and adds new counters to verify
    /// the new pipeline:
    ///   * [invokeAttemptCount] — times emitEvent tried channel.invokeMethod
    ///   * [invokeSucceededCount] — times invokeMethod returned without throw
    ///   * [invokeExceptionCount] — times invokeMethod threw (real failure)
    ///   * [invokeChannelNullCount] — times channel was null (attach race)
    ///   * [onListenCalled] — kept for parity, always true post-attach now
    ///
    /// v1.13.6-alpha: v1.13.5 production diagnostic data showed all 6
    /// invokeMethod calls threw `RuntimeException: Methods marked with
    /// @UiThread must be executed on the main thread. Current thread:
    /// binder:29456_X`. Android TTS utterance callbacks (onStart/onDone)
    /// fire on binder threads, but Flutter MethodChannel.invokeMethod is
    /// annotated @UiThread. emitEvent now detects non-main threads and
    /// posts to the main thread via Handler(Looper.getMainLooper()).post.
    /// [invokePostedToMainThreadCount] tracks how often the post path
    /// triggered — production should see this > 0 (utterances come from
    /// binder thread); unit tests on Robolectric's main thread should see 0.
    internal var invokeAttemptCount: Int = 0
        private set
    internal var invokeSucceededCount: Int = 0
        private set
    internal var invokeExceptionCount: Int = 0
        private set
    internal var invokeChannelNullCount: Int = 0
        private set
    internal var invokePostedToMainThreadCount: Int = 0
        private set
    internal var onListenCalled: Boolean = false
        private set

    /// v1.16.2-alpha: test-only capture of every event passed to [emitEvent].
    /// Production ignores this list (memory cost is negligible — service
    /// emits <100 events per session). Tests assert on this to verify which
    /// event types reached the plugin without spinning up a real binary
    /// messenger. Counter-based assertions (invokeAttemptCount etc.) can't
    /// distinguish event types, which is why we need the full capture.
    internal val capturedEventsForTest: MutableList<Map<String, Any?>> = mutableListOf()

    /// v1.13.4 legacy counters kept (always 0 in v1.13.5+) for one release
    /// so the Dart pretty-printer doesn't blow up if a stale field is read
    /// during version-skew debugging.
    internal var emitCount: Int = 0
        private set
    internal var emitDroppedCount: Int = 0
        private set

    /// Held context. In production this is assigned by
    /// [onAttachedToEngine]; in tests by [attachContextForTest].
    internal var contextForTest: Context? = null
        private set

    /// Test infrastructure: lets a Robolectric test hand the plugin an
    /// Application context without spinning up a full Flutter engine.
    fun attachContextForTest(ctx: Context) {
        contextForTest = ctx
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // CRITICAL: do NOT construct TextToSpeech / MediaSession / AudioFocus /
        // startForeground here. Just bind channels.
        instance = this
        contextForTest = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.zhiyue.tts").also {
            it.setMethodCallHandler(this)
        }
        // v1.13.5-alpha: event delivery is now via MethodChannel reverse
        // callback (channel.invokeMethod("onTtsEvent", event)). No EventChannel.
        onListenCalled = true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = contextForTest ?: run {
            result.error("NO_CONTEXT", "Plugin not attached", null)
            return
        }
        when (call.method) {
            "init" -> {
                initCallCount++
                val ok = ensureServiceStarted(ctx)
                if (ok) {
                    result.success(null)
                } else {
                    result.error("SERVICE_START_FAILED", lastStartError, null)
                }
            }
            "speak" -> {
                speakCallCount++
                val ok = ensureServiceStarted(ctx)
                if (!ok) {
                    result.error("SERVICE_START_FAILED", lastStartError, null)
                    return
                }
                @Suppress("UNCHECKED_CAST")
                val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                val text = args["text"] as? String ?: ""
                val intent = Intent(ctx, ZhiYueTtsService::class.java)
                    .setAction(ZhiYueTtsService.ACTION_SPEAK)
                    .putExtra(ZhiYueTtsService.EXTRA_TEXT, text)
                    .putExtra(ZhiYueTtsService.EXTRA_LOCALE, args["locale"] as? String ?: "zh-CN")
                    .putExtra(
                        ZhiYueTtsService.EXTRA_SENTENCE_INDEX,
                        (args["sentenceIndex"] as? Number)?.toInt() ?: 0
                    )
                    // v1.13.7-alpha Bug 4: forward cached rate/pitch/volume so
                    // the Service can apply them before each utterance. Dart
                    // side caches these in SelfBuiltTtsServiceImpl and re-sends
                    // on every speak call (Kotlin setRate/setPitch/setVolume
                    // MethodChannel handlers remain no-ops; this is the real
                    // delivery path).
                    .putExtra(
                        ZhiYueTtsService.EXTRA_RATE,
                        (args["rate"] as? Number)?.toDouble() ?: 1.0
                    )
                    .putExtra(
                        ZhiYueTtsService.EXTRA_PITCH,
                        (args["pitch"] as? Number)?.toDouble() ?: 1.0
                    )
                    .putExtra(
                        ZhiYueTtsService.EXTRA_VOLUME,
                        (args["volume"] as? Number)?.toDouble() ?: 1.0
                    )
                    // v1.14.0-alpha T4: forward voiceId so handleSpeak can
                    // apply it before setLanguage (avoids engine-reset races).
                    // Null when the user hasn't picked a voice — service then
                    // falls back to the cached _voiceOverride or engine default.
                val voiceId = args["voiceId"] as? String
                if (voiceId != null) {
                    intent.putExtra(ZhiYueTtsService.EXTRA_VOICE_ID, voiceId)
                }
                try {
                    ctx.startService(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SPEAK_INTENT_FAILED", "${e.javaClass.simpleName}: ${e.message}", null)
                }
            }
            "pause" -> forwardAction(ctx, ZhiYueTtsService.ACTION_PAUSE, result)
            "resume" -> forwardAction(ctx, ZhiYueTtsService.ACTION_RESUME, result)
            "stop" -> forwardAction(ctx, ZhiYueTtsService.ACTION_STOP, result)
            // T12+ will wire these to the service. Until then, ack so the
            // Dart side doesn't see `notImplemented` for control plumbing.
            "setRate", "setPitch", "setVolume", "setLanguage" -> result.success(null)
            "isLanguageAvailable", "isLanguageInstalled" -> result.success(true)
            "getDefaultEngine" -> result.success("com.google.android.tts")
            // v1.14.0-alpha T4: voice selection. These handlers need to
            // reach the live service (engine voices / setVoice mutate the
            // TextToSpeech state); we go through ZhiYueTtsService.instance
            // rather than firing an Intent (which can't return a list or
            // apply voice atomically). If the service isn't running yet,
            // getVoices returns an empty list and setVoice returns false —
            // Dart side will see these and prompt the user to start TTS.
            "getVoices" -> {
                val service = ZhiYueTtsService.instance
                if (service == null) {
                    result.success(emptyList<Map<String, Any>>())
                } else {
                    service.handleGetVoices(result)
                }
            }
            "setVoice" -> {
                val voiceId = call.argument<String>("voiceId")
                val service = ZhiYueTtsService.instance
                if (service == null) {
                    // Service not running: can't apply, surface as failure
                    // so Dart knows to retry after init.
                    result.success(false)
                } else {
                    service.handleSetVoice(voiceId, result)
                }
            }
            "openSystemTtsSettings" -> openSystemTtsSettings(ctx, result)
            // v1.13.1-alpha: dump plugin + service debug state for in-app display.
            "getDebugState" -> result.success(buildDebugState())
            else -> result.notImplemented()
        }
    }

    /// v1.13.1-alpha: returns a JSON-serializable map of plugin + service
    /// debug state. Surfaced via `getDebugState` MethodChannel so the user
    /// can paste it back into chat without needing adb.
    private fun buildDebugState(): Map<String, Any?> {
        return mapOf(
            "pluginAttached" to (contextForTest != null),
            "isServiceCreated" to isServiceCreated,
            "initCallCount" to initCallCount,
            "speakCallCount" to speakCallCount,
            "lastStartError" to lastStartError,
            "serviceDebugLogs" to ZhiYueTtsService.debugLogs.toList(),
            "serviceOnCreateDone" to ZhiYueTtsService.onCreateCompleted,
            "serviceOnCreateException" to ZhiYueTtsService.onCreateException,
            "serviceStartForegroundDone" to ZhiYueTtsService.startForegroundCompleted,
            "phoneStateListenerSetupSkipped" to ZhiYueTtsService.phoneStateListenerSetupSkipped,
            "ttsInitStatus" to ZhiYueTtsService.ttsInitStatus,
            "ttsLastSpeakReturn" to ZhiYueTtsService.ttsLastSpeakReturn,
            "onStartCommandCount" to ZhiYueTtsService.onStartCommandCount,
            "lastStartCommandAction" to ZhiYueTtsService.lastStartCommandAction,
            "utteranceCallbacks" to ZhiYueTtsService.utteranceCallbacks.toList(),
            // v1.13.8-alpha Bug 2: deferred SPEAK indicator (init race).
            "pendingSpeakActive" to ZhiYueTtsService.pendingSpeakActive,
            // v1.13.5-alpha: MethodChannel callback pipeline diagnostics.
            "onListenCalled" to onListenCalled,
            "realEventSinkReady" to (channel != null),
            "emitCount" to invokeAttemptCount,
            "emitDroppedCount" to invokeChannelNullCount,
            "invokeSucceededCount" to invokeSucceededCount,
            "invokeExceptionCount" to invokeExceptionCount,
            // v1.13.6-alpha: tracks how often emitEvent had to post from a
            // binder thread to the main thread. Production should see this
            // > 0 (utterances come from binder thread); Robolectric unit
            // tests run on main thread so this stays 0.
            "invokePostedToMainThreadCount" to invokePostedToMainThreadCount
        )
    }

    /// Idempotently start [ZhiYueTtsService]. On API 26+ we use
    /// [Context.startForegroundService] so the service can promote itself
    /// to foreground within the 5-second window; older API levels fall back
    /// to plain [Context.startService].
    ///
    /// On the `noFgs` flavor, the service is omitted from the manifest so
    /// [Context.startForegroundService] throws [IllegalArgumentException]
    /// ("Service not registered"). We catch that here so the `noFgs` flavor
    /// degrades gracefully: TTS calls become silent no-ops (no foreground
    /// promotion, no notification), but the app does not crash and the
    /// MethodChannel call still returns success.
    private fun ensureServiceStarted(ctx: Context): Boolean {
        if (isServiceCreated) return true
        val intent = Intent(ctx, ZhiYueTtsService::class.java)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(intent)
            } else {
                ctx.startService(intent)
            }
            isServiceCreated = true
            true
        } catch (e: Exception) {
            // noFgs flavor omits the service declaration; startForegroundService
            // throws. Log and continue — TTS calls become no-op (no foreground
            // promotion, no notification), but app does not crash.
            lastStartError = "${e.javaClass.simpleName}: ${e.message}"
            android.util.Log.w(
                "ZhiYueTts",
                "ensureServiceStarted failed (likely noFgs flavor)",
                e
            )
            false
        }
    }

    /// Forward a control action (PAUSE / RESUME / STOP) to the service.
    /// Uses [Context.startService] (not startForegroundService) because the
    /// service is already in foreground after [ensureServiceStarted].
    private fun forwardAction(ctx: Context, action: String, result: MethodChannel.Result) {
        ctx.startService(Intent(ctx, ZhiYueTtsService::class.java).setAction(action))
        result.success(null)
    }

    /// v1.14.0-alpha T4: launch the system's Text-to-Speech settings screen
    /// so the user can install / configure engine voices. FLAG_ACTIVITY_NEW_TASK
    /// is required because we're launching from a non-Activity context (the
    /// plugin's applicationContext). Returns true on success, false on any
    /// exception (e.g. no Activity found to handle the Intent on this ROM).
    private fun openSystemTtsSettings(ctx: Context, result: MethodChannel.Result) {
        try {
            val intent = Intent("com.android.settings.TTS_SETTINGS")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            android.util.Log.w("ZhiYueTts", "openSystemTtsSettings failed", e)
            result.success(false)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        contextForTest = null
        instance = null
    }

    /// Called by ZhiYueTtsService (or tests) to emit events to Dart.
    ///
    /// v1.13.5-alpha: rewrote to use MethodChannel reverse callback
    /// (channel.invokeMethod) instead of EventChannel sink.success.
    /// v1.13.4 diagnostic data showed sink.success returned cleanly but
    /// events were silently dropped by the binary messenger on Chinese
    /// ROMs. invokeMethod lets us detect failures via try/catch.
    ///
    /// v1.13.6-alpha: v1.13.5 production diagnostic data revealed that all
    /// invokeMethod calls threw `Methods marked with @UiThread must be
    /// executed on the main thread. Current thread: binder:29456_X`.
    /// Android TTS utterance callbacks (UtteranceProgressListener.onStart /
    /// onDone) fire on binder threads, but MethodChannel.invokeMethod is
    /// annotated @UiThread. We now detect the current thread and post to
    /// the main looper when not already on it. Same root cause as v1.13.5's
    /// silent binary messenger drop — sink.success has the same constraint
    /// but fails silently.
    internal fun emitEvent(event: Map<String, Any?>) {
        val ch = channel
        val type = event["event"]
        // v1.16.3-alpha: companion-scoped last-event snapshot for tests that
        // assert on the most recent emit payload (e.g., engines list in
        // init_error). See lastEmittedEventForTest docs.
        lastEmittedEventForTest = event
        // v1.16.2-alpha: capture for tests (see capturedEventsForTest docs).
        capturedEventsForTest.add(event)
        if (ch == null) {
            invokeChannelNullCount++
            ZhiYueTtsService.debugLog(
                "EMIT_DROPPED type=$type reason=channel_null total_dropped=$invokeChannelNullCount"
            )
            return
        }
        invokeAttemptCount++
        ZhiYueTtsService.debugLog(
            "EMIT_ATTEMPT type=$type total_attempt=$invokeAttemptCount thread=${Thread.currentThread().name}"
        )
        // v1.13.6-alpha: Android TTS callbacks fire on binder threads;
        // MethodChannel.invokeMethod must run on the main thread. Post
        // when not already there.
        if (Looper.myLooper() != Looper.getMainLooper()) {
            invokePostedToMainThreadCount++
            ZhiYueTtsService.debugLog(
                "EMIT_POST_TO_MAIN type=$type total_posted=$invokePostedToMainThreadCount from_thread=${Thread.currentThread().name}"
            )
            Handler(Looper.getMainLooper()).post {
                try {
                    ch.invokeMethod("onTtsEvent", event)
                    invokeSucceededCount++
                    ZhiYueTtsService.debugLog(
                        "EMIT_OK type=$type total_ok=$invokeSucceededCount thread=main(posted)"
                    )
                } catch (e: Exception) {
                    invokeExceptionCount++
                    ZhiYueTtsService.debugLog(
                        "EMIT_THROWN type=$type ex=${e.javaClass.simpleName}: ${e.message} total_thrown=$invokeExceptionCount thread=main(posted)"
                    )
                }
            }
            return
        }
        try {
            ch.invokeMethod("onTtsEvent", event)
            invokeSucceededCount++
            ZhiYueTtsService.debugLog(
                "EMIT_OK type=$type total_ok=$invokeSucceededCount thread=main"
            )
        } catch (e: Exception) {
            invokeExceptionCount++
            ZhiYueTtsService.debugLog(
                "EMIT_THROWN type=$type ex=${e.javaClass.simpleName}: ${e.message} total_thrown=$invokeExceptionCount thread=main"
            )
        }
    }

    /// Test-only: simulate a service event bypassing the real service.
    internal fun simulateServiceEventForTest(event: Map<String, Any?>) {
        emitEvent(event)
    }

    companion object {
        /// Singleton reference set in [onAttachedToEngine] and cleared in
        /// [onDetachedFromEngine]. Read by [ZhiYueTtsService.emit] at every
        /// call (v1.13.7-alpha Bug 5) so plugin rebinding doesn't strand
        /// the service on a stale plugin reference.
        internal var instance: ZhiYueTtsPlugin? = null
            private set

        /// Test-only: swap the companion instance so a Robolectric test can
        /// simulate plugin rebinding (Activity recreate / Flutter engine
        /// restart) without spinning up a full Flutter engine. Production
        /// code MUST NOT call this.
        internal fun setInstanceForTest(plugin: ZhiYueTtsPlugin?) {
            instance = plugin
        }

        /// v1.16.3-alpha: test-only snapshot of the most recent event passed
        /// to [emitEvent]. Lets tests assert on the emitted payload (e.g.,
        /// the `engines` list in init_error) without depending on a specific
        /// plugin instance being attached. Tests should call
        /// [resetLastEmittedEventForTest] at the start to avoid leakage.
        ///
        /// Companion-scoped (not instance-scoped like [capturedEventsForTest])
        /// because some tests construct a fresh plugin per scenario and we want
        /// the latest emit visible regardless of which instance handled it.
        /// Production code reads nothing from this field; assignment is a cheap
        /// Map reference inside [emitEvent] (no perf concern — service emits
        /// <100 events per session).
        @Volatile
        internal var lastEmittedEventForTest: Map<String, Any?>? = null
            private set

        /// Test-only: clears [lastEmittedEventForTest] so each test starts
        /// from a clean baseline. Production code MUST NOT call this.
        internal fun resetLastEmittedEventForTest() {
            lastEmittedEventForTest = null
        }
    }
}
