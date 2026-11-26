package com.example.turisapp

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Preferencias compartidas entre Flutter y el NotificationListenerService.
 * Guarda la sesión de Supabase, rol admin y el historial de notificaciones capturadas.
 */
class YapePrefs(context: Context) {
    companion object {
        const val DEFAULT_URL = "https://ewpggamtdzziplibpabv.supabase.co"
        const val DEFAULT_ANON_KEY = "sb_publishable_cV-Zs3q_NSlm5b_IehTAJQ_p8t9iUnz"
        private const val MAX_RECENT = 20
    }

    private val prefs =
        context.applicationContext.getSharedPreferences("turisapp_yape", Context.MODE_PRIVATE)

    var url: String
        get() {
            val v = prefs.getString("url", "") ?: ""
            return if (v.isNotBlank()) v else DEFAULT_URL
        }
        set(value) = prefs.edit().putString("url", value).apply()

    var anonKey: String
        get() {
            val v = prefs.getString("anon_key", "") ?: ""
            return if (v.isNotBlank()) v else DEFAULT_ANON_KEY
        }
        set(value) = prefs.edit().putString("anon_key", value).apply()

    var accessToken: String
        get() = prefs.getString("access_token", "") ?: ""
        set(value) = prefs.edit().putString("access_token", value).apply()

    var refreshToken: String
        get() = prefs.getString("refresh_token", "") ?: ""
        set(value) = prefs.edit().putString("refresh_token", value).apply()

    var userId: String
        get() = prefs.getString("user_id", "") ?: ""
        set(value) = prefs.edit().putString("user_id", value).apply()

    var isAdmin: Boolean
        get() = prefs.getBoolean("is_admin", false)
        set(value) = prefs.edit().putBoolean("is_admin", value).apply()

    var enabled: Boolean
        get() = prefs.getBoolean("enabled", true)
        set(value) = prefs.edit().putBoolean("enabled", value).apply()

    var lastNotificationText: String
        get() = prefs.getString("last_notification_text", "") ?: ""
        set(value) = prefs.edit().putString("last_notification_text", value).apply()

    var lastNotificationTime: Long
        get() = prefs.getLong("last_notification_time", 0L)
        set(value) = prefs.edit().putLong("last_notification_time", value).apply()

    var lastNotificationStatus: String
        get() = prefs.getString("last_notification_status", "") ?: ""
        set(value) = prefs.edit().putString("last_notification_status", value).apply()

    /**
     * Guarda la notificación en la lista de eventos recientes (JSON) para diagnóstico en la app.
     */
    fun registrarNotificacionLocal(
        paquete: String,
        titulo: String,
        texto: String,
        monto: Double?,
        estado: String,
        detalle: String = ""
    ) {
        try {
            val now = System.currentTimeMillis()
            lastNotificationText = "$titulo: $texto"
            lastNotificationTime = now
            lastNotificationStatus = estado

            val rawList = prefs.getString("recent_notifications_json", "[]") ?: "[]"
            val array = runCatching { JSONArray(rawList) }.getOrDefault(JSONArray())

            val item = JSONObject().apply {
                put("timestamp", now)
                put("paquete", paquete)
                put("titulo", titulo)
                put("texto", texto)
                put("monto", monto ?: 0.0)
                put("estado", estado)
                put("detalle", detalle)
            }

            // Insertar al inicio
            val nuevo = JSONArray()
            nuevo.put(item)
            val limit = minOf(array.length(), MAX_RECENT - 1)
            for (i in 0 until limit) {
                nuevo.put(array.getJSONObject(i))
            }

            prefs.edit().putString("recent_notifications_json", nuevo.toString()).apply()
        } catch (_: Exception) {}
    }

    fun obtenerNotificacionesRecientesJson(): String {
        return prefs.getString("recent_notifications_json", "[]") ?: "[]"
    }

    fun save(
        url: String,
        anonKey: String,
        accessToken: String,
        refreshToken: String,
        userId: String,
        isAdmin: Boolean,
        enabled: Boolean,
    ) {
        prefs.edit()
            .putString("url", if (url.isNotBlank()) url else DEFAULT_URL)
            .putString("anon_key", if (anonKey.isNotBlank()) anonKey else DEFAULT_ANON_KEY)
            .putString("access_token", accessToken)
            .putString("refresh_token", refreshToken)
            .putString("user_id", userId)
            .putBoolean("is_admin", isAdmin)
            .putBoolean("enabled", enabled)
            .apply()
    }
}
