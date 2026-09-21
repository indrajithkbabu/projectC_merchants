package com.example.project_c

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Default: block screenshots / screen recording until Flutter
        // ScreenshotProtectionService clears FLAG_SECURE when allowed.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
