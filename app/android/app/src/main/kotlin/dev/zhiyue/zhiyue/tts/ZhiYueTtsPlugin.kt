package dev.zhiyue.zhiyue.tts

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
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
class ZhiYueTtsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var channel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    internal var eventSinkForTest: EventChannel.EventSink? = null
        set(value) { field = value; realEventSink = value }
    private var realEventSink: EventChannel.EventSink? = null

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

    /// v1.13.4-alpha diagnostic: emit pipeline instrumentation.
    ///
    /// Background: v1.13.2 + v1.13.3 both attempted fixes for "multi-sentence
    /// playback halts after queue[0]". User reported both ineffective. The
    /// Kotlin `UtteranceProgressListener.onStart/onDone` callbacks fire
    /// correctly (visible in utteranceCallbacks), but Dart-side queue still
    /// doesn't advance — strongly suggesting events are silently dropped
    /// between Kotlin `emit()` and Dart `_handleEvent`.
    ///
    /// The original `emitEvent` was `realEventSink?.success(event)` — a
    /// **silent no-op** when realEventSink is null. v1.13.4 adds counters +
    /// explicit logs at every hop so the next debug-state dump pinpoints
    /// exactly where the chain breaks:
    ///   * [onListenCalled] — did Dart ever subscribe to the EventChannel?
    ///   * [emitCount] — how many events did Kotlin successfully hand off?
    ///   * [emitDroppedCount] — how many events were silently dropped?
    /// Comparison with Dart-side `_eventReceivedCount` reveals whether the
    /// loss is on the Kotlin side (sink null) or the binary-messenger round-trip.
    internal var emitCount: Int = 0
        private set
    internal var emitDroppedCount: Int = 0
        private set
    internal var onListenCalled: Boolean = false
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
        eventChannel = EventChannel(binding.binaryMessenger, "dev.zhiyue.tts/events").also {
            it.setStreamHandler(this)
        }
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
            // v1.13.4-alpha: EventChannel pipeline diagnostics.
            "onListenCalled" to onListenCalled,
            "realEventSinkReady" to (realEventSink != null),
            "emitCount" to emitCount,
            "emitDroppedCount" to emitDroppedCount
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

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        realEventSink = null
        contextForTest = null
        instance = null
    }

    override fun onListen(args: Any?, sink: io.flutter.plugin.common.EventChannel.EventSink?) {
        realEventSink = sink
        onListenCalled = true
        ZhiYueTtsService.debugLog("EVENT_SINK_ON_LISTEN fired — realEventSink assigned")
    }

    override fun onCancel(args: Any?) {
        realEventSink = null
        ZhiYueTtsService.debugLog("EVENT_SINK_ON_CANCEL fired — realEventSink cleared")
    }

    /// Called by ZhiYueTtsService (or tests) to emit events to Dart.
    ///
    /// v1.13.4-alpha: was previously `realEventSink?.success(event)` — a
    /// **silent no-op** when sink is null. Now records counters + per-event
    /// debugLog so the user can compare Kotlin emitCount vs Dart
    /// eventReceivedCount and pinpoint where events vanish.
    internal fun emitEvent(event: Map<String, Any?>) {
        val sink = realEventSink
        val type = event["event"]
        if (sink == null) {
            emitDroppedCount++
            ZhiYueTtsService.debugLog(
                "EMIT_DROPPED type=$type total_dropped=$emitDroppedCount"
            )
        } else {
            emitCount++
            ZhiYueTtsService.debugLog(
                "EMIT_OK type=$type total_emit=$emitCount"
            )
            sink.success(event)
        }
    }

    /// Test-only: simulate a service event bypassing the real service.
    internal fun simulateServiceEventForTest(event: Map<String, Any?>) {
        emitEvent(event)
    }

    companion object {
        /// Singleton reference set in [onAttachedToEngine] and cleared in
        /// [onDetachedFromEngine]. Used by [ZhiYueTtsService.onCreate] to
        /// wire `eventEmitter` so service state/progress events flow back
        /// to Dart via the EventChannel.
        internal var instance: ZhiYueTtsPlugin? = null
            private set
    }
}
