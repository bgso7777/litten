package com.example.frontend

import android.os.Bundle
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // WebView 디버깅 활성화 (release에서도 필요할 수 있음)
        WebView.setWebContentsDebuggingEnabled(true)
    }
}
