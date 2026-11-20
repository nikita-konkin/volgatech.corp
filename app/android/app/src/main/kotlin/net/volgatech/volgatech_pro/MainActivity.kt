package net.volgatech.volgatech_pro

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
        // Contacts, calendar events and translation for the mail reader.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "volgatech/text")
            .setMethodCallHandler { call, result -> TextIntents.handle(this, call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "volgatech/mail_background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> {
                        val hasAppLaunch = Build.MANUFACTURER.equals("Honor", ignoreCase = true) ||
                            Build.MANUFACTURER.equals("Huawei", ignoreCase = true)
                        result.success(mapOf(
                            "hasAppLaunch" to hasAppLaunch,
                            "canRequestBatteryExemption" to (hasAppLaunch && !ignoresBatteryOptimization()),
                        ))
                    }
                    "openAppLaunch" -> result.success(openSettings(
                        Intent().setClassName(
                            "com.hihonor.systemmanager",
                            "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                        ),
                        Intent().setClassName(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                        ),
                        appSettingsIntent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS),
                    ))
                    "requestBatteryExemption" -> result.success(
                        ignoresBatteryOptimization() || openSettings(
                            appSettingsIntent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS),
                        ),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun ignoresBatteryOptimization(): Boolean =
        getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)

    private fun appSettingsIntent(action: String) =
        Intent(action, Uri.fromParts("package", packageName, null))

    private fun openSettings(vararg intents: Intent): Boolean = intents.any { intent ->
        try {
            startActivity(intent)
            true
        } catch (_: RuntimeException) {
            false
        }
    }
}
