-- ==============================================================================
-- TURISAPP · PARCHE DE SEGURIDAD Y COMPATIBILIDAD PARA COBROS QR
-- ==============================================================================
-- Ejecuta TODO este archivo en Supabase → SQL Editor si ya habías ejecutado
-- `cobros_yape_qr.sql` antes del 24/11/2026.
--
-- Corrige tres cosas:
--   1. `es_admin()` devolvía NULL para anónimos y la comprobación `if not
--      es_admin()` se saltaba. Ahora siempre devuelve true/false.
--   2. `confirmar_pago_qr` usa `is not true`, así un usuario sin sesión no puede
--      confirmar pagos.
--   3. El trigger escribía `reservas.estado = 'Confirmada'`, pero la tabla usa
--      estados en minúsculas (`aceptada`). Eso hacía fallar la confirmación de
--      un pago asociado a una reserva por el CHECK constraint.
--
-- Es idempotente: puedes ejecutarlo varias veces.
-- ==============================================================================

-- 1) Helper de rol admin, a prueba de NULL
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

-- 2) Confirmación de saldo, solo para admin real
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

-- 3) Trigger de impacto en pedido / reserva con el estado correcto
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
-- Verificación rápida: debe devolver `false` (no NULL) sin sesión.
-- ==============================================================================
select public.es_admin() as es_admin_sin_sesion;
