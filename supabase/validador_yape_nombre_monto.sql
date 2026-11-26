-- ==============================================================================
-- ⚠️  OBSOLETO — NO EJECUTAR ESTE ARCHIVO
-- ==============================================================================
-- Este script exigía que coincidieran MONTO + NOMBRE del cliente. Eso bloquea
-- los pagos hechos desde una cuenta Yape con otro nombre (por ejemplo, un
-- familiar) y fue la causa de que el pago no se validara.
--
-- La versión vigente y correcta es:
--     supabase/pago_automatico.sql
--
-- Se conserva solo como referencia histórica.
-- ==============================================================================

-- ==============================================================================
-- TURISAPP · VALIDACIÓN DE PAGO POR NOTIFICACIÓN: NOMBRE + MONTO
-- ==============================================================================
-- Ejecuta este script en Supabase → SQL Editor.
-- Es seguro e idempotente.
--
-- QUÉ HACE ESTE SCRIPT:
-- 1. Agrega la columna `usuario_nombre` a `public.pagos_qr` para saber a qué
--    cliente (turista, negocio o admin) le pertenece el cobro.
-- 2. Llena automáticamente `usuario_nombre` de los cobros existentes.
-- 3. Crea funciones de texto para comparar sin importar tildes, mayúsculas o puntuación.
-- 4. Modifica `crear_cobro_qr` para asociar automáticamente el nombre del usuario
--    registrado al momento de crear el cobro.
-- 5. Actualiza `validar_pago_por_notificacion` para que SOLO valide el pago
--    cuando coincidan SIMULTÁNEAMENTE el MONTO y el NOMBRE del cliente en la
--    notificación de Yape.
-- ==============================================================================

-- 1. Agregar columna usuario_nombre a pagos_qr si no existe
alter table public.pagos_qr
    add column if not exists usuario_nombre text;

comment on column public.pagos_qr.usuario_nombre is
    'Nombre completo del usuario (turista, negocio o admin) que realiza el pago.';

-- 2. Llenar registros anteriores con los nombres de public.usuarios
update public.pagos_qr p
   set usuario_nombre = u.nombre
  from public.usuarios u
 where p.usuario_id = u.id
   and p.usuario_nombre is null;

-- 3. Función auxiliar para normalizar cadenas: quita tildes, pasa a minúsculas y filtra signos
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
    -- Reemplaza cualquier carácter no alfanumérico por un espacio
    v_res := regexp_replace(v_res, '[^a-z0-9]+', ' ', 'g');
    return trim(v_res);
end;
$$;

-- 4. Función de coincidencia inteligente de nombre en la notificación
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
    v_hay_coincidencia boolean := false;
    v_hay_tokens boolean := false;
    v_norm_notif text;
begin
    if p_nombre_usuario is null or trim(p_nombre_usuario) = '' then
        -- Si por alguna razón no hay nombre guardado, no bloqueamos la validación
        return true;
    end if;

    v_norm_notif := ' ' || public.normalizar_texto(coalesce(p_titulo, '') || ' ' || coalesce(p_texto, '')) || ' ';
    v_tokens := string_to_array(public.normalizar_texto(p_nombre_usuario), ' ');

    foreach v_token in array v_tokens loop
        -- Ignorar palabras demasiado cortas o conectores (de, la, el, etc.)
        if length(v_token) >= 3 then
            v_hay_tokens := true;
            if position(' ' || v_token || ' ' in v_norm_notif) > 0 
               or position(v_token in v_norm_notif) > 0 then
                v_hay_coincidencia := true;
                exit;
            end if;
        end if;
    end loop;

    if not v_hay_tokens then
        return true;
    end if;

    return v_hay_coincidencia;
end;
$$;

-- 5. Actualizar función crear_cobro_qr para guardar el usuario_nombre
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

    -- Extraer el nombre de la tabla de usuarios (soporta turista, negocio y admin)
    select nombre into v_nombre
      from public.usuarios
     where id = auth.uid();

    if v_nombre is null or trim(v_nombre) = '' then
        v_nombre := coalesce(nullif(trim(p_usuario_nombre), ''), auth.jwt() -> 'user_metadata' ->> 'nombre', 'Usuario');
    end if;

    -- Cancelar cobros pendientes anteriores del mismo pedido o reserva
    update public.pagos_qr
       set estado = 'RECHAZADO'
     where usuario_id = auth.uid()
       and estado = 'PENDIENTE'
       and id_pedido is not distinct from p_id_pedido
       and id_reserva is not distinct from p_id_reserva;

    v_ref := 'PAY-' || to_char(now(), 'YYMMDDHH24MISS')
             || '-' || upper(substr(md5(random()::text), 1, 4));

    insert into public.pagos_qr (
        usuario_id,
        usuario_nombre,
        id_pedido,
        id_reserva,
        referencia_interna,
        monto_esperado,
        glosa,
        estado
    )
    values (
        auth.uid(),
        v_nombre,
        p_id_pedido,
        p_id_reserva,
        v_ref,
        p_monto,
        coalesce(nullif(trim(p_glosa), ''), 'Pago en TurisApp'),
        'PENDIENTE'
    )
    returning * into v_row;

    return v_row;
end;
$$;

grant execute on function public.crear_cobro_qr(numeric, text, text, text, text) to authenticated;

-- 6. Actualizar validar_pago_por_notificacion: VALIDA NOMBRE Y MONTO
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

    -- Idempotencia: no reprocesar notificaciones idénticas
    if p_hash is not null and length(p_hash) > 0 then
        select * into v_row
          from public.pagos_qr
         where evento_hash = p_hash
         limit 1;

        if v_row.id is not null then
            return v_row;
        end if;
    end if;

    -- Verificar que la escucha esté activa
    if not exists (
        select 1
          from public.configuracion_cobros
         where id = 1
           and escucha_activa
    ) then
        return null;
    end if;

    -- Buscar cobro PENDIENTE que coincida en MONTO y en NOMBRE
    select id into v_id
      from public.pagos_qr
     where estado = 'PENDIENTE'
       and expira_en > now()
       and abs(monto_esperado - p_monto) < 0.01
       and (
           usuario_nombre is null
           or public.coincide_nombre_yape(usuario_nombre, p_titulo, p_texto)
       )
     order by creado_en asc
     limit 1
     for update skip locked;

    if v_id is null then
        return null;
    end if;

    -- Marcar como PAGADO automáticamente
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

grant execute on function public.validar_pago_por_notificacion(numeric, text, text, text) to authenticated;
