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
                ensureServiceStarted(ctx)
                result.success(null)
            }
            "speak" -> {
                ensureServiceStarted(ctx)
                @Suppress("UNCHECKED_CAST")
                val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                val intent = Intent(ctx, ZhiYueTtsService::class.java)
                    .setAction(ZhiYueTtsService.ACTION_SPEAK)
                    .putExtra(ZhiYueTtsService.EXTRA_TEXT, args["text"] as? String ?: "")
                    .putExtra(ZhiYueTtsService.EXTRA_LOCALE, args["locale"] as? String ?: "zh-CN")
                    .putExtra(
                        ZhiYueTtsService.EXTRA_SENTENCE_INDEX,
                        (args["sentenceIndex"] as? Number)?.toInt() ?: 0
                    )
                ctx.startService(intent)
                result.success(null)
            }
            "pause" -> forwardAction(ctx, ZhiYueTtsService.ACTION_PAUSE, result)
            "resume" -> forwardAction(ctx, ZhiYueTtsService.ACTION_RESUME, result)
            "stop" -> forwardAction(ctx, ZhiYueTtsService.ACTION_STOP, result)
            // T12+ will wire these to the service. Until then, ack so the
            // Dart side doesn't see `notImplemented` for control plumbing.
            "setRate", "setPitch", "setVolume", "setLanguage" -> result.success(null)
            "isLanguageAvailable", "isLanguageInstalled" -> result.success(true)
            "getDefaultEngine" -> result.success("com.google.android.tts")
            else -> result.notImplemented()
        }
    }

    /// Idempotently start [ZhiYueTtsService]. On API 26+ we use
    /// [Context.startForegroundService] so the service can promote itself
    /// to foreground within the 5-second window; older API levels fall back
    /// to plain [Context.startService].
    private fun ensureServiceStarted(ctx: Context) {
        if (isServiceCreated) return
        val intent = Intent(ctx, ZhiYueTtsService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.startForegroundService(intent)
        } else {
            ctx.startService(intent)
        }
        isServiceCreated = true
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
    }

    override fun onListen(args: Any?, sink: io.flutter.plugin.common.EventChannel.EventSink?) {
        realEventSink = sink
    }

    override fun onCancel(args: Any?) {
        realEventSink = null
    }

    /// Called by ZhiYueTtsService (or tests) to emit events to Dart.
    internal fun emitEvent(event: Map<String, Any?>) {
        realEventSink?.success(event)
    }

    /// Test-only: simulate a service event bypassing the real service.
    internal fun simulateServiceEventForTest(event: Map<String, Any?>) {
        emitEvent(event)
    }
}
