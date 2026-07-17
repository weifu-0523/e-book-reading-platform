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
        // Implemented in T5.
        result.notImplemented()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }
}
