package com.example.project_c

import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import com.google.android.gms.tasks.Tasks
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "FCM_DEBUG_NATIVE"
        private const val CHANNEL = "project_c/fcm_debug"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Default: block screenshots / screen recording until Flutter
        // ScreenshotProtectionService clears FLAG_SECURE when allowed.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTokenWithCause" -> {
                    Thread {
                        try {
                            val token =
                                Tasks.await(
                                    FirebaseMessaging.getInstance().token,
                                    60,
                                    TimeUnit.SECONDS,
                                )
                            Log.i(TAG, "getToken OK len=${token?.length ?: 0}")
                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "ok" to true,
                                        "token" to (token ?: ""),
                                        "chain" to "",
                                    ),
                                )
                            }
                        } catch (e: Exception) {
                            val chain = exceptionChain(e)
                            Log.e(TAG, "getToken FAIL $chain", e)
                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "ok" to false,
                                        "token" to "",
                                        "chain" to chain,
                                    ),
                                )
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun exceptionChain(e: Throwable): String {
        val parts = ArrayList<String>()
        var cur: Throwable? = e
        var depth = 0
        while (cur != null && depth < 8) {
            parts.add("${cur.javaClass.simpleName}: ${cur.message}")
            cur = cur.cause
            depth++
        }
        return parts.joinToString(" <- ")
    }
}
