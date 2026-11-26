-- ==============================================================================
-- TURISAPP · EL ADMIN PUEDE VER TODOS LOS PEDIDOS
-- ==============================================================================
-- Síntoma:
--   · El cliente ve su pedido en "Mis pedidos".
--   · El pedido existe en la tabla `pedidos`.
--   · Pero el panel admin muestra "Pedidos (0)".
--
-- Causa:
--   Las políticas RLS de `pedidos` y `detalle_pedidos` solo contemplaban al
--   dueño (`id_turista = auth.uid()`). Como el admin no es el dueño, Supabase
--   le devuelve 0 filas SIN error, y el panel se queda vacío.
--   La pestaña "Yape QR" sí funciona porque `pagos_qr` ya tiene `es_admin()`.
--
-- Este script es idempotente: se puede ejecutar varias veces sin problema.
-- No borra ni modifica pedidos; solo agrega permisos de lectura/edición al admin.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. Diagnóstico: mira qué políticas existen hoy
-- ------------------------------------------------------------------------------
select tablename, policyname, cmd, qual
  from pg_policies
 where schemaname = 'public'
   and tablename in ('pedidos', 'detalle_pedidos', 'pagos_historial')
 order by tablename, cmd, policyname;

-- ------------------------------------------------------------------------------
-- 1. Asegurar que RLS está activo (no cambia nada si ya lo está)
-- ------------------------------------------------------------------------------
alter table public.pedidos enable row level security;
alter table public.detalle_pedidos enable row level security;

-- ------------------------------------------------------------------------------
-- 2. Pedidos: el admin ve TODOS y puede cambiar el estado
-- ------------------------------------------------------------------------------
drop policy if exists "Admin ve todos los pedidos" on public.pedidos;
create policy "Admin ve todos los pedidos"
    on public.pedidos for select
    using (public.es_admin());

drop policy if exists "Admin actualiza pedidos" on public.pedidos;
create policy "Admin actualiza pedidos"
    on public.pedidos for update
    using (public.es_admin())
    with check (public.es_admin());

-- ------------------------------------------------------------------------------
-- 3. Detalle de pedidos: el admin ve todos los renglones
-- ------------------------------------------------------------------------------
drop policy if exists "Admin ve todos los detalles de pedidos"
    on public.detalle_pedidos;
create policy "Admin ve todos los detalles de pedidos"
    on public.detalle_pedidos for select
    using (public.es_admin());

-- ------------------------------------------------------------------------------
-- 4. Comprobantes (pagos_historial): el admin ve y actualiza todos
--    (la pestaña "Comprobantes" tenía el mismo problema)
-- ------------------------------------------------------------------------------
do $$
begin
    if to_regclass('public.pagos_historial') is not null then
        execute 'alter table public.pagos_historial enable row level security';

        execute 'drop policy if exists "Admin ve todos los comprobantes" on public.pagos_historial';
        execute 'create policy "Admin ve todos los comprobantes"
                   on public.pagos_historial for select
                   using (public.es_admin())';

        execute 'drop policy if exists "Admin actualiza comprobantes" on public.pagos_historial';
        execute 'create policy "Admin actualiza comprobantes"
                   on public.pagos_historial for update
                   using (public.es_admin())
                   with check (public.es_admin())';
    end if;
end $$;

-- ------------------------------------------------------------------------------
-- 5. Verificación
-- ------------------------------------------------------------------------------
select tablename, policyname, cmd
  from pg_policies
 where schemaname = 'public'
   and tablename in ('pedidos', 'detalle_pedidos', 'pagos_historial')
 order by tablename, cmd, policyname;

-- Recuerda: el SQL Editor corre sin sesión, así que `es_admin()` es false aquí.
-- La comprobación real se hace desde la app con tu cuenta admin:
--   Panel admin → Pedidos & Pagos → Pedidos  → debe listar el pedido.
