package com.example.turisapp

import android.content.Context

/**
 * Preferencias compartidas entre Flutter y el NotificationListenerService.
 * Aquí se guarda la sesión de Supabase y si el usuario es administrador.
 */
class YapePrefs(context: Context) {
    private val prefs =
        context.applicationContext.getSharedPreferences("turisapp_yape", Context.MODE_PRIVATE)

    var url: String
        get() = prefs.getString("url", "") ?: ""
        set(value) = prefs.edit().putString("url", value).apply()

    var anonKey: String
        get() = prefs.getString("anon_key", "") ?: ""
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
        get() = prefs.getBoolean("enabled", false)
        set(value) = prefs.edit().putBoolean("enabled", value).apply()

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
            .putString("url", url)
            .putString("anon_key", anonKey)
            .putString("access_token", accessToken)
            .putString("refresh_token", refreshToken)
            .putString("user_id", userId)
            .putBoolean("is_admin", isAdmin)
            .putBoolean("enabled", enabled)
            .apply()
    }
}
