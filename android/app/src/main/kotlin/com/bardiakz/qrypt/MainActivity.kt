package com.bardiakz.qrypt

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SCREEN_SECURITY_CHANNEL = "io.github.bardiakz.qrypt/screen_security"
        private const val CLIPBOARD_SECURITY_CHANNEL = "io.github.bardiakz.qrypt/clipboard_security"
        private const val EXTRA_IS_SENSITIVE_COMPAT = "android.content.extra.IS_SENSITIVE"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setFlagSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                if (clipboard == null) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "setSensitiveText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val label = call.argument<String>("label") ?: "Qrypt Secret"
                        val clip = ClipData.newPlainText(label, text)
                        val extras = PersistableBundle().apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                            } else {
                                putBoolean(EXTRA_IS_SENSITIVE_COMPAT, true)
                            }
                        }
                        clip.description.extras = extras
                        clipboard.setPrimaryClip(clip)
                        result.success(true)
                    }
                    "clearClipboard" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            clipboard.clearPrimaryClip()
                        } else {
                            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
