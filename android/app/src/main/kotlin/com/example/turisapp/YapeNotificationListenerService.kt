package com.example.turisapp

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale

/**
 * Lee las notificaciones de Yape / banca y COMPLETA el cobro pendiente en Supabase.
 *
 * Puntos clave:
 * - Solo actúa si el usuario de este teléfono es admin y el listener está habilitado.
 * - Antes de procesar consulta `configuracion_cobros.escucha_activa`: si no hay
 *   ningún cobro PENDIENTE vigente, no hace nada (ahorro de batería y evita
 *   falsos positivos por pagos recibidos fuera de la app).
 * - Una sola llamada a la RPC `validar_pago_por_notificacion`: si el monto
 *   coincide con un cobro pendiente, el cobro pasa directo a PAGADO. No hay
 *   confirmación manual ni registro de saldos.
 * - El anti-duplicados usa `evento_hash` (SHA-256) y es idempotente en el
 *   servidor: una misma notificación no paga dos cobros.
 */
class YapeNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "YapeListener"
        private const val PREFS_RECENT = "recent_events"
    }

    private val recientes = mutableSetOf<String>()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            if (sbn == null) return

            val prefs = YapePrefs(this)
            if (!prefs.enabled || !prefs.isAdmin) return
            if (prefs.url.isEmpty() || prefs.anonKey.isEmpty() || prefs.accessToken.isEmpty()) return

            val notification: Notification = sbn.notification ?: return
            val extras = notification.extras ?: return

            val titulo = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val texto = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
            val textoGrande =
                extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()

            val cuerpo = listOf(texto, textoGrande)
                .filter { it.isNotBlank() }
                .distinct()
                .joinToString(" ")

            val paquete = sbn.packageName.orEmpty()
            val contenido = "$titulo $cuerpo"

            if (!parecePago(paquete, contenido)) return

            val monto = extraerMonto(contenido) ?: return
            val hash = sha256("$paquete|$titulo|$cuerpo|$monto")
            if (recientes.contains(hash)) return

            // Mantiene la caché pequeña.
            if (recientes.size > 50) recientes.clear()
            recientes.add(hash)

            Thread {
                try {
                    procesar(prefs, paquete, titulo, cuerpo, monto, hash)
                } catch (e: Exception) {
                    Log.e(TAG, "Error procesando notificación", e)
                }
            }.start()
        } catch (e: Exception) {
            Log.e(TAG, "Error leyendo notificación", e)
        }
    }

    private fun procesar(
        prefs: YapePrefs,
        paquete: String,
        titulo: String,
        cuerpo: String,
        monto: Double,
        hash: String,
    ) {
        val base = prefs.url.trimEnd('/')
        val token = prefs.accessToken

        // 1) ¿Hay escucha activa? (solo cuando existe un cobro pendiente)
        val config = request(
            "GET",
            "$base/rest/v1/configuracion_cobros?id=eq.1&select=escucha_activa",
            prefs.anonKey,
            token,
            null
        )
        if (config.code == 401) {
            Log.w(TAG, "Sesión expirada: abre TurisApp para renovarla.")
            return
        }
        if (config.code !in 200..299) return

        val configArr = runCatching { JSONArray(config.body) }.getOrNull() ?: return
        if (configArr.length() == 0) return
        if (!configArr.getJSONObject(0).optBoolean("escucha_activa", false)) {
            Log.i(TAG, "Escucha inactiva: se ignora la notificación.")
            return
        }

        // 2) RPC atómica: busca el cobro PENDIENTE del monto exacto y lo marca
        //    PAGADO. El servidor valida el rol admin, la vigencia y el
        //    anti-duplicados por hash.
        val payload = JSONObject().apply {
            put("p_monto", monto)
            put("p_titulo", if (titulo.isNotBlank()) titulo.take(200) else paquete.take(200))
            put("p_texto", cuerpo.take(500))
            put("p_hash", hash)
        }

        val rpc = request(
            "POST",
            "$base/rest/v1/rpc/validar_pago_por_notificacion",
            prefs.anonKey,
            token,
            payload.toString()
        )

        if (rpc.code == 401) {
            Log.w(TAG, "Sesión expirada: abre TurisApp para renovarla.")
            return
        }

        if (rpc.code !in 200..299) {
            Log.w(TAG, "No se pudo validar el cobro: ${rpc.code} ${rpc.body.take(200)}")
            return
        }

        val body = rpc.body.trim()
        if (body.isEmpty() || body == "null") {
            Log.i(TAG, "No hay cobro pendiente que coincida con Bs $monto")
            return
        }

        val fila = runCatching { JSONObject(body) }.getOrNull()
        val pagoId = fila?.optString("id").orEmpty()
        val estado = fila?.optString("estado").orEmpty()

        if (estado == "PAGADO") {
            Log.i(TAG, "Cobro $pagoId PAGADO automáticamente por notificación de Bs $monto")
        } else {
            Log.w(TAG, "Respuesta inesperada del servidor para Bs $monto: ${body.take(200)}")
        }
    }

    private fun parecePago(paquete: String, texto: String): Boolean {
        val p = paquete.lowercase(Locale.US)
        if (p.contains("yape") || p.contains("bcp")) return true

        val t = texto.lowercase(Locale.US)
        val claves = listOf(
            "yape",
            "yapearon",
            "yapeo",
            "transferencia recibida",
            "recibiste",
            "pago recibido",
            "abono",
            "te envió",
            "te envio",
        )
        return claves.any { t.contains(it) }
    }

    private fun extraerMonto(texto: String): Double? {
        val conMoneda = Regex(
            "(?:bs\\.?|bob|s/)\\s*([0-9]+(?:[.,][0-9]{1,2})?)",
            RegexOption.IGNORE_CASE
        )
        val respaldo = Regex("([0-9]+[.,][0-9]{2})")

        val raw = conMoneda.find(texto)?.groupValues?.get(1)
            ?: respaldo.find(texto)?.groupValues?.get(1)
            ?: return null

        val valor = raw.replace(',', '.').toDoubleOrNull() ?: return null
        return if (valor > 0) valor else null
    }

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(value.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private data class HttpResult(val code: Int, val body: String)

    private fun request(
        method: String,
        endpoint: String,
        apikey: String,
        bearer: String?,
        jsonBody: String?,
    ): HttpResult {
        var conn: HttpURLConnection? = null
        return try {
            conn = URL(endpoint).openConnection() as HttpURLConnection
            conn.requestMethod = method
            conn.connectTimeout = 8000
            conn.readTimeout = 8000
            conn.setRequestProperty("apikey", apikey)
            conn.setRequestProperty("Accept", "application/json")
            if (!bearer.isNullOrEmpty()) {
                conn.setRequestProperty("Authorization", "Bearer $bearer")
            }
            if (jsonBody != null) {
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write(jsonBody.toByteArray(Charsets.UTF_8)) }
            }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            HttpResult(code, body)
        } finally {
            conn?.disconnect()
        }
    }
}
