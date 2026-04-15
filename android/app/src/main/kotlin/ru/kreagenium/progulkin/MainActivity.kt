package ru.kreagenium.progulkin

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "ru.kreagenium.progulkin/incoming_file"
    private var initialFilePath: String? = null
    private var methodChannel: MethodChannel? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Обрабатываем intent, если приложение запущено из файла
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_VIEW -> {
                // Файл открыт через "Открыть с помощью"
                val uri: Uri? = intent.data
                uri?.let { handleUri(it) }
            }
            Intent.ACTION_SEND -> {
                // Файл передан через "Поделиться"
                val uri: Uri? = intent.getParcelableExtra(Intent.EXTRA_STREAM)
                uri?.let { handleUri(it) }
            }
        }
    }
    
    private fun handleUri(uri: Uri) {
        val filePath = when (uri.scheme) {
            "file" -> uri.path
            "content" -> {
                // Для content:// URI копируем файл во временный кэш
                copyContentToCache(uri)
            }
            else -> uri.toString()
        }
        
        filePath?.let { path ->
            android.util.Log.d("MainActivity", "📥 Получен файл: $path")
            initialFilePath = path
            
            // Если канал уже создан, отправляем событие
            methodChannel?.invokeMethod("onFileReceived", path)
        }
    }
    
    private fun copyContentToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri)
            val fileName = "import_${System.currentTimeMillis()}.progulkin"
            val cacheFile = File(cacheDir, fileName)
            
            inputStream?.use { input ->
                cacheFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            
            cacheFile.absolutePath
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ Ошибка копирования: ${e.message}")
            null
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> {
                    result.success(initialFilePath)
                    initialFilePath = null // Сбрасываем после первого запроса
                }
                "copyContentToFile" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString != null) {
                        val path = copyContentToCache(Uri.parse(uriString))
                        result.success(path)
                    } else {
                        result.error("INVALID_ARGS", "URI is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
