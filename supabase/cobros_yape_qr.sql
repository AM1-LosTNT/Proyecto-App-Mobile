-- ==============================================================================
-- TURISAPP · COBROS CON QR ESTÁTICO (Bs 0), ESCUCHA BAJO DEMANDA Y
-- AUDITORÍA DE AUMENTO DE SALDO (SOLO ADMIN)
-- ==============================================================================
-- Ejecuta TODO este archivo en Supabase → SQL Editor.
-- Es idempotente: puedes volver a ejecutarlo sin romper nada.
-- ==============================================================================

-- 0. EXTENSIONES NECESARIAS
create extension if not exists pgcrypto;

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================
create table if not exists public.pagos_qr (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid references auth.users(id) on delete set null,
    id_pedido text references public.pedidos(id) on delete set null,
    id_reserva text references public.reservas(id) on delete set null,
    referencia_interna text unique not null,
    monto_esperado numeric(12, 2) not null check (monto_esperado > 0),
    monto_recibido numeric(12, 2),
    moneda text not null default 'BOB',
    glosa text,
    estado text not null default 'PENDIENTE'
        check (estado in ('PENDIENTE', 'VALIDADO_NOTIF', 'PAGADO', 'EXPIRADO', 'RECHAZADO')),
    pagado_por text,
    notificacion_texto text,
    evento_hash text unique,
    saldo_anterior numeric(12, 2),
    saldo_nuevo numeric(12, 2),
    validado_por_admin uuid references auth.users(id) on delete set null,
    expira_en timestamptz not null default (now() + interval '10 minutes'),
    pagado_en timestamptz,
    creado_en timestamptz not null default now()
);

create table if not exists public.configuracion_cobros (
    id int primary key default 1 check (id = 1),
    escucha_activa boolean not null default false,
    qr_estatico_url text,
    titular_cuenta text default 'Christopher',
    banco_nombre text default 'Banco Unión / Yape',
    actualizado_en timestamptz not null default now()
);

-- Si ya existía una versión anterior de las tablas, completamos columnas faltantes.
alter table public.pagos_qr add column if not exists id_pedido text references public.pedidos(id) on delete set null;
alter table public.pagos_qr add column if not exists id_reserva text references public.reservas(id) on delete set null;
alter table public.pagos_qr add column if not exists monto_recibido numeric(12, 2);
alter table public.pagos_qr add column if not exists pagado_por text;
alter table public.pagos_qr add column if not exists notificacion_texto text;
alter table public.pagos_qr add column if not exists evento_hash text;
alter table public.pagos_qr add column if not exists saldo_anterior numeric(12, 2);
alter table public.pagos_qr add column if not exists saldo_nuevo numeric(12, 2);
alter table public.pagos_qr add column if not exists validado_por_admin uuid references auth.users(id) on delete set null;
alter table public.pagos_qr add column if not exists pagado_en timestamptz;
alter table public.configuracion_cobros add column if not exists qr_estatico_url text;
alter table public.configuracion_cobros add column if not exists titular_cuenta text default 'Christopher';
alter table public.configuracion_cobros add column if not exists banco_nombre text default 'Banco Unión / Yape';

insert into public.configuracion_cobros (id, escucha_activa, titular_cuenta, banco_nombre)
values (1, false, 'Christopher', 'Banco Unión / Yape')
on conflict (id) do nothing;

-- Índices para que las consultas del listener sean instantáneas.
create index if not exists idx_pagos_qr_estado_expira
    on public.pagos_qr (estado, expira_en);
create index if not exists idx_pagos_qr_usuario_creado
    on public.pagos_qr (usuario_id, creado_en desc);

-- ==============================================================================
-- 2. EXPIRACIÓN AUTOMÁTICA + CÁLCULO DE "ESCUCHA ACTIVA"
-- ==============================================================================
create or replace function public.expirar_cobros_vencidos()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count integer := 0;
begin
    update public.pagos_qr
       set estado = 'EXPIRADO'
     where estado = 'PENDIENTE'
       and expira_en <= now();
    get diagnostics v_count = row_count;

    update public.configuracion_cobros
       set escucha_activa = exists (
               select 1 from public.pagos_qr
                where estado = 'PENDIENTE' and expira_en > now()
           ),
           actualizado_en = now()
     where id = 1;

    return v_count;
end;
$$;

-- Trigger por sentencia. El guard con pg_trigger_depth() evita la recursión
-- infinita que tenía el script original (el UPDATE de expiración vuelve a
-- disparar el trigger sobre la misma tabla).
create or replace function public.recalcular_escucha()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if pg_trigger_depth() > 1 then
        return null;
    end if;

    perform public.expirar_cobros_vencidos();
    return null;
end;
$$;

drop trigger if exists trg_actualizar_escucha on public.pagos_qr;
create trigger trg_actualizar_escucha
after insert or update or delete on public.pagos_qr
for each statement
execute function public.recalcular_escucha();

-- Programar la expiración cada minuto (así la escucha se apaga sola aunque
-- nadie toque la tabla). Si pg_cron no está habilitado, el script sigue igual.
do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.unschedule(jobid)
           from cron.job
          where jobname = 'turisapp-expirar-cobros';

        perform cron.schedule(
            'turisapp-expirar-cobros',
            '* * * * *',
            'select public.expirar_cobros_vencidos();'
        );
        raise notice 'pg_cron programado: expiración de cobros cada minuto.';
    else
        raise notice 'pg_cron no está habilitado. Habilítalo en Database → Extensions para la expiración automática.';
    end if;
exception when others then
    raise notice 'No se pudo programar pg_cron: %', sqlerrm;
end $$;

-- ==============================================================================
-- 3. AL CONFIRMAR EL PAGO (PAGADO): IMPACTAR PEDIDO / RESERVA
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
-- 4. FUNCIONES SEGURAS (RPC) USADAS POR LA APP
-- ==============================================================================

-- 4.1 Crear un cobro. Cancela intentos previos pendientes del mismo pedido y
--     genera la referencia interna en el servidor (no confiamos en el cliente).
create or replace function public.crear_cobro_qr(
    p_monto numeric,
    p_id_pedido text default null,
    p_id_reserva text default null,
    p_glosa text default null
)
returns public.pagos_qr
language plpgsql
security definer
set search_path = public
as $$
declare
    v_row public.pagos_qr;
    v_ref text;
begin
    if auth.uid() is null then
        raise exception 'Debes iniciar sesión para generar un cobro.';
    end if;

    if p_monto is null or p_monto <= 0 then
        raise exception 'El monto del cobro debe ser mayor a 0.';
    end if;

    -- Un solo cobro pendiente a la vez por pedido/reserva (evita que un intento
    -- abandonado se robe la notificación del intento nuevo).
    update public.pagos_qr
       set estado = 'RECHAZADO'
     where usuario_id = auth.uid()
       and estado = 'PENDIENTE'
       and id_pedido is not distinct from p_id_pedido
       and id_reserva is not distinct from p_id_reserva;

    v_ref := 'PAY-' || to_char(now(), 'YYMMDDHH24MISS')
             || '-' || upper(substr(md5(random()::text), 1, 4));

    insert into public.pagos_qr (
        usuario_id, id_pedido, id_reserva, referencia_interna,
        monto_esperado, glosa, estado
    )
    values (
        auth.uid(), p_id_pedido, p_id_reserva, v_ref,
        p_monto, coalesce(nullif(trim(p_glosa), ''), 'Pago en TurisApp'), 'PENDIENTE'
    )
    returning * into v_row;

    return v_row;
end;
$$;

grant execute on function public.crear_cobro_qr(numeric, text, text, text) to authenticated;

-- 4.2 Confirmar el aumento de saldo. SOLO admin. Exige que la diferencia entre
--     el saldo nuevo y el anterior coincida con el monto del cobro.
create or replace function public.confirmar_pago_qr(
    p_pago_id uuid,
    p_saldo_anterior numeric,
    p_saldo_nuevo numeric
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
        raise exception 'Solo el administrador puede confirmar el aumento de saldo.';
    end if;

    select * into v_row
      from public.pagos_qr
     where id = p_pago_id
     for update;

    if not found then
        raise exception 'El cobro no existe.';
    end if;

    if v_row.estado not in ('PENDIENTE', 'VALIDADO_NOTIF') then
        raise exception 'El cobro ya fue procesado (estado: %).', v_row.estado;
    end if;

    if p_saldo_anterior is null or p_saldo_nuevo is null then
        raise exception 'Debes registrar el saldo anterior y el saldo nuevo.';
    end if;

    v_diferencia := round(p_saldo_nuevo - p_saldo_anterior, 2);

    if abs(v_diferencia - v_row.monto_esperado) > 0.01 then
        raise exception
            'El incremento de saldo (Bs. %) no coincide con el monto del cobro (Bs. %).',
            v_diferencia, v_row.monto_esperado;
    end if;

    update public.pagos_qr
       set estado = 'PAGADO',
           saldo_anterior = p_saldo_anterior,
           saldo_nuevo = p_saldo_nuevo,
           validado_por_admin = auth.uid(),
           pagado_en = coalesce(pagado_en, now())
     where id = p_pago_id
     returning * into v_row;

    return v_row;
end;
$$;

grant execute on function public.confirmar_pago_qr(uuid, numeric, numeric) to authenticated;

-- 4.3 Helper para saber si el usuario autenticado es admin.
create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        exists (
            select 1 from public.usuarios
            where id = auth.uid() and rol = 'admin'
        )
        or ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'),
        false
    );
$$;

grant execute on function public.es_admin() to authenticated;

-- ==============================================================================
-- 5. REALTIME (idempotente: no falla si la tabla ya estaba agregada)
-- ==============================================================================
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
           and tablename = 'configuracion_cobros'
    ) then
        alter publication supabase_realtime add table public.configuracion_cobros;
    end if;
end $$;

-- ==============================================================================
-- 6. SEGURIDAD (RLS)
-- ==============================================================================
alter table public.pagos_qr enable row level security;
alter table public.configuracion_cobros enable row level security;

-- 6.1 pagos_qr
drop policy if exists "Usuarios crean sus cobros" on public.pagos_qr;
create policy "Usuarios crean sus cobros"
on public.pagos_qr for insert
to authenticated
with check (auth.uid() = usuario_id);

drop policy if exists "Usuarios ven sus cobros y admin ve todos" on public.pagos_qr;
create policy "Usuarios ven sus cobros y admin ve todos"
on public.pagos_qr for select
to authenticated
using (
    auth.uid() = usuario_id
    or public.es_admin()
);

-- IMPORTANTE: un usuario normal NO puede actualizar sus propios cobros.
-- Así nadie puede marcarse un pago como PAGADO llamando a Supabase por fuera
-- de la app. El único que actualiza es el admin (o las RPC con security definer).
drop policy if exists "Admin y listener actualizan pagos" on public.pagos_qr;
drop policy if exists "Solo admin actualiza pagos" on public.pagos_qr;
create policy "Solo admin actualiza pagos"
on public.pagos_qr for update
to authenticated
using (public.es_admin())
with check (public.es_admin());

-- 6.2 configuracion_cobros
drop policy if exists "Usuarios leen configuracion_cobros" on public.configuracion_cobros;
create policy "Usuarios leen configuracion_cobros"
on public.configuracion_cobros for select
to authenticated
using (true);

drop policy if exists "Solo admin modifica configuracion_cobros" on public.configuracion_cobros;
create policy "Solo admin modifica configuracion_cobros"
on public.configuracion_cobros for update
to authenticated
using (public.es_admin())
with check (public.es_admin());

-- ==============================================================================
-- 7. PERMISOS DE TABLA
-- ==============================================================================
grant select, insert on public.pagos_qr to authenticated;
grant select on public.configuracion_cobros to authenticated;
grant update on public.configuracion_cobros to authenticated;

-- ==============================================================================
-- 8. STORAGE: BUCKETS PARA IMÁGENES (QR, PRODUCTOS, AVATARES, NEGOCIOS)
-- ==============================================================================
insert into storage.buckets (id, name, public)
values
    ('imagenes', 'imagenes', true),
    ('avatars', 'avatars', true),
    ('business-images', 'business-images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Lectura publica de imagenes" on storage.objects;
create policy "Lectura publica de imagenes"
on storage.objects for select
using (bucket_id in ('imagenes', 'avatars', 'business-images'));

drop policy if exists "Usuarios autenticados suben imagenes" on storage.objects;
create policy "Usuarios autenticados suben imagenes"
on storage.objects for insert
to authenticated
with check (bucket_id in ('imagenes', 'avatars', 'business-images'));

drop policy if exists "Usuarios autenticados actualizan imagenes" on storage.objects;
create policy "Usuarios autenticados actualizan imagenes"
on storage.objects for update
to authenticated
using (
    bucket_id in ('imagenes', 'avatars', 'business-images')
    and (owner = auth.uid() or public.es_admin())
)
with check (
    bucket_id in ('imagenes', 'avatars', 'business-images')
    and (owner = auth.uid() or public.es_admin())
);

drop policy if exists "Usuarios autenticados eliminan imagenes" on storage.objects;
create policy "Usuarios autenticados eliminan imagenes"
on storage.objects for delete
to authenticated
using (
    bucket_id in ('imagenes', 'avatars', 'business-images')
    and (owner = auth.uid() or public.es_admin())
);

-- ==============================================================================
-- 9. RECORDATORIO: DAR ROL ADMIN A TU CUENTA
-- ==============================================================================
-- Opción A (recomendada, una sola vez):
--   update public.usuarios set rol = 'admin' where email = 'tu_correo@ejemplo.com';
--
-- Opción B (metadata del JWT, requiere volver a iniciar sesión):
--   update auth.users
--      set raw_app_meta_data = raw_app_meta_data || '{"role":"admin"}'
--    where email = 'tu_correo@ejemplo.com';
-- ==============================================================================
