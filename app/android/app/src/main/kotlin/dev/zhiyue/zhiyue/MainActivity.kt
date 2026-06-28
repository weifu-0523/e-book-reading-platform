package dev.zhiyue.zhiyue

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
        super.configureFlutterEngine(flutterEngine)
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
