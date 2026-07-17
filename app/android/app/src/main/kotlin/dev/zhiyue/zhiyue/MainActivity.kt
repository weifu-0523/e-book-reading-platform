package dev.zhiyue.zhiyue

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.Log
import java.io.File

/// v1.12.3-alpha-exp3 P0 diagnostic: custom plugin registration that
/// SKIPS audio_service / audio_session / flutter_tts to test the
/// hypothesis that one of these 3 plugins' attach-time work triggers
/// the Chinese-ROM (Honor / Xiaomi / Huawei-pre-Harmony) startup kill.
///
/// Trade-off accepted for this diagnostic build only:
///   - Android: TTS becomes no-op (UI buttons appear but do nothing)
///   - Desktop: unaffected (uses different code path)
///   - Plan after root cause confirmed: v1.13 builds a custom lightweight
///     Android TTS plugin via MethodChannel with full control over init
///     timing, restoring TTS without triggering the ROM kill.
///
/// DO NOT CALL super.configureFlutterEngine — that triggers
/// GeneratedPluginRegistrant.registerWith which auto-adds ALL plugins
/// including the 3 we want to skip. Once they're added, their
/// onAttachedToEngine runs immediately and binds to system services
/// (TextToSpeech, AudioDeviceCallback) — damage done before we can
/// remove them.
class MainActivity : FlutterActivity() {
    private val CHANNEL = "dev.zhiyue.bookopen"
    private var pendingBookPath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Cold start：从 launch intent 取出文件 URI，转成本地路径暂存
        pendingBookPath = intent?.data?.let { uriToPath(it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // v1.12.3-alpha-exp3 P0: explicitly do NOT call super — super
        // triggers GeneratedPluginRegistrant which auto-registers all
        // plugins including the 3 we suspect cause the Chinese-ROM
        // startup kill. Manually register only the safe plugins below.
        registerSafePlugins(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "popPendingBookPath" -> {
                    result.success(pendingBookPath)
                    pendingBookPath = null
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Hand-curated plugin registration list. Mirrors
    /// GeneratedPluginRegistrant.registerWith but SKIPS:
    ///   - com.ryanheise.audioservice.AudioServicePlugin     (audio_service)
    ///   - com.ryanheise.audio_session.AudioSessionPlugin    (audio_session)
    ///   - com.eyedeadevelopment.fluttertts.FlutterTtsPlugin (flutter_tts)
    ///
    /// If Flutter upgrades and GeneratedPluginRegistrant changes, this
    /// list MUST be updated to mirror the new set (minus the 3 skips).
    /// Mismatch will manifest as runtime "channel not registered"
    /// errors on the missing plugin, not as a crash.
    private fun registerSafePlugins(flutterEngine: FlutterEngine) {
        val tag = "ZhiYuePluginFilter"
        val safePlugins: List<Pair<String, () -> Any>> = listOf(
            "connectivity_plus" to { dev.fluttercommunity.plus.connectivity.ConnectivityPlugin() },
            "file_picker" to { com.mr.flutter.plugin.filepicker.FilePickerPlugin() },
            "flutter_plugin_android_lifecycle" to { io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin() },
            "flutter_secure_storage" to { com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin() },
            "jni" to { com.github.dart_lang.jni.JniPlugin() },
            "jni_flutter" to { com.github.dart_lang.jni_flutter.JniFlutterPlugin() },
            "just_audio" to { com.ryanheise.just_audio.JustAudioPlugin() },
            "package_info_plus" to { dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin() },
            "sqflite_android" to { com.tekartik.sqflite.SqflitePlugin() },
            "sqlite3_flutter_libs" to { eu.simonbinder.sqlite3_flutter_libs.Sqlite3FlutterLibsPlugin() },
            "url_launcher_android" to { io.flutter.plugins.urllauncher.UrlLauncherPlugin() },
            "video_player_android" to { io.flutter.plugins.videoplayer.VideoPlayerPlugin() },
            "wakelock_plus" to { dev.fluttercommunity.plus.wakelock.WakelockPlusPlugin() },
            "webview_flutter_android" to { io.flutter.plugins.webviewflutter.WebViewFlutterPlugin() },
        )
        // integration_test plugin is test-only; not registered here.
        for ((name, factory) in safePlugins) {
            try {
                @Suppress("UNCHECKED_CAST")
                val plugin = factory() as io.flutter.embedding.engine.plugins.FlutterPlugin
                flutterEngine.getPlugins().add(plugin)
            } catch (e: Exception) {
                Log.e(tag, "Error registering plugin $name", e)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Warm start：app 已运行时收到新文件 URI
        intent.data?.let { uri ->
            uriToPath(uri)?.let { path ->
                methodChannel?.invokeMethod("openBook", path)
            }
        }
    }

    /// 把 file:// / content:// URI 解析为本地文件绝对路径。
    /// file:// → 直接取 path
    /// content:// → 拷贝到 cacheDir 返回副本路径（避免权限 / 持久化问题）
    private fun uriToPath(uri: Uri): String? {
        return when (uri.scheme?.lowercase()) {
            "file" -> uri.path
            "content" -> copyContentToCache(uri)
            else -> null
        }
    }

    private fun copyContentToCache(uri: Uri): String? {
        return try {
            val input = contentResolver.openInputStream(uri) ?: return null
            val tempFile = File(cacheDir, "import_${System.currentTimeMillis()}.book")
            tempFile.outputStream().use { output ->
                input.use { it.copyTo(output) }
            }
            tempFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
