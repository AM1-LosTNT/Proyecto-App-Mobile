-- ==============================================================================
-- TURISAPP · PAGO AUTOMÁTICO POR NOTIFICACIÓN  (SCRIPT DEFINITIVO)
-- ==============================================================================
-- Ejecuta TODO este archivo en Supabase → SQL Editor.
-- Es idempotente: puedes volver a ejecutarlo las veces que quieras.
--
-- REGLA DE NEGOCIO (la que pediste):
--   Cuando llega una notificación de Yape/Banca cuyo MONTO coincide con un
--   cobro PENDIENTE vigente, ese cobro pasa DIRECTO a PAGADO.
--   No se escribe saldo anterior ni saldo nuevo. No hay confirmación manual.
--
--   El nombre del cliente se usa SOLO como desempate si hay dos cobros
--   pendientes del mismo monto. Nunca bloquea un pago.
--
-- ESTE SCRIPT REEMPLAZA A:
--   - supabase/pago_automatico.sql (versión anterior)
--   - supabase/validador_yape_nombre_monto.sql (exigía nombre y monto, y
--     bloqueaba los pagos hechos desde una cuenta Yape con otro nombre)
-- ==============================================================================

-- ==============================================================================
-- 1. COLUMNAS NECESARIAS
-- ==============================================================================
alter table public.pagos_qr
    add column if not exists usuario_nombre text;
alter table public.pagos_qr
    add column if not exists origen_confirmacion text;
alter table public.pagos_qr
    add column if not exists confirmado_automaticamente boolean not null default false;
alter table public.pagos_qr
    add column if not exists pagado_en timestamptz;

comment on column public.pagos_qr.usuario_nombre is
    'Nombre del cliente que generó el cobro. Solo informativo/desempate.';
comment on column public.pagos_qr.origen_confirmacion is
    'NOTIFICACION = lo confirmó el listener de Yape; ADMIN = lo confirmó el admin a mano.';
comment on column public.pagos_qr.confirmado_automaticamente is
    'true cuando el pago se completó solo con la notificación de Yape.';

-- Rellena el nombre de los cobros antiguos que no lo tengan.
update public.pagos_qr p
   set usuario_nombre = u.nombre
  from public.usuarios u
 where p.usuario_id = u.id
   and p.usuario_nombre is null;

-- ==============================================================================
-- 2. NORMALIZACIÓN DE TEXTO (para el desempate por nombre)
-- ==============================================================================
create or replace function public.normalizar_texto(p_input text)
returns text
language plpgsql
immutable
as $$
declare
    v_res text;
begin
    if p_input is null then
        return '';
    end if;

    v_res := lower(p_input);
    v_res := replace(v_res, 'á', 'a');
    v_res := replace(v_res, 'é', 'e');
    v_res := replace(v_res, 'í', 'i');
    v_res := replace(v_res, 'ó', 'o');
    v_res := replace(v_res, 'ú', 'u');
    v_res := replace(v_res, 'ü', 'u');
    v_res := replace(v_res, 'ñ', 'n');
    v_res := regexp_replace(v_res, '[^a-z0-9]+', ' ', 'g');
    return trim(v_res);
end;
$$;

create or replace function public.coincide_nombre_yape(
    p_nombre_usuario text,
    p_titulo text,
    p_texto text
)
returns boolean
language plpgsql
immutable
as $$
declare
    v_tokens text[];
    v_token text;
    v_hay_tokens boolean := false;
    v_norm_notif text;
begin
    if p_nombre_usuario is null or trim(p_nombre_usuario) = '' then
        return false;
    end if;

    v_norm_notif := ' ' || public.normalizar_texto(
        coalesce(p_titulo, '') || ' ' || coalesce(p_texto, '')
    ) || ' ';
    v_tokens := string_to_array(public.normalizar_texto(p_nombre_usuario), ' ');

    foreach v_token in array v_tokens loop
        if length(v_token) >= 3 then
            v_hay_tokens := true;
            if position(v_token in v_norm_notif) > 0 then
                return true;
            end if;
        end if;
    end loop;

    if not v_hay_tokens then
        return false;
    end if;

    return false;
end;
$$;

-- ==============================================================================
-- 3. CREAR COBRO (un solo overload, con nombre automático)
-- ==============================================================================
drop function if exists public.crear_cobro_qr(numeric, text, text, text);
drop function if exists public.crear_cobro_qr(numeric, text, text, text, text);

create or replace function public.crear_cobro_qr(
    p_monto numeric,
    p_id_pedido text default null,
    p_id_reserva text default null,
    p_glosa text default null,
    p_usuario_nombre text default null
)
returns public.pagos_qr
language plpgsql
security definer
set search_path = public
as $$
declare
    v_row public.pagos_qr;
    v_ref text;
    v_nombre text;
begin
    if auth.uid() is null then
        raise exception 'Debes iniciar sesión para generar un cobro.';
    end if;

    if p_monto is null or p_monto <= 0 then
        raise exception 'El monto del cobro debe ser mayor a 0.';
    end if;

    select nombre into v_nombre
      from public.usuarios
     where id = auth.uid();

    if v_nombre is null or trim(v_nombre) = '' then
        v_nombre := coalesce(
            nullif(trim(p_usuario_nombre), ''),
            auth.jwt() -> 'user_metadata' ->> 'nombre',
            'Usuario'
        );
    end if;

    update public.pagos_qr
       set estado = 'RECHAZADO'
     where usuario_id = auth.uid()
       and estado = 'PENDIENTE'
       and id_pedido is not distinct from p_id_pedido
       and id_reserva is not distinct from p_id_reserva;

    v_ref := 'PAY-' || to_char(now(), 'YYMMDDHH24MISS')
             || '-' || upper(substr(md5(random()::text), 1, 4));

    insert into public.pagos_qr (
        usuario_id, usuario_nombre, id_pedido, id_reserva,
        referencia_interna, monto_esperado, glosa, estado
    )
    values (
        auth.uid(), v_nombre, p_id_pedido, p_id_reserva,
        v_ref, p_monto,
        coalesce(nullif(trim(p_glosa), ''), 'Pago en TurisApp'),
        'PENDIENTE'
    )
    returning * into v_row;

    return v_row;
end;
$$;

grant execute on function public.crear_cobro_qr(numeric, text, text, text, text)
    to authenticated;

-- ==============================================================================
-- 4. VALIDAR PAGO POR NOTIFICACIÓN → PAGADO (regla: MONTO)
-- ==============================================================================
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
        select 1 from public.configuracion_cobros
         where id = 1 and escucha_activa
    ) then
        return null;
    end if;

    -- Intento 1: mismo monto y nombre coincidente (solo desempate).
    select id into v_id
      from public.pagos_qr
     where estado = 'PENDIENTE'
       and expira_en > now()
       and abs(monto_esperado - p_monto) < 0.01
       and usuario_nombre is not null
       and public.coincide_nombre_yape(usuario_nombre, p_titulo, p_texto)
     order by creado_en asc
     limit 1
     for update skip locked;

    -- Intento 2: REGLA PRINCIPAL — solo por monto exacto.
    if v_id is null then
        select id into v_id
          from public.pagos_qr
         where estado = 'PENDIENTE'
           and expira_en > now()
           and abs(monto_esperado - p_monto) < 0.01
         order by creado_en asc
         limit 1
         for update skip locked;
    end if;

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
-- 5. CONFIRMACIÓN MANUAL (RESPALDO, UN TOQUE, SIN SALDOS)
-- ==============================================================================
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

    if v_row.estado = 'PAGADO' then
        return v_row;
    end if;

    if v_row.estado not in ('PENDIENTE', 'VALIDADO_NOTIF') then
        raise exception 'El cobro ya fue procesado (estado: %).', v_row.estado;
    end if;

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
-- 6. TRIGGER: PEDIDO / RESERVA
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
-- 7. COBROS COLGADOS EN VALIDADO_NOTIF → PAGADO
-- ==============================================================================
update public.pagos_qr
   set estado = 'PAGADO',
       pagado_en = coalesce(pagado_en, now()),
       origen_confirmacion = coalesce(origen_confirmacion, 'NOTIFICACION'),
       confirmado_automaticamente = true
 where estado = 'VALIDADO_NOTIF';

-- ==============================================================================
-- 8. REALTIME (cliente y admin sin refrescar)
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
-- 9. VERIFICACIÓN
-- ==============================================================================
select p.proname,
       pg_get_function_arguments(p.oid) as argumentos
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in (
       'crear_cobro_qr',
       'validar_pago_por_notificacion',
       'confirmar_pago_qr'
   )
 order by p.proname;

select public.es_admin() as es_admin_sin_sesion;
