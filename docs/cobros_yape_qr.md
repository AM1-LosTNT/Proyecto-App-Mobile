# Cobros con QR estático de Bs 0 + validación de notificaciones

Sistema implementado en TurisApp para:

1. Mostrar **tu QR personal de Yape/Banca (sin monto fijo, Bs 0)**.
2. Que el cliente escriba el monto exacto y genere el cobro.
3. Activar la escucha de notificaciones **solo mientras existe un cobro PENDIENTE**
   (ahorro de batería y menos falsos positivos).
4. Marcar el cobro **directo como `PAGADO`** cuando llega la notificación real
   con el monto exacto. Sin confirmación manual ni registro de saldos.
5. Mostrar al cliente una **pantalla animada de pago completado** en cuanto el
   cobro se paga (Realtime, sin refrescar).

---

## Arquitectura (cómo quedó)

```
Cliente                        Supabase                         Teléfono del admin
────────                       ────────                         ─────────────────
RPC crear_cobro_qr  ────────►  pagos_qr (PENDIENTE)  ◄────────  NotificationListenerService
                                │ trigger                         (lee notificación Yape)
                                ▼                                 │
                           escucha_activa = true                  ▼
                                                          RPC validar_pago_por_notificacion
                                                          (monto exacto → PAGADO)
                                │
                                ▼
                        pagos_qr (PAGADO) + pedido/reserva actualizados
                                │
                                ▼
Muestra QR Bs 0      ◄──── Realtime ────  pantalla "¡Pago completado!"
```

### Decisiones importantes

- **No se usa Edge Function.** El teléfono del admin habla directamente con
  Supabase usando su propia sesión de administrador. Las reglas RLS y las RPC
  `security definer` validan el rol en el servidor, así que no hay secretos
  extra que desplegar ni mantener.
- La escucha de notificaciones se ejecuta en **código nativo Android**
  (`NotificationListenerService`), por lo que funciona aunque la app esté en
  segundo plano o cerrada (mientras Android mantenga el proceso).
- El cliente **no puede** marcar su pago como pagado: la política RLS de
  `UPDATE` en `pagos_qr` es solo para admin.

---

## PASO 1 — Ejecutar el SQL en Supabase (TU TURNO)

1. Abre tu proyecto en <https://supabase.com>.
2. Ve a **SQL Editor → New query**.
3. Copia **todo** el contenido de:

   ```
   supabase/cobros_yape_qr.sql
   ```

4. Pega y pulsa **Run**.

El script es idempotente (puedes ejecutarlo otra vez si algo falla). Crea:

- Tablas `pagos_qr` y `configuracion_cobros`.
- Trigger de expiración + `escucha_activa` (con protección anti-recursión).
- RPC `crear_cobro_qr`, `confirmar_pago_qr` y `es_admin`.
- Realtime en ambas tablas.
- RLS (solo admin actualiza pagos y configuración).
- Buckets de Storage `imagenes`, `avatars`, `business-images`.
- Job de `pg_cron` para expirar cobros cada minuto (si la extensión está activa).

### Verificación rápida (pegar en SQL Editor)

```sql
-- Debe devolver una fila con escucha_activa = false
select * from public.configuracion_cobros;

-- Debe listar tu cuenta como admin
select id, email, rol from public.usuarios where rol = 'admin';

-- Debe devolver las 2 tablas
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('pagos_qr', 'configuracion_cobros');
```

Si no apareces como admin:

```sql
update public.usuarios
   set rol = 'admin'
 where email = 'christopherlotoreherrera@gmail.com';  -- tu correo
```

> `pg_cron` es opcional. Si el script avisa que no está habilitado, actívalo en
> **Database → Extensions → pg_cron**. Sin él, los cobros igual expiran cuando
> alguien consulta/crea un cobro, pero no cada minuto.

---

## PASO 2 — Instalar la app en el teléfono del admin

```bash
flutter pub get
flutter build apk --debug
```

Instala el APK en el teléfono donde tienes Yape y en el que iniciarás sesión con
**tu cuenta admin**. El APK queda en:

```
build/app/outputs/flutter-apk/app-debug.apk
```

---

## PASO 3 — Subir tu QR de Bs 0 (TU TURNO)

1. En la app entra como admin.
2. **Administración → Pedidos & Pagos → Yape QR**.
3. En la tarjeta “QR estático de Bs 0” pulsa **Subir mi QR**.
4. Elige la captura de tu QR personal de Yape/Banca **sin monto fijo**.

Se sube a Supabase Storage y se guarda en `configuracion_cobros.qr_estatico_url`.
Los clientes lo verán al instante, sin recompilar la app.

---

## PASO 4 — Dar acceso a notificaciones (solo teléfono admin)

1. **Administración → Pedidos & Pagos → Yape QR**.
2. Pulsa **Abrir ajustes**.
3. En la lista de apps toca **TurisApp** y activa **Permitir acceso a notificaciones**.
4. Vuelve a la app y pulsa **“Ya lo activé, verificar”**.
   Debe quedar en verde: `Acceso a notificaciones CONCEDIDO`.

**Muy importante en Xiaomi/Redmi, Samsung, Huawei, etc.:** desactiva la
optimización de batería para TurisApp:

> Ajustes → Apps → TurisApp → Batería → **Sin restricciones**.

Sin eso, el sistema puede matar el listener y no detectar pagos.

---

## PASO 5 — Prueba real (sin simulador)

El botón “Simular Notificación Yape” es **solo diagnóstico**: no participa en el
flujo real. Para la prueba de verdad necesitas una **segunda cuenta de Yape**
(de un familiar o amigo) que te envíe el monto.

### 5.1 Prepara un producto de prueba de Bs 0,10

1. Admin → **Administración → Tienda & Stock → Nuevo producto**.
2. Nombre: `Prueba QR`, precio: `0.10`, stock: `5`.

Así el pedido real cuesta Bs 0,10 y no arriesgas dinero.

### 5.2 Flujo real completo

1. Cliente (otra cuenta) → tienda → agrega `Prueba QR` → **Confirmar pedido** →
   **Pagar con QR (Yape)**.
   Se muestra **tu QR** con el monto `Bs. 0.10` y el temporizador de 10:00.
2. En el teléfono admin → **Pedidos & Pagos → Yape QR**:
   debe aparecer el cobro `PENDIENTE` y el indicador verde **“Escucha ACTIVA”**.
3. Desde la segunda cuenta de Yape, escanea el QR que muestra la pantalla del
   cliente y envía **exactamente Bs 0.10**.
4. En segundos, el teléfono admin recibe la notificación real de Yape; el
   listener la valida por **monto** y el cobro pasa **directo a `PAGADO`**.
   El cliente ve la pantalla animada **“¡Pago completado!”** sin refrescar.
5. El pedido pasa solo a **Pagado** y la escucha se apaga (`escucha_activa = false`).
   No hay que escribir saldos ni confirmar nada.
6. Borra o desactiva el producto `Prueba QR`.

### Si la transferencia real no se detecta

- ¿La notificación de Yape aparece en la barra del teléfono admin? Si Yape no
  notifica, el sistema no tiene qué leer.
- ¿El cobro estaba `PENDIENTE` y la escucha en verde?
- Revisa el log del teléfono conectado por USB:

  ```bash
  adb logcat -s YapeListener
  ```

  Verás mensajes como:
  - `Escucha inactiva: se ignora la notificación.`
  - `No hay cobro pendiente que coincida con Bs ...`
  - `Cobro ... validado por notificación de Bs ...`
- Si tu notificación no usa “Bs” (por ejemplo `S/ 0,10`), el detector igual
  toma el número decimal como respaldo.
- Si aun así falla, **copia el texto exacto de la notificación de Yape** y lo
  ajustamos: cada versión de Yape/Banca redacta distinto.
- Confirma permiso de notificaciones activo y batería sin restricciones.

### Simulador (opcional)

El botón “Simular Notificación Yape (Prueba)” puedes ignorarlo. Sirve para
probar la pantalla del cliente sin mover dinero, pero el flujo de producción es
el de la prueba real de arriba.

---

## Cómo funciona el ahorro de batería

- Android exige que el `NotificationListenerService` esté registrado siempre;
  eso no consume batería por sí solo.
- El servicio **no consulta internet** hasta que llega una notificación que
  parece de Yape/Banca.
- Aun así, antes de procesar consulta `configuracion_cobros.escucha_activa`.
  Si no hay un cobro `PENDIENTE` vigente, termina de inmediato.
- Al crear el cobro, el trigger enciende `escucha_activa`.
- Al pagarse o expirar (10 min), el trigger la apaga.
- Anti-duplicados: `evento_hash` SHA-256 evita que una misma notificación valide
  dos cobros.

---

## Solución de problemas

| Síntoma | Causa / solución |
|---|---|
| El panel admin no aparece | Tu usuario no tiene `rol = 'admin'` en `public.usuarios`. |
| El QR no aparece al cliente | Falta subirlo en **Yape QR → Subir mi QR**; verifica que el bucket `imagenes` exista (lo crea el SQL). |
| “La función crear_cobro_qr no existe” | No ejecutaste el SQL del Paso 1. |
| El admin no detecta la notificación | Falta el permiso de acceso a notificaciones, batería optimizada, o la notificación no contiene `Bs 12.34`. |
| El admin detecta pero el cliente no ve el cambio | Revisa Realtime en Supabase (Database → Replication) y que la app del cliente tenga internet. |
| La sesión del listener expiró | Abre la app del admin: el token se renueva y se sincroniza con el servicio nativo. |
| Los cobros quedan `PENDIENTE` | Activa `pg_cron` o ejecuta `select public.expirar_cobros_vencidos();`. |
| Un cobro fue `RECHAZADO` | Se generó un intento nuevo para el mismo pedido; el anterior se cancela automáticamente. |

---

## Archivos modificados / creados

**Base de datos**
- `supabase/cobros_yape_qr.sql` — script completo y corregido.

**Flutter**
- `lib/config/supabase_config.dart` — URL y clave centralizadas.
- `lib/services/yape_listener_bridge.dart` — puente con Android.
- `lib/services/yape_notification_service.dart` — RPC, QR configurable y sesión nativa.
- `lib/services/supabase_service.dart` — confirmación de saldo vía RPC.
- `lib/providers/app_state.dart` — sincroniza sesión/rol con el listener nativo.
- `lib/screens/admin/admin_dashboard_screen.dart` — subir QR, permiso de notificaciones y refresco automático.
- `lib/screens/shop/qr_static_cobro_screen.dart` — QR configurable, estado rechazado y mensaje si falta el QR.
- `lib/main.dart` — usa `SupabaseConfig`.

**Android**
- `MainActivity.kt` — canal `turisapp/yape_listener`.
- `YapeNotificationListenerService.kt` — lectura de notificaciones y validación.
- `YapePrefs.kt` — sesión y banderas del listener.
- `AndroidManifest.xml` — declara el servicio con `BIND_NOTIFICATION_LISTENER_SERVICE`.
