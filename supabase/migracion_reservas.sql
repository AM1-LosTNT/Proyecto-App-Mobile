-- ==============================================================================
-- TURISAPP · MIGRACIÓN: SISTEMA DE RESERVAS CON ESTADOS
-- Ejecuta este script UNA vez en el SQL Editor de Supabase.
-- Es idempotente: puedes volver a ejecutarlo sin romper datos existentes.
--
-- Cambios:
--   1. Añade columna hora_reserva (separada de fecha_reserva)
--   2. Añade columna motivo_rechazo (texto libre para el dueño del negocio)
--   3. Actualiza el CHECK de la columna estado para incluir los nuevos valores:
--        'pendiente', 'aceptada', 'rechazada', 'completada', 'cancelada'
--   4. Migra datos antiguos al nuevo formato (Pendiente → pendiente, etc.)
--   5. Añade índices para consultas frecuentes
--   6. Actualiza las políticas RLS para que el dueño pueda aceptar/rechazar
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Nueva columna: hora_reserva
-- Separa la hora de fecha_reserva para consultas y ordenamiento más limpio.
-- ------------------------------------------------------------------------------
ALTER TABLE public.reservas
    ADD COLUMN IF NOT EXISTS hora_reserva TEXT DEFAULT '';

-- Si hay reservas viejas que guardaban la hora dentro de fecha_reserva (como
-- '2026-12-01T14:30:00'), extraemos la hora a la nueva columna.
UPDATE public.reservas
SET hora_reserva = SUBSTRING(fecha_reserva FROM 'T(\d{2}:\d{2})'),
    fecha_reserva = SPLIT_PART(fecha_reserva, 'T', 1)
WHERE fecha_reserva LIKE '%T%'
  AND (hora_reserva IS NULL OR hora_reserva = '');

-- ------------------------------------------------------------------------------
-- 2. Nueva columna: motivo_rechazo
-- El dueño del negocio puede explicar al turista por qué rechazó la solicitud.
-- ------------------------------------------------------------------------------
ALTER TABLE public.reservas
    ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT DEFAULT '';

-- ------------------------------------------------------------------------------
-- 3. Migrar valores de estado al nuevo formato en minúsculas
-- Los valores anteriores eran: 'Pendiente', 'Confirmada', 'Cancelada', 'Completada'
-- Los nuevos son:             'pendiente', 'aceptada',  'cancelada', 'completada', 'rechazada'
-- ------------------------------------------------------------------------------
-- Primero quitamos el CHECK antiguo (si existe)
DO $$
BEGIN
    -- Buscar y eliminar cualquier constraint CHECK sobre la columna 'estado'
    PERFORM 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.check_constraints cc
        ON tc.constraint_name = cc.constraint_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'reservas'
      AND tc.constraint_type = 'CHECK'
      AND cc.check_clause ILIKE '%estado%';

    IF FOUND THEN
        EXECUTE (
            SELECT 'ALTER TABLE public.reservas DROP CONSTRAINT ' || tc.constraint_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.check_constraints cc
                ON tc.constraint_name = cc.constraint_name
            WHERE tc.table_schema = 'public'
              AND tc.table_name = 'reservas'
              AND tc.constraint_type = 'CHECK'
              AND cc.check_clause ILIKE '%estado%'
            LIMIT 1
        );
    END IF;
END
$$;

-- Migrar valores viejos
UPDATE public.reservas SET estado = 'pendiente'  WHERE estado IN ('Pendiente', 'En espera', 'pending');
UPDATE public.reservas SET estado = 'aceptada'   WHERE estado IN ('Confirmada', 'Aceptada', 'accepted', 'confirmed');
UPDATE public.reservas SET estado = 'rechazada'  WHERE estado IN ('Rechazada', 'rejected');
UPDATE public.reservas SET estado = 'completada' WHERE estado IN ('Completada', 'completed');
UPDATE public.reservas SET estado = 'cancelada'  WHERE estado IN ('Cancelada', 'cancelled', 'canceled');

-- Poner el default en 'pendiente' (no directo a 'confirmada')
ALTER TABLE public.reservas
    ALTER COLUMN estado SET DEFAULT 'pendiente';

-- Crear el nuevo CHECK
ALTER TABLE public.reservas
    ADD CONSTRAINT reservas_estado_check
    CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'completada', 'cancelada'));

-- ------------------------------------------------------------------------------
-- 4. Índices de rendimiento
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_reservas_turista
    ON public.reservas (id_turista);

CREATE INDEX IF NOT EXISTS idx_reservas_destino
    ON public.reservas (id_destino);

CREATE INDEX IF NOT EXISTS idx_reservas_estado
    ON public.reservas (estado);

CREATE INDEX IF NOT EXISTS idx_reservas_fecha
    ON public.reservas (fecha_reserva);

-- ------------------------------------------------------------------------------
-- 5. Políticas RLS actualizadas (sobrescriben las de actualizacion_completa.sql)
-- Ahora el turista también puede cancelar su propia reserva (UPDATE).
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Ver reservas propias o de locales administrados" ON public.reservas;
DROP POLICY IF EXISTS "Ver reservas propias, del negocio o admin" ON public.reservas;
DROP POLICY IF EXISTS "Turistas pueden crear reservas" ON public.reservas;
DROP POLICY IF EXISTS "Dueños actualizan reservas de sus locales" ON public.reservas;
DROP POLICY IF EXISTS "Admin actualiza reservas" ON public.reservas;
DROP POLICY IF EXISTS "Admin elimina reservas" ON public.reservas;
DROP POLICY IF EXISTS "Turista elimina su reserva" ON public.reservas;
DROP POLICY IF EXISTS "Turista cancela su reserva" ON public.reservas;

-- SELECT: turista ve las suyas, negocio ve las de sus locales, admin ve todas
CREATE POLICY "Ver reservas propias, del negocio o admin"
    ON public.reservas FOR SELECT
    USING (
        auth.uid() = id_turista
        OR public.es_admin()
        OR EXISTS (
            SELECT 1
            FROM public.destinos_lugares d
            WHERE d.id = reservas.id_destino
              AND d.id_usuario = auth.uid()
        )
    );

-- INSERT: solo el turista crea su reserva
CREATE POLICY "Turistas pueden crear reservas"
    ON public.reservas FOR INSERT
    WITH CHECK (auth.uid() = id_turista);

-- UPDATE (turista): puede cancelar sus propias reservas
CREATE POLICY "Turista cancela su reserva"
    ON public.reservas FOR UPDATE
    USING (auth.uid() = id_turista)
    WITH CHECK (auth.uid() = id_turista);

-- UPDATE (negocio): acepta, rechaza o completa reservas de sus locales
CREATE POLICY "Dueños actualizan reservas de sus locales"
    ON public.reservas FOR UPDATE
    USING (
        EXISTS (
            SELECT 1
            FROM public.destinos_lugares d
            WHERE d.id = reservas.id_destino
              AND d.id_usuario = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.destinos_lugares d
            WHERE d.id = reservas.id_destino
              AND d.id_usuario = auth.uid()
        )
    );

-- UPDATE (admin): puede cambiar cualquier reserva
CREATE POLICY "Admin actualiza reservas"
    ON public.reservas FOR UPDATE
    USING (public.es_admin())
    WITH CHECK (public.es_admin());

-- DELETE (admin): puede eliminar cualquier reserva
CREATE POLICY "Admin elimina reservas"
    ON public.reservas FOR DELETE
    USING (public.es_admin());

-- DELETE (turista): puede borrar sus propias reservas
CREATE POLICY "Turista elimina su reserva"
    ON public.reservas FOR DELETE
    USING (auth.uid() = id_turista);

-- ==============================================================================
-- FIN DE LA MIGRACIÓN DE RESERVAS
-- ==============================================================================
