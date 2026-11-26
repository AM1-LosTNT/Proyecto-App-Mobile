-- ==============================================================================
-- TURISAPP · DIAGNÓSTICO COMPLETO DEL PAGO POR NOTIFICACIONES
-- ==============================================================================
-- Cómo usarlo:
--   1. Supabase → SQL Editor → New query.
--   2. Pega TODO este archivo y pulsa Run.
--   3. Devuelve UNA sola tabla:  seccion | objeto | estado | detalle
--
-- Es de SOLO LECTURA: no modifica ni borra nada.
--
-- Qué revisa:
--   1. Funciones RPC y cuál versión está activa (monto vs nombre+monto)
--   2. Overloads duplicados que hacen que PostgREST elija mal
--   3. Columnas que la app espera en pagos_qr / configuracion_cobros
--   4. Triggers (escucha activa y pedido/reserva a Pagado)
--   5. Políticas RLS de pedidos, detalle_pedidos, pagos_historial, pagos_qr
--   6. RLS activo, Realtime, replica identity, permisos EXECUTE
--   7. Tu usuario admin y el estado actual de la escucha
--   8. Últimos cobros (con hash, origen y nombre)
-- ==============================================================================

select * from (

-- -----------------------------------------------------------------------------
-- 1. FUNCIONES DEL PROCESO
-- -----------------------------------------------------------------------------
select '1. FUNCIONES'::text as seccion,
       p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' as objeto,
       case when p.prosecdef
            then 'OK (security definer)'
            else 'REVISAR (sin security definer)' end as estado,
       case
         when p.proname = 'validar_pago_por_notificacion'
              and p.prosrc ilike '%REGLA PRINCIPAL%'
           then 'Variante MONTO (correcta)'
         when p.proname = 'validar_pago_por_notificacion'
              and p.prosrc ilike '%MONTO y en NOMBRE%'
           then 'Variante NOMBRE+MONTO (puede bloquear pagos con otro nombre)'
         when p.proname = 'validar_pago_por_notificacion'
           then 'Variante desconocida: revisa pg_get_functiondef'
         when p.proname = 'crear_cobro_qr'
              and p.prosrc ilike '%p_usuario_nombre%'
           then 'Incluye usuario_nombre (correcta)'
         when p.proname = 'crear_cobro_qr'
           then 'NO guarda usuario_nombre (versión vieja)'
         when p.proname = 'fn_on_pago_qr_confirmado'
              and p.prosrc ilike '%Confirmada%'
           then 'MAL: usa reservas.estado = Confirmada (debe ser aceptada)'
         when p.proname = 'fn_on_pago_qr_confirmado'
           then 'OK (pedido Pagado + reserva aceptada)'
         else 'OK'
       end as detalle
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in (
       'crear_cobro_qr',
       'validar_pago_por_notificacion',
       'confirmar_pago_qr',
       'coincide_nombre_yape',
       'normalizar_texto',
       'es_admin',
       'expirar_cobros_vencidos',
       'recalcular_escucha',
       'fn_on_pago_qr_confirmado'
   )

-- -----------------------------------------------------------------------------
-- 2. OVERLOADS DUPLICADOS (causa típica de error 404/PGRST203)
-- -----------------------------------------------------------------------------
union all
select '2. OVERLOADS',
       p.proname,
       case when count(*) > 1
            then 'CONFLICTO: ' || count(*) || ' versiones'
            else 'OK' end,
       string_agg(pg_get_function_identity_arguments(p.oid), '  ||  ')
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in (
       'crear_cobro_qr',
       'validar_pago_por_notificacion',
       'confirmar_pago_qr'
   )
 group by p.proname

-- -----------------------------------------------------------------------------
-- 3. COLUMNAS QUE LA APP ESPERA EN pagos_qr
-- -----------------------------------------------------------------------------
union all
select '3. COLUMNAS pagos_qr',
       e.col,
       case when c.column_name is null then 'FALTA' else 'OK' end,
       coalesce(c.data_type, '')
  from (values
        ('usuario_nombre'),('evento_hash'),('origen_confirmacion'),
        ('confirmado_automaticamente'),('pagado_en'),('monto_recibido'),
        ('pagado_por'),('notificacion_texto'),('saldo_anterior'),
        ('saldo_nuevo'),('expira_en'),('id_pedido'),('id_reserva')
       ) as e(col)
  left join information_schema.columns c
    on c.table_schema = 'public'
   and c.table_name = 'pagos_qr'
   and c.column_name = e.col

-- -----------------------------------------------------------------------------
-- 4. COLUMNAS DE configuracion_cobros
-- -----------------------------------------------------------------------------
union all
select '4. COLUMNAS configuracion_cobros',
       e.col,
       case when c.column_name is null then 'FALTA' else 'OK' end,
       coalesce(c.data_type, '')
  from (values ('escucha_activa'),('qr_estatico_url'),('actualizado_en')) as e(col)
  left join information_schema.columns c
    on c.table_schema = 'public'
   and c.table_name = 'configuracion_cobros'
   and c.column_name = e.col

-- -----------------------------------------------------------------------------
-- 5. TRIGGERS
-- -----------------------------------------------------------------------------
union all
select '5. TRIGGERS',
       c.relname || ' · ' || t.tgname,
       case when t.tgenabled = 'O' then 'ACTIVO' else 'DESACTIVADO' end,
       pg_get_triggerdef(t.oid)
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('pagos_qr','configuracion_cobros')
   and not t.tgisinternal

-- -----------------------------------------------------------------------------
-- 6. RLS DE PEDIDOS / DETALLE / COMPROBANTES (tu problema de Pedidos (0))
-- -----------------------------------------------------------------------------
union all
select '6. RLS pedidos',
       tablename || ' · ' || policyname,
       cmd,
       case
         when coalesce(qual,'') ilike '%es_admin%'
           or coalesce(with_check,'') ilike '%es_admin%'
         then 'incluye es_admin (OK)'
         else 'NO incluye es_admin (el admin no verá estas filas)'
       end
  from pg_policies
 where schemaname = 'public'
   and tablename in ('pedidos','detalle_pedidos','pagos_historial')

-- -----------------------------------------------------------------------------
-- 7. RLS DE pagos_qr
-- -----------------------------------------------------------------------------
union all
select '7. RLS pagos_qr',
       policyname,
       cmd,
       coalesce(qual,'') ||
       case when with_check is not null
            then ' | CHECK: ' || with_check else '' end
  from pg_policies
 where schemaname = 'public'
   and tablename = 'pagos_qr'

-- -----------------------------------------------------------------------------
-- 8. ¿RLS ESTÁ ACTIVO?
-- -----------------------------------------------------------------------------
union all
select '8. RLS ACTIVO',
       c.relname,
       case when c.relrowsecurity then 'SI' else 'NO' end,
       ''
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in (
       'pagos_qr','pedidos','detalle_pedidos',
       'configuracion_cobros','pagos_historial'
   )

-- -----------------------------------------------------------------------------
-- 9. REALTIME
-- -----------------------------------------------------------------------------
union all
select '9. REALTIME',
       e.tabla,
       case when p.tablename is null
            then 'FALTA en la publicación supabase_realtime'
            else 'OK' end,
       ''
  from (values ('pagos_qr'),('pedidos'),('configuracion_cobros')) as e(tabla)
  left join pg_publication_tables p
    on p.pubname = 'supabase_realtime'
   and p.schemaname = 'public'
   and p.tablename = e.tabla

-- -----------------------------------------------------------------------------
-- 10. REPLICA IDENTITY
-- -----------------------------------------------------------------------------
union all
select '10. REPLICA IDENTITY',
       c.relname,
       case c.relreplident
         when 'f' then 'FULL (OK)'
         when 'd' then 'DEFAULT (puede faltar detalle en Realtime)'
         else c.relreplident::text
       end,
       ''
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('pagos_qr','pedidos')

-- -----------------------------------------------------------------------------
-- 11. PERMISOS EXECUTE PARA authenticated
-- -----------------------------------------------------------------------------
union all
select '11. GRANTS',
       'validar_pago_por_notificacion(numeric,text,text,text)',
       case
         when to_regprocedure(
                'public.validar_pago_por_notificacion(numeric,text,text,text)'
              ) is null then 'NO EXISTE (falta pago_automatico.sql)'
         when has_function_privilege(
                'authenticated',
                to_regprocedure(
                  'public.validar_pago_por_notificacion(numeric,text,text,text)'
                ),
                'EXECUTE'
              ) then 'OK authenticated'
         else 'FALTA EXECUTE a authenticated'
       end,
       ''

union all
select '11. GRANTS',
       'crear_cobro_qr(numeric,text,text,text,text)',
       case
         when to_regprocedure(
                'public.crear_cobro_qr(numeric,text,text,text,text)'
              ) is null then 'NO EXISTE (falta pago_automatico.sql)'
         when has_function_privilege(
                'authenticated',
                to_regprocedure(
                  'public.crear_cobro_qr(numeric,text,text,text,text)'
                ),
                'EXECUTE'
              ) then 'OK authenticated'
         else 'FALTA EXECUTE a authenticated'
       end,
       ''

union all
select '11. GRANTS',
       'confirmar_pago_qr(uuid,numeric,numeric)',
       case
         when to_regprocedure(
                'public.confirmar_pago_qr(uuid,numeric,numeric)'
              ) is null then 'NO EXISTE'
         when has_function_privilege(
                'authenticated',
                to_regprocedure(
                  'public.confirmar_pago_qr(uuid,numeric,numeric)'
                ),
                'EXECUTE'
              ) then 'OK authenticated'
         else 'FALTA EXECUTE a authenticated'
       end,
       ''

-- -----------------------------------------------------------------------------
-- 12. TU USUARIO ADMIN
-- -----------------------------------------------------------------------------
union all
select '12. ADMIN',
       u.email,
       case when u.rol = 'admin'
            then 'OK rol admin'
            else 'NO es admin (rol=' || coalesce(u.rol,'?') || ')' end,
       u.id::text
  from public.usuarios u
 where u.id = '8d9b6019-10e9-464e-8a2f-e5ed41c9fce1'::uuid

-- -----------------------------------------------------------------------------
-- 13. es_admin() SIN SESIÓN (debe ser false, nunca null)
-- -----------------------------------------------------------------------------
union all
select '13. ES_ADMIN sin sesión',
       'public.es_admin()',
       case
         when public.es_admin() is false then 'OK (false)'
         when public.es_admin() is null then 'MAL (null: permite saltarse comprobaciones)'
         else 'true'
       end,
       'En el SQL Editor debe salir false'

-- -----------------------------------------------------------------------------
-- 14. ESTADO ACTUAL DE LA ESCUCHA
-- -----------------------------------------------------------------------------
union all
select '14. CONFIGURACIÓN',
       'configuracion_cobros id=1',
       case when escucha_activa
            then 'Escucha ACTIVA'
            else 'Escucha INACTIVA' end,
       'QR: ' || coalesce(nullif(qr_estatico_url,''), '(vacío)')
  from public.configuracion_cobros
 where id = 1

-- -----------------------------------------------------------------------------
-- 15. ÚLTIMOS 10 COBROS
-- -----------------------------------------------------------------------------
union all
(select '15. ÚLTIMOS COBROS',
        referencia_interna,
        estado,
        'monto=' || monto_esperado::text
        || ' · pedido=' || coalesce(id_pedido,'-')
        || ' · nombre=' || coalesce(usuario_nombre,'-')
        || ' · origen=' || coalesce(origen_confirmacion,'-')
        || ' · hash=' || coalesce(left(evento_hash,12),'-')
        || ' · creado=' || to_char(creado_en,'DD/MM HH24:MI')
   from public.pagos_qr
  order by creado_en desc
  limit 10)

-- -----------------------------------------------------------------------------
-- 16. CONTEOS
-- -----------------------------------------------------------------------------
union all
select '16. CONTEO',
       'pedidos',
       count(*)::text,
       'total en la tabla (el SQL Editor ve todo)'
  from public.pedidos

union all
select '16. CONTEO',
       'pagos_qr pendientes',
       count(*)::text,
       'vigentes (expira_en > now): '
       || (count(*) filter (where expira_en > now()))::text
  from public.pagos_qr
 where estado = 'PENDIENTE'

) as diagnostico
order by seccion, objeto;
