package dev.zhiyue.zhiyue.tts

import android.content.Context
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
class ZhiYueTtsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    /// Test-only: whether [ZhiYueTtsService] has been created via init call.
    /// Production code shouldn't read this; tests verify the lazy invariant.
    internal var isServiceCreated: Boolean = false
        private set

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // CRITICAL: do NOT construct TextToSpeech / MediaSession /
        // AudioFocus / startForeground here. Just bind the channel.
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.zhiyue.tts").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                ensureServiceCreated()
                result.success(null)
            }
            "speak" -> {
                ensureServiceCreated()
                // T11 will forward to ZhiYueTtsService via Intent.
                // T5 stub: just acknowledge.
                result.success(null)
            }
            "pause", "resume", "stop",
            "setRate", "setPitch", "setVolume",
            "setLanguage", "isLanguageAvailable", "isLanguageInstalled", "getDefaultEngine" -> {
                // T11/T13 will route these to service.
                // T5 stub: return success with default values for queries.
                result.success(when (call.method) {
                    "isLanguageAvailable", "isLanguageInstalled" -> true
                    "getDefaultEngine" -> "com.google.android.tts"
                    else -> null
                })
            }
            else -> result.notImplemented()
        }
    }

    /// T5 stub: flips [isServiceCreated] for test observability. T11 will
    /// actually `startForegroundService(Intent(context, ZhiYueTtsService))`
    /// here so the service owns TextToSpeech / MediaSession / AudioFocus.
    private fun ensureServiceCreated() {
        if (!isServiceCreated) {
            isServiceCreated = true
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }
}
