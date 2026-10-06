package net.volgatech.volgatech_pro

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so the
// biometric prompt can attach to a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The home-screen widget's lessons (lib/core/lesson_widget.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "volgatech/lesson_widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        LessonWidget.save(applicationContext, call.arguments as String)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
