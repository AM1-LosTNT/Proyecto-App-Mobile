package com.example.turisapp

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "turisapp/yape_listener"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(tieneAccesoNotificaciones())

                    "openSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }

                    "openAppDetails" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("APP_DETAILS_ERROR", e.message, null)
                        }
                    }

                    "rebindListener" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                val component = ComponentName(this, YapeNotificationListenerService::class.java)
                                YapeNotificationListenerService.requestRebind(component)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "getRecentNotifications" -> {
                        result.success(YapePrefs(this).obtenerNotificacionesRecientesJson())
                    }

                    "configure" -> {
                        try {
                            YapePrefs(this).save(
                                url = call.argument<String>("url") ?: "",
                                anonKey = call.argument<String>("anonKey") ?: "",
                                accessToken = call.argument<String>("accessToken") ?: "",
                                refreshToken = call.argument<String>("refreshToken") ?: "",
                                userId = call.argument<String>("userId") ?: "",
                                isAdmin = call.argument<Boolean>("isAdmin") ?: false,
                                enabled = call.argument<Boolean>("enabled") ?: true,
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CONFIG_ERROR", e.message, null)
                        }
                    }

                    "setEnabled" -> {
                        YapePrefs(this).enabled =
                            call.argument<Boolean>("enabled") ?: true
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** Comprueba si TurisApp aparece en Ajustes → Acceso a notificaciones. */
    private fun tieneAccesoNotificaciones(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false

        return enabled.split(":").any { entry ->
            ComponentName.unflattenFromString(entry)?.packageName == packageName
        }
    }
}
