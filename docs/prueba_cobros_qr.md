# Prueba real de cobros con QR (Yape) — paso a paso

> Esta guía valida el flujo **real**, sin simuladores: el cliente genera un cobro,
> transfiere de verdad por Yape y el pago se completa **automáticamente** con la
> notificación. No se escribe ningún saldo.
>
> Configuración previa del sistema: [`docs/cobros_yape_qr.md`](./cobros_yape_qr.md)

---

## 0. Qué necesitas antes de empezar

| Requisito | Detalle |
|---|---|
| SQL ejecutado | `supabase/cobros_yape_qr.sql` |
| **Script de pago automático** | `supabase/pago_automatico.sql` → **obligatorio**, ver paso 1 |
| App instalada | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` en **dos teléfonos** |
| Cuenta admin | `christopherlotoreherrera@gmail.com` (rol `admin`) |
| Segunda cuenta Yape | De un familiar o amigo, con saldo para enviar **Bs 0.10** |
| Cuenta cliente | Cualquier otra cuenta de TurisApp (no la admin) |
| QR de Bs 0 | Captura de tu QR personal de Yape/Banca **sin monto fijo** |

> ⚠️ El teléfono que **recibe** las notificaciones debe ser el que tiene la
> sesión de Yape de tu cuenta de cobro. Ese mismo teléfono debe tener TurisApp
> abierta con la cuenta **admin**.

---

## 1. Aplicar el script de pago automático (TU TURNO — 2 minutos)

Este script deja todo en un estado conocido y corrige los problemas anteriores:

1. `es_admin()` devolvía `NULL` para usuarios sin sesión y la comprobación
   `if not es_admin()` se saltaba → un anónimo podía confirmar pagos.
2. El trigger escribía `reservas.estado = 'Confirmada'`, pero tu tabla usa
   estados en minúsculas (`aceptada`) → confirmar un pago de reserva fallaba.
3. La validación exigía **monto + nombre** del cliente, y bloqueaba los pagos
   hechos desde una cuenta Yape con otro nombre. Ahora valida por **monto**.

**Pasos:**

1. Supabase → **SQL Editor → New query**.
2. Pega **todo** el contenido de:

   ```
   supabase/pago_automatico.sql
   ```

3. Pulsa **Run**.
4. Debe aparecer un resultado con la columna `es_admin_sin_sesion` = **`false`**
   y las 3 funciones (`crear_cobro_qr`, `validar_pago_por_notificacion`,
   `confirmar_pago_qr`).

> Si en lugar de `false` ves `null`, el script no se aplicó: vuelve a ejecutarlo.

> ⚠️ No ejecutes `supabase/validador_yape_nombre_monto.sql`: está obsoleto y
> volvería a exigir el nombre.

---

## 2. Verificar la infraestructura (SQL Editor)

Ejecuta cada consulta y compara con el resultado esperado.

```sql
-- 2.1 Debe devolver false (no null)
select public.es_admin() as es_admin_sin_sesion;

-- 2.2 Debe devolver 1 fila con escucha_activa = false
select id, escucha_activa, qr_estatico_url, titular_cuenta, banco_nombre
from public.configuracion_cobros;

-- 2.3 Debe listar tu cuenta como admin
select id, email, rol from public.usuarios where rol = 'admin';

-- 2.4 Deben aparecer las 2 tablas
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('pagos_qr', 'configuracion_cobros')
order by table_name;

-- 2.5 Deben existir los 3 buckets
select id, name, public from storage.buckets
where id in ('imagenes', 'avatars', 'business-images');

-- 2.6 Debe mostrar la política de UPDATE solo para admin
select policyname, cmd, qual
from pg_policies
where schemaname = 'public' and tablename = 'pagos_qr';
```

**Resultado esperado**

| Consulta | Resultado |
|---|---|
| 2.1 | `false` |
| 2.2 | 1 fila, `escucha_activa = false` |
| 2.3 | `christopherlotoreherrera@gmail.com · admin` |
| 2.4 | `configuracion_cobros` y `pagos_qr` |
| 2.5 | `imagenes`, `avatars`, `business-images` |
| 2.6 | una política de `UPDATE` con `es_admin()` |

Si falta el bucket `imagenes`, la subida del QR fallará: vuelve a ejecutar
`supabase/cobros_yape_qr.sql` (es idempotente).

---

## 3. Preparar el teléfono del admin

### 3.1 Instalar / actualizar la app

Los APK **ya están compilados** en `build/app/outputs/flutter-apk/` (24/11/2026,
5:52) e incluyen todos los cambios del listener de Yape. **No hace falta
recompilar** para esta prueba.

| APK | Tamaño | Cuándo usarlo |
|---|---|---|
| `app-arm64-v8a-release.apk` | 20 MB | **Recomendado** para teléfonos reales (instala rápido) |
| `app-debug.apk` | 243 MB | Solo si necesitas logs de Dart en el dispositivo |

Instala el mismo APK en el teléfono que tiene Yape y en el del cliente.

> Si más adelante cambias código Dart o Kotlin, recompila con
> `flutter build apk --release` (o `--debug`).

### 3.2 Iniciar sesión como admin

Abre TurisApp en el teléfono receptor con **`christopherlotoreherrera@gmail.com`**.

> Al iniciar sesión, la app guarda la sesión de Supabase en el servicio nativo.
> Si cambiaste de cuenta, **cierra sesión y vuelve a entrar** para resincronizar.
> Si la sesión caduca, el listener deja de validar hasta que abras la app
> (así se renueva el token).

### 3.3 Subir tu QR de Bs 0

1. **Administración → Pedidos & Pagos → pestaña `Yape QR`**.
2. En la tarjeta **“QR estático de Bs 0”** pulsa **“Subir mi QR (Yape / Banca)”**.
3. Elige la captura de tu QR personal **sin monto fijo**.
4. Espera el mensaje **“QR estático actualizado correctamente.”**

**Resultado esperado**

- La imagen aparece en la tarjeta.
- En la base:

```sql
select qr_estatico_url from public.configuracion_cobros;
-- debe devolver una URL https://.../storage/v1/object/public/imagenes/qrs/...
```

### 3.4 Dar acceso a notificaciones

1. En la misma pestaña pulsa **“Abrir ajustes”**.
2. En la lista de apps toca **TurisApp**.
3. Activa **“Permitir acceso a notificaciones”**.
4. Vuelve a la app y pulsa **“Ya lo activé, verificar”**.

**Resultado esperado**

- La tarjeta cambia a verde: **“Acceso a notificaciones CONCEDIDO”**.
- El estado del listener muestra **“🟢 Escucha ACTIVA en tu teléfono”** cuando
  haya un cobro pendiente.

### 3.5 Quitar restricciones de batería (crítico)

En Xiaomi/Redmi, Samsung, Huawei, Oppo, etc.:

> Ajustes → Apps → TurisApp → **Batería → Sin restricciones**

Sin esto, Android puede matar el listener y **no se detectará el pago**.

---

## 4. Crear el producto de prueba (Bs 0.10)

Para no arriesgar dinero:

1. Admin → **Administración → Tienda & Stock → Nuevo producto**.
2. Nombre: `Prueba QR`
3. Precio: `0.10`
4. Stock: `5`
5. Guarda el producto.

> Al terminar la prueba, bórralo o desactívalo.

---

## 5. Prueba real — procedimiento paso a paso

### Paso 1 · El cliente crea el pedido

**Acción**
1. En el **teléfono cliente**, inicia sesión con otra cuenta.
2. Tienda → agrega `Prueba QR` al carrito.
3. **Confirmar pedido**.

**Resultado esperado**
- Mensaje de pedido creado y código de referencia generado.

**Verificar**
```sql
select id, codigo_referencia, estado, total
from public.pedidos
order by created_at desc
limit 1;
```
→ `estado = 'Pendiente'`, `total = 0.10`.

---

### Paso 2 · El cliente abre la pantalla de pago

**Acción**
- Pulsa **“Pagar con QR (Yape)”** (en el carrito) o
  **“Pagar con QR de Bs 0 (Yape)”** (en el historial del pedido).

**Resultado esperado en el cliente**

| Elemento | Valor esperado |
|---|---|
| Título | `Pago con QR (Bs 0)` |
| Monto | `Bs. 0.10` (con botón para copiar) |
| Referencia | `PAY-AAAAMMDDHHMMSS-XXXX` |
| Imagen | **Tu QR configurado** |
| Temporizador | `10:00` bajando |
| Banner | 🟢 `Escucha activa en el receptor: Esperando que realices la transferencia...` |

**Resultado esperado en la base**

```sql
select referencia_interna, monto_esperado, estado, expira_en
from public.pagos_qr
order by creado_en desc
limit 1;
```
→ `estado = 'PENDIENTE'`, `monto_esperado = 0.10`, `expira_en ≈ ahora + 10 min`.

```sql
select escucha_activa from public.configuracion_cobros;
```
→ **`true`** (el trigger la encendió automáticamente).

**En el teléfono admin**

- La pestaña `Yape QR` muestra el cobro en **PENDIENTE**.
- Aparece el indicador **“🟢 Escucha ACTIVA”**.

> Si `escucha_activa` sigue en `false`, el trigger no se creó. Revisa:
> ```sql
> select tgname from pg_trigger where tgrelid = 'public.pagos_qr'::regclass;
> ```

---

### Paso 3 · Transferencia real desde Yape

**Acción**
1. En el **segundo teléfono**, abre Yape con la otra cuenta.
2. Escanea el QR que muestra la pantalla del cliente.
3. Envía **exactamente `Bs 0.10`**.

> El monto debe coincidir al centavo con el cobro pendiente.

**Resultado esperado**

- Llega la notificación de Yape al teléfono admin.
- El `NotificationListenerService` la lee, verifica que hay escucha activa y que
  el monto coincide.
- El cobro pasa **directo a `PAGADO`** en segundos. No hay paso intermedio ni
  confirmación manual.
- La pantalla del cliente cambia **sola** a la pantalla de pago completado:
  **“¡Pago completado!”** con el check animado, el monto y la referencia.
  No hay que refrescar nada.

**Verificar**

```sql
select referencia_interna, estado, monto_recibido, pagado_por,
       notificacion_texto, evento_hash, pagado_en,
       origen_confirmacion, confirmado_automaticamente
from public.pagos_qr
order by creado_en desc
limit 1;
```

→ `estado = 'PAGADO'`, `monto_recibido = 0.10`,
`origen_confirmacion = 'NOTIFICACION'`, `confirmado_automaticamente = true`,
`notificacion_texto` contiene el texto real de Yape y `evento_hash` no es nulo.

**Log del teléfono admin (USB)**

```bash
adb logcat -s YapeListener
```

Debe aparecer:

```
¡Cobro <uuid> PAGADO exitosamente por Bs 0.1!
```

---

### Paso 4 · Verificación (opcional) del saldo en banca

Ya no hay que escribir ningún saldo. El pago queda completado solo con la
notificación.

**Acción (opcional)**
1. Abre Yape/Banca y comprueba que el saldo subió exactamente **Bs 0.10**.
2. En el panel admin → `Yape QR` el cobro ya aparece en **`PAGADO`** con el aviso
   verde “Pago completado automáticamente por la notificación de Yape”.

**Resultado esperado**

- La pantalla del cliente muestra **“¡Pago completado!”** con el check animado.
- El pedido pasa a **`Pagado`** solo.
- `escucha_activa` vuelve a **`false`** (ya no hay cobros pendientes).

**Verificar**

```sql
select p.referencia_interna, p.estado, p.monto_esperado, p.monto_recibido,
       p.origen_confirmacion, p.confirmado_automaticamente, p.pagado_en
from public.pagos_qr p
order by p.creado_en desc
limit 1;
```
→ `estado = 'PAGADO'`, `origen_confirmacion = 'NOTIFICACION'`,
`confirmado_automaticamente = true`.

```sql
select codigo_referencia, estado, updated_at
from public.pedidos
order by created_at desc
limit 1;
```
→ `estado = 'Pagado'`.

```sql
select escucha_activa from public.configuracion_cobros;
```
→ `false`.

**Si el cobro estaba asociado a una reserva**

```sql
select id, estado from public.reservas order by id desc limit 3;
```
→ la reserva pasa a `aceptada` (minúsculas).

**Respaldo manual (solo si la notificación no llegó)**

En el panel admin, en el cobro `PENDIENTE`, pulsa
**“Marcar como pagado (solo si no llegó la notificación)”**. Es un solo toque,
sin escribir saldos.

---

### Paso 5 · Comprobación visual final

| Pantalla | Estado final esperado |
|---|---|
| Cliente | Pantalla “¡Pago completado!” con check animado |
| Admin · Yape QR | Cobro en `PAGADO` con aviso verde automático |
| Admin · Pedidos | Pedido en `Pagado` |
| Supabase | `pagos_qr.estado = PAGADO`, `confirmado_automaticamente = true`, `escucha_activa = false` |

---

## 6. Máquina de estados esperada

```
                    crear_cobro_qr
                          │
                          ▼
                    ┌───────────┐
        notificación│ PENDIENTE │  (expira en 10 min)
        real de Yape└─────┬─────┘
                          │
                          │ validar_pago_por_notificacion
                          │ (monto exacto → PAGADO)
                          ▼
                     ┌────────┐
                     │ PAGADO │
                     └────────┘

  PENDIENTE ──► EXPIRADO    (pg_cron, 10 min sin pago)
  PENDIENTE ──► RECHAZADO   (se crea un cobro nuevo del mismo pedido)
  PENDIENTE ──► PAGADO      (respaldo manual del admin, un toque)
```

| Estado | Quién lo produce | Significado |
|---|---|---|
| `PENDIENTE` | Cliente (`crear_cobro_qr`) | Esperando la transferencia |
| `PAGADO` | Listener nativo (`validar_pago_por_notificacion`) | Notificación con el monto exacto |
| `PAGADO` | Admin (`confirmar_pago_qr`, respaldo) | Marcado a mano si no llegó la notificación |
| `EXPIRADO` | `pg_cron` / `expirar_cobros_vencidos()` | Pasaron 10 minutos |
| `RECHAZADO` | `crear_cobro_qr` | Reemplazado por un intento nuevo |

> `VALIDADO_NOTIF` ya no se usa: era el paso intermedio que obligaba a escribir
> saldos. Los cobros viejos en ese estado se migran a `PAGADO`.

---

## 7. Pruebas negativas (recomendadas)

### 7.1 Monto distinto → no debe validar

1. Genera un cobro de `Bs 0.10`.
2. Transfiere `Bs 0.20`.

**Esperado:** el cobro sigue `PENDIENTE`; en el log:
`No hay cobro pendiente que coincida con Bs 0.2`.
El dinero llegó a tu cuenta, pero el sistema **no** lo asocia. Se resuelve
manualmente o generando un cobro del monto correcto.

### 7.2 Expiración a los 10 minutos

1. Genera un cobro y **no pagues**.
2. Espera 10 minutos (o fuerza la expiración):

```sql
update public.pagos_qr
   set expira_en = now() - interval '1 minute'
 where estado = 'PENDIENTE';

select public.expirar_cobros_vencidos();
```

**Esperado:** `estado = 'EXPIRADO'` y `escucha_activa = false`.
La pantalla del cliente muestra “El cobro expiró por tiempo límite”.

### 7.3 Un usuario normal NO puede confirmar el pago

En el SQL Editor (sin sesión) ejecuta:

```sql
select public.confirmar_pago_qr(
  (select id from public.pagos_qr order by creado_en desc limit 1)
);
```

**Esperado:** error
`Solo el administrador puede confirmar el pago.`

> Lo mismo aplica a `validar_pago_por_notificacion`: sin sesión admin responde
> `Sesión requerida para validar un pago.` o
> `Solo el administrador puede validar pagos con notificaciones.`

### 7.4 El cliente NO puede marcar su pago como PAGADO

La política RLS `Solo admin actualiza pagos` impide el `UPDATE` directo desde
la app del cliente. Si se intenta por fuera, Supabase responde con 0 filas
afectadas / error de RLS.

### 7.5 Un nombre distinto en Yape NO bloquea el pago

Este era el fallo del script anterior (exigía nombre + monto). Con la regla
actual:

1. Genera un cobro con la cuenta de TurisApp de `Christopher`.
2. Transfiere desde la cuenta Yape de otra persona (por ejemplo, un familiar).

**Esperado:** el pago se completa igual, porque la validación es por **monto**.
El nombre solo se usa como desempate si hubiera dos cobros pendientes del mismo
monto.

### 7.6 Notificación duplicada

Yape puede repetir la notificación. El `evento_hash` (SHA-256) es `UNIQUE`, así
que una misma notificación **no** valida dos cobros.

```sql
select evento_hash, count(*)
from public.pagos_qr
where evento_hash is not null
group by evento_hash
having count(*) > 1;
```
**Esperado:** 0 filas.

---

## 8. Diagnóstico si algo falla

### 8.1 El admin no ve el cobro

```sql
select id, referencia_interna, monto_esperado, estado, creado_en
from public.pagos_qr
order by creado_en desc limit 5;
```

- Si no hay filas → el cliente no llegó a generar el cobro (revisa el error en
  su pantalla; suele ser que el SQL no estaba aplicado).
- Si hay filas pero el panel no las muestra → baja y refresca la pestaña, o
  revisa que estés con la cuenta admin.

### 8.2 `escucha_activa` no se enciende

```sql
select tgname, tgenabled
from pg_trigger
where tgrelid = 'public.pagos_qr'::regclass;

select public.expirar_cobros_vencidos();
select escucha_activa from public.configuracion_cobros;
```

### 8.3 No se detecta la transferencia real

Checklist:

1. ¿La notificación de Yape aparece en la barra del teléfono admin?
   Si Yape no notifica, no hay nada que leer.
2. ¿El teléfono admin tiene **Acceso a notificaciones** concedido?
3. ¿TurisApp está **sin restricciones de batería**?
4. ¿El cobro estaba `PENDIENTE` y dentro de los 10 minutos?
5. ¿La sesión del listener sigue viva? Abre la app del admin.

Log en vivo:

```bash
adb logcat -s YapeListener
```

Mensajes y su significado:

| Log | Significado |
|---|---|
| `Escucha inactiva: se ignora la notificación.` | No hay cobro pendiente vigente |
| `No hay cobro pendiente que coincida con Bs X` | El monto no coincide |
| `Sesión expirada: abre TurisApp para renovarla.` | Token caducado |
| `¡Cobro <id> PAGADO exitosamente por Bs X!` | ✅ Funcionó |

Si el formato de tu notificación es distinto, **copia el texto exacto** que
aparece en la barra de notificaciones y ajústalo: el detector acepta `Bs`,
`Bs.`, `BOB`, `S/`, con coma (`0,10`) o punto (`0.10`), y como respaldo
cualquier número decimal.

### 8.4 Error al confirmar el pago (respaldo manual)

| Mensaje | Causa |
|---|---|
| `Solo el administrador...` | La cuenta no es admin o no aplicaste `pago_automatico.sql` |
| `El cobro ya fue procesado` | Ya está `PAGADO`, `EXPIRADO` o `RECHAZADO` |
| `El cobro no existe` | UUID incorrecto |

### 8.5 El pedido no cambia a Pagado

El trigger `trg_pago_qr_confirmado` actualiza `pedidos.estado = 'Pagado'` cuando
`pagos_qr.id_pedido` no es nulo. Verifica:

```sql
select id_pedido, estado from public.pagos_qr
order by creado_en desc limit 1;

select id, estado from public.pedidos
where id = (select id_pedido from public.pagos_qr
            order by creado_en desc limit 1);
```

---

## 9. Checklist de aceptación

Marca cada punto cuando lo compruebes:

- [ ] Parche aplicado (`es_admin()` = `false` sin sesión)
- [ ] `supabase/pago_automatico.sql` aplicado (las 3 funciones existen)
- [ ] Buckets de Storage existen
- [ ] QR de Bs 0 subido y visible en la app del cliente
- [ ] Acceso a notificaciones concedido
- [ ] Batería sin restricciones
- [ ] Cobro generado en `PENDIENTE`
- [ ] `escucha_activa = true` al crear el cobro
- [ ] Transferencia real de Bs 0.10 detectada → **`PAGADO`**
- [ ] Cliente ve la pantalla “¡Pago completado!” con check animado
- [ ] Pedido en `Pagado`
- [ ] `escucha_activa = false` al terminar
- [ ] `origen_confirmacion = 'NOTIFICACION'`
- [ ] Un usuario sin sesión **no** puede confirmar (prueba 7.3)

---

## 10. Limpieza después de la prueba

1. Borra o desactiva el producto `Prueba QR`.
2. (Opcional) Borra los cobros de prueba:

```sql
delete from public.pagos_qr
where monto_esperado <= 0.10
  and creado_en > now() - interval '1 day';
```

> No borres cobros reales. Si quieres conservar la auditoría, deja los registros.

---

## 11. Anexo · Consultas útiles

```sql
-- Últimos cobros con todo el detalle
select p.referencia_interna, p.monto_esperado, p.monto_recibido, p.estado,
       p.pagado_por, p.saldo_anterior, p.saldo_nuevo,
       p.creado_en, p.expira_en, p.pagado_en,
       u.email as admin
from public.pagos_qr p
left join public.usuarios u on u.id = p.validado_por_admin
order by p.creado_en desc
limit 10;

-- Estado de la escucha y del QR
select escucha_activa,
       qr_estatico_url is not null as qr_configurado,
       actualizado_en
from public.configuracion_cobros;

-- Cobros pendientes vigentes
select referencia_interna, monto_esperado, expira_en
from public.pagos_qr
where estado = 'PENDIENTE' and expira_en > now()
order by creado_en;

-- Forzar expiración manual
select public.expirar_cobros_vencidos();

-- Ver si pg_cron está programado
select jobname, schedule, active
from cron.job
where jobname = 'turisapp-expirar-cobros';
```

---

**Resultado global esperado:** una transferencia real de Bs 0.10 queda
registrada de principio a fin — detectada por la notificación de Yape, el cobro
pasa solo a `PAGADO`, el cliente ve la pantalla animada de pago completado, el
pedido queda en `Pagado` y la escucha se apaga automáticamente. Sin escribir
saldos ni refrescar nada.
