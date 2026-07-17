package com.sidore.catholiccalendar

import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sidore.catholiccalendar/settings"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sidore.catholiccalendar/widget_snapshot"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    val payload = call.arguments as? String
                    if (payload == null) {
                        result.error("invalid_payload", "Expected JSON string", null)
                    } else {
                        syncWidgetSnapshot(payload)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            )
        }
    }

    private fun syncWidgetSnapshot(payload: String) {
        getSharedPreferences("widget_snapshot", MODE_PRIVATE)
            .edit()
            .putString("widget_snapshot", payload)
            .apply()

        val manager = AppWidgetManager.getInstance(this)
        val component = ComponentName(this, TodayWidgetProvider::class.java)
        val ids = manager.getAppWidgetIds(component)
        if (ids.isNotEmpty()) {
            TodayWidgetProvider.updateWidgets(this, manager, ids)
        }
    }
}
