package com.example.turisapp

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale

/**
 * Servicio nativo que lee notificaciones de Yape y bancos en Bolivia y valida
 * automáticamente el cobro en Supabase.
 */
class YapeNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "YapeListener"
    }

    private val recientes = mutableSetOf<String>()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            if (sbn == null) return

            val prefs = YapePrefs(this)
            // Si la app está instalada y el usuario concedió permiso en Android, procesamos.
            if (!prefs.enabled) {
                Log.d(TAG, "Listener deshabilitado en preferencias.")
                return
            }

            val notification: Notification = sbn.notification ?: return
            val extras = notification.extras ?: return

            val titulo = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty().trim()
            val texto = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty().trim()
            val textoGrande =
                extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty().trim()

            val cuerpo = listOf(texto, textoGrande)
                .filter { it.isNotBlank() }
                .distinct()
                .joinToString(" ")

            val paquete = sbn.packageName.orEmpty()
            val contenido = "$titulo $cuerpo".trim()

            if (contenido.isEmpty()) return

            // Filtro rápido: ¿proviene de una app bancaria o tiene palabras clave de pago?
            if (!parecePago(paquete, contenido)) return

            val monto = extraerMonto(contenido)
            if (monto == null || monto <= 0) {
                // Registrar para diagnóstico que se detectó una notificación bancaria pero sin monto claro
                prefs.registrarNotificacionLocal(
                    paquete = paquete,
                    titulo = titulo,
                    texto = cuerpo,
                    monto = null,
                    estado = "MONTO_NO_DETECTADO",
                    detalle = "No se pudo extraer el monto numérico del texto."
                )
                return
            }

            val hash = sha256("$paquete|$titulo|$cuerpo|$monto")
            if (recientes.contains(hash)) {
                Log.d(TAG, "Notificación duplicada ignorada (hash en caché).")
                return
            }

            if (recientes.size > 50) recientes.clear()
            recientes.add(hash)

            Thread {
                try {
                    procesar(prefs, paquete, titulo, cuerpo, monto, hash)
                } catch (e: Exception) {
                    Log.e(TAG, "Error procesando notificación", e)
                    prefs.registrarNotificacionLocal(
                        paquete = paquete,
                        titulo = titulo,
                        texto = cuerpo,
                        monto = monto,
                        estado = "ERROR_PROCESAMIENTO",
                        detalle = e.message.orEmpty()
                    )
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
        var token = prefs.accessToken

        // Si no hay token de acceso, intentar renovar con refresh token
        if (token.isEmpty() && prefs.refreshToken.isNotEmpty()) {
            token = renovarToken(prefs).orEmpty()
        }

        if (token.isEmpty()) {
            Log.w(TAG, "No hay credenciales activas de Supabase.")
            prefs.registrarNotificacionLocal(
                paquete = paquete,
                titulo = titulo,
                texto = cuerpo,
                monto = monto,
                estado = "SIN_AUTENTICACION",
                detalle = "No hay sesión activa de administrador en TurisApp."
            )
            return
        }

        // Llamar a validar_pago_por_notificacion (RPC atómica en Supabase)
        val payload = JSONObject().apply {
            put("p_monto", monto)
            put("p_titulo", if (titulo.isNotBlank()) titulo.take(200) else paquete.take(200))
            put("p_texto", cuerpo.take(500))
            put("p_hash", hash)
        }

        var rpc = request(
            "POST",
            "$base/rest/v1/rpc/validar_pago_por_notificacion",
            prefs.anonKey,
            token,
            payload.toString()
        )

        // Si el token expiró (401), renovar y reintentar una vez
        if (rpc.code == 401) {
            Log.i(TAG, "Token expirado. Renovando sesión de Supabase...")
            val nuevoToken = renovarToken(prefs)
            if (!nuevoToken.isNullOrEmpty()) {
                rpc = request(
                    "POST",
                    "$base/rest/v1/rpc/validar_pago_por_notificacion",
                    prefs.anonKey,
                    nuevoToken,
                    payload.toString()
                )
            }
        }

        if (rpc.code !in 200..299) {
            Log.w(TAG, "Error RPC: ${rpc.code} ${rpc.body.take(200)}")
            prefs.registrarNotificacionLocal(
                paquete = paquete,
                titulo = titulo,
                texto = cuerpo,
                monto = monto,
                estado = "ERROR_SERVIDOR_${rpc.code}",
                detalle = rpc.body.take(200)
            )
            return
        }

        val body = rpc.body.trim()
        if (body.isEmpty() || body == "null") {
            Log.i(TAG, "No hay cobro pendiente que coincida con Bs $monto")
            prefs.registrarNotificacionLocal(
                paquete = paquete,
                titulo = titulo,
                texto = cuerpo,
                monto = monto,
                estado = "SIN_COINCIDENCIA",
                detalle = "No se encontró ningún cobro pendiente por Bs $monto."
            )
            return
        }

        val fila = runCatching { JSONObject(body) }.getOrNull()
        val pagoId = fila?.optString("id").orEmpty()
        val estado = fila?.optString("estado").orEmpty()
        val cliente = fila?.optString("usuario_nombre").orEmpty()

        if (estado == "PAGADO") {
            Log.i(TAG, "¡Cobro $pagoId PAGADO exitosamente por Bs $monto!")
            prefs.registrarNotificacionLocal(
                paquete = paquete,
                titulo = titulo,
                texto = cuerpo,
                monto = monto,
                estado = "PAGADO",
                detalle = "Validado exitosamente. Cliente: $cliente. ID: $pagoId"
            )
        } else {
            prefs.registrarNotificacionLocal(
                paquete = paquete,
                titulo = titulo,
                texto = cuerpo,
                monto = monto,
                estado = estado.ifEmpty { "RESPUESTA_DESCONOCIDA" },
                detalle = body.take(150)
            )
        }
    }

    /**
     * Renueva el access_token de Supabase usando el refresh_token guardado.
     */
    private fun renovarToken(prefs: YapePrefs): String? {
        val refresh = prefs.refreshToken
        if (refresh.isEmpty()) return null

        return try {
            val base = prefs.url.trimEnd('/')
            val bodyJson = JSONObject().apply {
                put("refresh_token", refresh)
            }
            val res = request(
                "POST",
                "$base/auth/v1/token?grant_type=refresh_token",
                prefs.anonKey,
                null,
                bodyJson.toString()
            )
            if (res.code in 200..299) {
                val json = JSONObject(res.body)
                val newAccess = json.optString("access_token")
                val newRefresh = json.optString("refresh_token")
                if (newAccess.isNotEmpty()) {
                    prefs.accessToken = newAccess
                    if (newRefresh.isNotEmpty()) prefs.refreshToken = newRefresh
                    Log.i(TAG, "Sesión de Supabase renovada exitosamente.")
                    return newAccess
                }
            }
            null
        } catch (e: Exception) {
            Log.e(TAG, "Fallo al renovar token", e)
            null
        }
    }

    /**
     * Determina si la notificación parece un comprobante o transferencia de dinero.
     */
    private fun parecePago(paquete: String, texto: String): Boolean {
        val p = paquete.lowercase(Locale.US)
        // Detección por apps de bancos y billeteras en Bolivia
        if (p.contains("yape") || p.contains("bcp") || p.contains("bancamovil") ||
            p.contains("bancounion") || p.contains("unimovil") || p.contains("bnb") ||
            p.contains("bmsc") || p.contains("mercantil") || p.contains("ganadero") ||
            p.contains("bisa") || p.contains("bancosol") || p.contains("fiemovil") ||
            p.contains("simple") || p.contains("wallet")) {
            return true
        }

        val t = texto.lowercase(Locale.US)
        val claves = listOf(
            "yape", "yapearon", "yapeo", "yapeaste",
            "transferencia", "transf", "recibiste", "recibido", "recibida",
            "pago", "abono", "abonado", "acreditacion", "acreditación",
            "deposito", "depósito", "te envió", "te envio", "te transfirió",
            "te transfirio", "te pagó", "te pago", "qr", "simple",
            "cobro", "exitoso", "acreditado"
        )
        return claves.any { t.contains(it) }
    }

    /**
     * Extrae el monto numérico soportando diferentes formatos habituales en Bolivia:
     * - "Bs 25.00", "Bs. 25", "Bs25"
     * - "25 Bs", "25.00 Bs", "25,00 BOB"
     * - "por 25.00", "monto: 25.00"
     */
    private fun extraerMonto(texto: String): Double? {
        val t = texto.replace('\u00A0', ' ')

        // 1) Moneda antes del número: "Bs. 25.50", "Bs 25", "Bs.25", "BOB 50"
        val monedaAntes = Regex(
            """(?:bs\.?|bob|s/)\s*([0-9]{1,6}(?:[.,][0-9]{1,2})?)""",
            RegexOption.IGNORE_CASE
        )
        val matchAntes = monedaAntes.find(t)
        if (matchAntes != null) {
            val num = matchAntes.groupValues[1].replace(',', '.').toDoubleOrNull()
            if (num != null && num > 0) return num
        }

        // 2) Moneda después del número: "25.00 Bs", "25 Bs.", "50 BOB"
        val monedaDespues = Regex(
            """([0-9]{1,6}(?:[.,][0-9]{1,2})?)\s*(?:bs\.?|bob|s/)""",
            RegexOption.IGNORE_CASE
        )
        val matchDespues = monedaDespues.find(t)
        if (matchDespues != null) {
            val num = matchDespues.groupValues[1].replace(',', '.').toDoubleOrNull()
            if (num != null && num > 0) return num
        }

        // 3) Respaldo con palabras clave: "por 25.00", "monto: 25", "de 25"
        val porMonto = Regex(
            """(?:monto|por|de|valor)\s*:?\s*([0-9]{1,6}(?:[.,][0-9]{1,2})?)""",
            RegexOption.IGNORE_CASE
        )
        val matchPor = porMonto.find(t)
        if (matchPor != null) {
            val num = matchPor.groupValues[1].replace(',', '.').toDoubleOrNull()
            if (num != null && num > 0) return num
        }

        // 4) Cualquier número con 2 decimales: "25.00" o "25,00"
        val respaldo = Regex("""\b([0-9]{1,6}[.,][0-9]{2})\b""")
        val matchRespaldo = respaldo.find(t)
        if (matchRespaldo != null) {
            val num = matchRespaldo.groupValues[1].replace(',', '.').toDoubleOrNull()
            if (num != null && num > 0) return num
        }

        return null
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
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
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
