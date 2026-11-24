-- ==============================================================================
-- TURISAPP · CONFIRMACIÓN AUTOMÁTICA DE PAGOS QR
-- ==============================================================================
-- Ejecuta TODO este archivo en Supabase → SQL Editor.
-- Es idempotente: puedes volver a ejecutarlo sin romper nada.
--
-- QUÉ CAMBIA
-- ----------
-- Antes: la notificación de Yape dejaba el cobro en VALIDADO_NOTIF y el admin
--        tenía que escribir saldo anterior y saldo nuevo para pasarlo a PAGADO.
-- Ahora: la notificación de Yape con el monto exacto marca el cobro como
--        PAGADO automáticamente. No se escribe ningún saldo.
--
--        El cobro manual queda solo como respaldo (un toque, sin saldos) por si
--        el teléfono no recibe la notificación.
--
-- Requiere haber ejecutado antes:
--   1. supabase/cobros_yape_qr.sql
--   2. supabase/parche_cobros_qr.sql
-- ==============================================================================

-- ==============================================================================
-- 1. COLUMNAS DE AUDITORÍA
-- ==============================================================================
alter table public.pagos_qr
    add column if not exists origen_confirmacion text;
alter table public.pagos_qr
    add column if not exists confirmado_automaticamente boolean not null default false;
alter table public.pagos_qr
    add column if not exists pagado_en timestamptz;

comment on column public.pagos_qr.origen_confirmacion is
    'NOTIFICACION = lo confirmó el listener de Yape; ADMIN = lo confirmó el admin a mano.';
comment on column public.pagos_qr.confirmado_automaticamente is
    'true cuando el pago se completó solo con la notificación de Yape.';

-- ==============================================================================
-- 2. RPC PRINCIPAL: LA NOTIFICACIÓN MARCA EL COBRO COMO PAGADO
-- ==============================================================================
-- Atómica y a prueba de duplicados:
--   * Si el hash ya existe, devuelve el cobro que ya se había pagado (no falla).
--   * Si no hay escucha activa o no hay un cobro del monto exacto, devuelve NULL.
--   * Toma el cobro más antiguo que coincida, con FOR UPDATE SKIP LOCKED.
create or replace function public.validar_pago_por_notificacion(
    p_monto numeric,
    p_titulo text default null,
    p_texto text default null,
    p_hash text default null
)
returns public.pagos_qr
language plpgsql
security definer
set search_path = public
as $$
declare
    v_row public.pagos_qr;
    v_id uuid;
begin
    if auth.uid() is null then
        raise exception 'Sesión requerida para validar un pago.';
    end if;

    if public.es_admin() is not true then
        raise exception 'Solo el administrador puede validar pagos con notificaciones.';
    end if;

    if p_monto is null or p_monto <= 0 then
        raise exception 'Monto inválido para validar el pago.';
    end if;

    -- Idempotencia: Yape puede repetir la misma notificación.
    if p_hash is not null and length(p_hash) > 0 then
        select * into v_row
          from public.pagos_qr
         where evento_hash = p_hash
         limit 1;

        if v_row.id is not null then
            return v_row;
        end if;
    end if;

    -- La escucha solo está activa cuando existe un cobro PENDIENTE vigente.
    if not exists (
        select 1
          from public.configuracion_cobros
         where id = 1
           and escucha_activa
    ) then
        return null;
    end if;

    select id into v_id
      from public.pagos_qr
     where estado = 'PENDIENTE'
       and expira_en > now()
       and abs(monto_esperado - p_monto) < 0.01
     order by creado_en asc
     limit 1
     for update skip locked;

    if v_id is null then
        return null;
    end if;

    update public.pagos_qr
       set estado = 'PAGADO',
           monto_recibido = p_monto,
           pagado_por = nullif(left(coalesce(p_titulo, ''), 200), ''),
           notificacion_texto = nullif(left(coalesce(p_texto, ''), 500), ''),
           evento_hash = nullif(p_hash, ''),
           pagado_en = now(),
           origen_confirmacion = 'NOTIFICACION',
           confirmado_automaticamente = true
     where id = v_id
     returning * into v_row;

    return v_row;
end;
$$;

grant execute on function public.validar_pago_por_notificacion(numeric, text, text, text)
    to authenticated;

-- ==============================================================================
-- 3. CONFIRMACIÓN MANUAL (RESPALDO, UN SOLO TOQUE, SIN SALDOS)
-- ==============================================================================
-- Se conserva por si el teléfono no recibe la notificación de Yape.
-- Los saldos son opcionales: si no se envían, solo se marca el pago.
drop function if exists public.confirmar_pago_qr(uuid, numeric, numeric);

create or replace function public.confirmar_pago_qr(
    p_pago_id uuid,
    p_saldo_anterior numeric default null,
    p_saldo_nuevo numeric default null
)
returns public.pagos_qr
language plpgsql
security definer
set search_path = public
as $$
declare
    v_row public.pagos_qr;
    v_diferencia numeric(12, 2);
begin
    if public.es_admin() is not true then
        raise exception 'Solo el administrador puede confirmar el pago.';
    end if;

    select * into v_row
      from public.pagos_qr
     where id = p_pago_id
     for update;

    if v_row.id is null then
        raise exception 'El cobro no existe.';
    end if;

    -- Idempotente: si ya estaba pagado, no es un error.
    if v_row.estado = 'PAGADO' then
        return v_row;
    end if;

    if v_row.estado not in ('PENDIENTE', 'VALIDADO_NOTIF') then
        raise exception 'El cobro ya fue procesado (estado: %).', v_row.estado;
    end if;

    -- Auditoría opcional: si el admin sí ingresa saldos, se valida la diferencia.
    if p_saldo_anterior is not null and p_saldo_nuevo is not null then
        v_diferencia := round(p_saldo_nuevo - p_saldo_anterior, 2);

        if abs(v_diferencia - v_row.monto_esperado) > 0.01 then
            raise exception
                'El incremento de saldo (Bs. %) no coincide con el monto del cobro (Bs. %).',
                v_diferencia, v_row.monto_esperado;
        end if;
    end if;

    update public.pagos_qr
       set estado = 'PAGADO',
           saldo_anterior = p_saldo_anterior,
           saldo_nuevo = p_saldo_nuevo,
           validado_por_admin = auth.uid(),
           pagado_en = coalesce(pagado_en, now()),
           origen_confirmacion = 'ADMIN',
           confirmado_automaticamente = false
     where id = p_pago_id
     returning * into v_row;

    return v_row;
end;
$$;

grant execute on function public.confirmar_pago_qr(uuid, numeric, numeric)
    to authenticated;

-- ==============================================================================
-- 4. TRIGGER: IMPACTAR PEDIDO / RESERVA (estado correcto en minúsculas)
-- ==============================================================================
create or replace function public.fn_on_pago_qr_confirmado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.estado = 'PAGADO' and (old.estado is distinct from 'PAGADO') then
        if new.id_pedido is not null then
            update public.pedidos
               set estado = 'Pagado',
                   updated_at = now()
             where id = new.id_pedido;
        end if;

        if new.id_reserva is not null then
            update public.reservas
               set estado = 'aceptada'
             where id = new.id_reserva;
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_pago_qr_confirmado on public.pagos_qr;
create trigger trg_pago_qr_confirmado
after update of estado on public.pagos_qr
for each row
execute function public.fn_on_pago_qr_confirmado();

-- ==============================================================================
-- 5. COBROS QUE QUEDARON COLGADOS EN VALIDADO_NOTIF
-- ==============================================================================
-- Con la regla nueva, "notificación detectada" equivale a "pago completado".
-- Así que los cobros viejos en VALIDADO_NOTIF se cierran ahora.
update public.pagos_qr
   set estado = 'PAGADO',
       pagado_en = coalesce(pagado_en, now()),
       origen_confirmacion = coalesce(origen_confirmacion, 'NOTIFICACION'),
       confirmado_automaticamente = true
 where estado = 'VALIDADO_NOTIF';

-- ==============================================================================
-- 6. REALTIME: QUE CLIENTE Y ADMIN SE ENTEREN SIN REFRESCAR
-- ==============================================================================
alter table public.pagos_qr replica identity full;

do $$
begin
    if not exists (
        select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'pagos_qr'
    ) then
        alter publication supabase_realtime add table public.pagos_qr;
    end if;

    if not exists (
        select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'pedidos'
    ) then
        alter publication supabase_realtime add table public.pedidos;
    end if;
end $$;

-- ==============================================================================
-- 7. VERIFICACIÓN RÁPIDA
-- ==============================================================================
-- Debe devolver una fila con la función nueva y sus argumentos.
select p.proname,
       pg_get_function_arguments(p.oid) as argumentos
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('validar_pago_por_notificacion', 'confirmar_pago_qr')
 order by p.proname;

-- Debe devolver false (sin sesión).
select public.es_admin() as es_admin_sin_sesion;
