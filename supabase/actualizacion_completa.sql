-- ==============================================================================
-- TURISAPP · ACTUALIZACIÓN COMPLETA DE BASE DE DATOS
-- Ejecuta este script UNA vez en el SQL Editor de Supabase.
-- Es idempotente: puedes volver a ejecutarlo sin romper datos existentes.
--
-- Incluye:
--   · Perfil de negocio (portada)
--   · Una reseña por usuario y lugar + promedio de calificación automático
--   · Políticas de administrador sin recursión
--   · Reservas visibles para el dueño del negocio
--   · Buckets y políticas de Storage (avatars / business-images)
--   · Planificador de rutas en micro (directa y con transbordo)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. Extensiones
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------------------------
-- 1. Perfil de usuario / negocio
-- ------------------------------------------------------------------------------
ALTER TABLE public.usuarios
    ADD COLUMN IF NOT EXISTS portada_url TEXT;

ALTER TABLE public.usuarios
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ
    DEFAULT TIMEZONE('utc'::text, NOW());

UPDATE public.usuarios
SET updated_at = TIMEZONE('utc'::text, NOW())
WHERE updated_at IS NULL;

-- ------------------------------------------------------------------------------
-- 2. Reseñas: una sola opinión por usuario y lugar
-- ------------------------------------------------------------------------------
ALTER TABLE public.resenas
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ
    DEFAULT TIMEZONE('utc'::text, NOW());

-- Elimina opiniones duplicadas antiguas (conserva la más reciente de cada usuario).
DELETE FROM public.resenas r
USING public.resenas r2
WHERE r.id_destino = r2.id_destino
  AND r.id_usuario = r2.id_usuario
  AND r.id < r2.id;

-- Índice único requerido por el upsert de la app:
-- ON CONFLICT (id_destino, id_usuario)
CREATE UNIQUE INDEX IF NOT EXISTS resenas_destino_usuario_uidx
    ON public.resenas (id_destino, id_usuario);

CREATE INDEX IF NOT EXISTS idx_resenas_destino
    ON public.resenas (id_destino);

-- ------------------------------------------------------------------------------
-- 3. Recalcular rating y total_reviews de cada lugar automáticamente
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalcular_rating_destino()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_destino TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_destino := OLD.id_destino;
    ELSE
        v_destino := NEW.id_destino;
    END IF;

    UPDATE public.destinos_lugares d
    SET rating = COALESCE((
            SELECT ROUND(AVG(r.calificacion)::numeric, 1)
            FROM public.resenas r
            WHERE r.id_destino = v_destino
        ), 0),
        total_reviews = (
            SELECT COUNT(*)
            FROM public.resenas r
            WHERE r.id_destino = v_destino
        ),
        updated_at = TIMEZONE('utc'::text, NOW())
    WHERE d.id = v_destino;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_resenas_rating ON public.resenas;
CREATE TRIGGER trg_resenas_rating
    AFTER INSERT OR UPDATE OR DELETE ON public.resenas
    FOR EACH ROW EXECUTE FUNCTION public.recalcular_rating_destino();

-- Backfill: corrige promedios y conteos existentes.
UPDATE public.destinos_lugares d
SET rating = COALESCE(agg.promedio, 0),
    total_reviews = COALESCE(agg.total, 0)
FROM (
    SELECT id_destino,
           ROUND(AVG(calificacion)::numeric, 1) AS promedio,
           COUNT(*) AS total
    FROM public.resenas
    GROUP BY id_destino
) agg
WHERE d.id = agg.id_destino;

UPDATE public.destinos_lugares d
SET rating = 0, total_reviews = 0
WHERE NOT EXISTS (
    SELECT 1 FROM public.resenas r WHERE r.id_destino = d.id
);

-- ------------------------------------------------------------------------------
-- 4. Trigger de registro: guarda nombre, rol, teléfono y negocio
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.manejar_nuevo_usuario()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    rol_texto TEXT;
    rol_final TEXT;
BEGIN
    rol_texto := NEW.raw_user_meta_data->>'rol';

    IF rol_texto = 'admin' THEN
        rol_final := 'admin';
    ELSIF rol_texto = 'business' THEN
        rol_final := 'business';
    ELSE
        rol_final := 'user';
    END IF;

    INSERT INTO public.usuarios AS u (id, nombre, email, rol, nombre_negocio, telefono)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'nombre', ''), 'Usuario'),
        NEW.email,
        rol_final,
        NULLIF(NEW.raw_user_meta_data->>'nombre_negocio', ''),
        NULLIF(NEW.raw_user_meta_data->>'telefono', '')
    )
    ON CONFLICT (id) DO UPDATE
    SET nombre = COALESCE(NULLIF(u.nombre, ''), EXCLUDED.nombre),
        email = EXCLUDED.email,
        nombre_negocio = COALESCE(u.nombre_negocio, EXCLUDED.nombre_negocio),
        telefono = COALESCE(u.telefono, EXCLUDED.telefono),
        rol = CASE
            WHEN u.rol = 'admin' THEN 'admin'
            ELSE EXCLUDED.rol
        END,
        updated_at = TIMEZONE('utc'::text, NOW());

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.manejar_nuevo_usuario();

-- ------------------------------------------------------------------------------
-- 5. Función es_admin (SECURITY DEFINER evita recursión en las políticas RLS)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.es_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND u.rol = 'admin'
    );
$$;

GRANT EXECUTE ON FUNCTION public.es_admin() TO anon, authenticated;

-- ------------------------------------------------------------------------------
-- 6. Políticas RLS de usuarios
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Lectura de perfiles de usuario" ON public.usuarios;
DROP POLICY IF EXISTS "Usuarios gestionan su propio perfil" ON public.usuarios;
DROP POLICY IF EXISTS "Usuarios insertan su propio perfil" ON public.usuarios;
DROP POLICY IF EXISTS "Admin actualiza usuarios" ON public.usuarios;
DROP POLICY IF EXISTS "Admin elimina usuarios" ON public.usuarios;
DROP POLICY IF EXISTS "Admin inserta usuarios" ON public.usuarios;

CREATE POLICY "Lectura de perfiles de usuario"
    ON public.usuarios FOR SELECT
    USING (true);

CREATE POLICY "Usuarios insertan su propio perfil"
    ON public.usuarios FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Usuarios gestionan su propio perfil"
    ON public.usuarios FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Admin actualiza usuarios"
    ON public.usuarios FOR UPDATE
    USING (public.es_admin())
    WITH CHECK (public.es_admin());

CREATE POLICY "Admin elimina usuarios"
    ON public.usuarios FOR DELETE
    USING (public.es_admin());

CREATE POLICY "Admin inserta usuarios"
    ON public.usuarios FOR INSERT
    WITH CHECK (public.es_admin());

-- ------------------------------------------------------------------------------
-- 7. Políticas RLS de lugares (usa es_admin, sin subconsultas recursivas)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Lectura pública de destinos" ON public.destinos_lugares;
DROP POLICY IF EXISTS "Dueños y admin pueden crear lugares" ON public.destinos_lugares;
DROP POLICY IF EXISTS "Dueños y admin pueden actualizar sus lugares" ON public.destinos_lugares;
DROP POLICY IF EXISTS "Dueños y admin pueden eliminar sus lugares" ON public.destinos_lugares;

CREATE POLICY "Lectura pública de destinos"
    ON public.destinos_lugares FOR SELECT
    USING (activo = true OR auth.uid() = id_usuario OR public.es_admin());

CREATE POLICY "Dueños y admin pueden crear lugares"
    ON public.destinos_lugares FOR INSERT
    WITH CHECK (auth.uid() = id_usuario OR public.es_admin());

CREATE POLICY "Dueños y admin pueden actualizar sus lugares"
    ON public.destinos_lugares FOR UPDATE
    USING (auth.uid() = id_usuario OR public.es_admin())
    WITH CHECK (auth.uid() = id_usuario OR public.es_admin());

CREATE POLICY "Dueños y admin pueden eliminar sus lugares"
    ON public.destinos_lugares FOR DELETE
    USING (auth.uid() = id_usuario OR public.es_admin());

-- ------------------------------------------------------------------------------
-- 8. Políticas RLS de categorías (solo admin escribe)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Lectura pública de categorias" ON public.categorias;
DROP POLICY IF EXISTS "Admin crea categorias" ON public.categorias;
DROP POLICY IF EXISTS "Admin actualiza categorias" ON public.categorias;
DROP POLICY IF EXISTS "Admin elimina categorias" ON public.categorias;

CREATE POLICY "Lectura pública de categorias"
    ON public.categorias FOR SELECT
    USING (true);

CREATE POLICY "Admin crea categorias"
    ON public.categorias FOR INSERT
    WITH CHECK (public.es_admin());

CREATE POLICY "Admin actualiza categorias"
    ON public.categorias FOR UPDATE
    USING (public.es_admin())
    WITH CHECK (public.es_admin());

CREATE POLICY "Admin elimina categorias"
    ON public.categorias FOR DELETE
    USING (public.es_admin());

-- ------------------------------------------------------------------------------
-- 9. Reservas: turista, dueño del lugar y admin
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Ver reservas propias o de locales administrados" ON public.reservas;
DROP POLICY IF EXISTS "Ver reservas propias, del negocio o admin" ON public.reservas;
DROP POLICY IF EXISTS "Turistas pueden crear reservas" ON public.reservas;
DROP POLICY IF EXISTS "Dueños actualizan reservas de sus locales" ON public.reservas;
DROP POLICY IF EXISTS "Admin actualiza reservas" ON public.reservas;
DROP POLICY IF EXISTS "Admin elimina reservas" ON public.reservas;
DROP POLICY IF EXISTS "Turista elimina su reserva" ON public.reservas;

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

CREATE POLICY "Turistas pueden crear reservas"
    ON public.reservas FOR INSERT
    WITH CHECK (auth.uid() = id_turista);

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

CREATE POLICY "Admin actualiza reservas"
    ON public.reservas FOR UPDATE
    USING (public.es_admin())
    WITH CHECK (public.es_admin());

CREATE POLICY "Admin elimina reservas"
    ON public.reservas FOR DELETE
    USING (public.es_admin());

CREATE POLICY "Turista elimina su reserva"
    ON public.reservas FOR DELETE
    USING (auth.uid() = id_turista);

-- ------------------------------------------------------------------------------
-- 10. Reseñas: editar y eliminar la propia (o admin)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Lectura pública de reseñas" ON public.resenas;
DROP POLICY IF EXISTS "Usuarios registrados crean reseñas" ON public.resenas;
DROP POLICY IF EXISTS "Usuarios actualizan su reseña" ON public.resenas;
DROP POLICY IF EXISTS "Usuarios eliminan su reseña" ON public.resenas;
DROP POLICY IF EXISTS "Admin gestiona reseñas" ON public.resenas;

CREATE POLICY "Lectura pública de reseñas"
    ON public.resenas FOR SELECT
    USING (true);

CREATE POLICY "Usuarios registrados crean reseñas"
    ON public.resenas FOR INSERT
    WITH CHECK (auth.uid() = id_usuario);

CREATE POLICY "Usuarios actualizan su reseña"
    ON public.resenas FOR UPDATE
    USING (auth.uid() = id_usuario)
    WITH CHECK (auth.uid() = id_usuario);

CREATE POLICY "Usuarios eliminan su reseña"
    ON public.resenas FOR DELETE
    USING (auth.uid() = id_usuario);

CREATE POLICY "Admin gestiona reseñas"
    ON public.resenas FOR ALL
    USING (public.es_admin())
    WITH CHECK (public.es_admin());

-- ------------------------------------------------------------------------------
-- 11. Eliminar usuario desde el panel de administración
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_eliminar_usuario(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF NOT public.es_admin() THEN
        RAISE EXCEPTION 'No tienes permisos de administrador.';
    END IF;

    IF p_id = auth.uid() THEN
        RAISE EXCEPTION 'No puedes eliminar tu propia cuenta desde el panel.';
    END IF;

    -- Al borrar de auth.users se eliminan en cascada perfil, favoritos y reservas.
    DELETE FROM auth.users WHERE id = p_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_eliminar_usuario(UUID) TO authenticated;

-- ------------------------------------------------------------------------------
-- 12. Storage: buckets públicos para fotos de perfil y de negocios
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('avatars', 'avatars', true),
    ('business-images', 'business-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Lectura pública de las imágenes.
DROP POLICY IF EXISTS "TurisApp lectura publica avatars" ON storage.objects;
DROP POLICY IF EXISTS "TurisApp lectura publica business images" ON storage.objects;
DROP POLICY IF EXISTS "TurisApp sube sus avatars" ON storage.objects;
DROP POLICY IF EXISTS "TurisApp sube sus business images" ON storage.objects;
DROP POLICY IF EXISTS "TurisApp actualiza sus avatars" ON storage.objects;
DROP POLICY IF EXISTS "TurisApp actualiza sus business images" ON storage.objects;
DROP POLICY IF EXISTS "TurisApp elimina sus avatars" ON storage.objects;
DROP POLICY IF EXISTS "TurisApp elimina sus business images" ON storage.objects;

CREATE POLICY "TurisApp lectura publica avatars"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "TurisApp lectura publica business images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'business-images');

-- El primer nivel de la ruta siempre es el id del usuario autenticado:
--   avatars/<user_id>/archivo.jpg
--   business-images/<user_id>/portada/archivo.jpg
--   business-images/<user_id>/lugares/archivo.jpg
CREATE POLICY "TurisApp sube sus avatars"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "TurisApp sube sus business images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'business-images'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "TurisApp actualiza sus avatars"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'avatars'
        AND auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "TurisApp actualiza sus business images"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'business-images'
        AND auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'business-images'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "TurisApp elimina sus avatars"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'avatars'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "TurisApp elimina sus business images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'business-images'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- ------------------------------------------------------------------------------
-- 13. Planificador de rutas en micro
-- Devuelve rutas directas y con un transbordo entre líneas cercanas.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.planificar_ruta_micros(
    o_lat DOUBLE PRECISION,
    o_lng DOUBLE PRECISION,
    d_lat DOUBLE PRECISION,
    d_lng DOUBLE PRECISION,
    p_dist DOUBLE PRECISION DEFAULT 700.0
)
RETURNS TABLE (
    tipo TEXT,
    linea_1 TEXT,
    linea_2 TEXT,
    distancia_origen DOUBLE PRECISION,
    distancia_destino DOUBLE PRECISION,
    distancia_transbordo DOUBLE PRECISION
)
LANGUAGE sql
STABLE
AS $$
WITH
origen AS (
    SELECT DISTINCT ON (m.linea)
        m.linea,
        m.sentido,
        m.distancia_metros
    FROM public.obtener_micros_cercanos(o_lat, o_lng, p_dist) m
    ORDER BY m.linea, m.distancia_metros
),
destino AS (
    SELECT DISTINCT ON (m.linea)
        m.linea,
        m.sentido,
        m.distancia_metros
    FROM public.obtener_micros_cercanos(d_lat, d_lng, p_dist) m
    ORDER BY m.linea, m.distancia_metros
),
lineas_geom AS (
    SELECT t.id_linea, ST_Union(t.geom) AS geom
    FROM public.tramos_micros t
    WHERE t.geom IS NOT NULL
      AND t.id_linea IN (
          SELECT linea FROM origen
          UNION
          SELECT linea FROM destino
      )
    GROUP BY t.id_linea
),
directas AS (
    SELECT
        'directa'::TEXT AS tipo,
        o.linea AS linea_1,
        NULL::TEXT AS linea_2,
        o.distancia_metros AS distancia_origen,
        d.distancia_metros AS distancia_destino,
        0::DOUBLE PRECISION AS distancia_transbordo,
        (o.distancia_metros + d.distancia_metros) AS score
    FROM origen o
    JOIN destino d ON d.linea = o.linea
),
pares AS (
    SELECT
        'transbordo'::TEXT AS tipo,
        o.linea AS linea_1,
        d.linea AS linea_2,
        o.distancia_metros AS distancia_origen,
        d.distancia_metros AS distancia_destino,
        ROUND(
            ST_Distance(go.geom::geography, gd.geom::geography)::NUMERIC,
            1
        )::DOUBLE PRECISION AS distancia_transbordo,
        (
            o.distancia_metros
            + d.distancia_metros
            + ROUND(ST_Distance(go.geom::geography, gd.geom::geography)::NUMERIC, 1)::DOUBLE PRECISION
        ) AS score
    FROM origen o
    JOIN destino d ON d.linea <> o.linea
    JOIN lineas_geom go ON go.id_linea = o.linea
    JOIN lineas_geom gd ON gd.id_linea = d.linea
    WHERE ST_Distance(go.geom::geography, gd.geom::geography) <= 1200
),
combinadas AS (
    SELECT * FROM directas
    UNION ALL
    SELECT * FROM pares
)
SELECT
    c.tipo,
    c.linea_1,
    c.linea_2,
    c.distancia_origen,
    c.distancia_destino,
    c.distancia_transbordo
FROM combinadas c
ORDER BY
    CASE WHEN c.tipo = 'directa' THEN 0 ELSE 1 END,
    c.score ASC
LIMIT 12;
$$;

GRANT EXECUTE ON FUNCTION public.planificar_ruta_micros(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION
) TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.obtener_micros_cercanos(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION
) TO anon, authenticated;

-- ------------------------------------------------------------------------------
-- 14. Permisos básicos de lectura para la app
-- ------------------------------------------------------------------------------
GRANT SELECT ON public.categorias, public.destinos_lugares, public.resenas,
    public.lineas_micros, public.tramos_micros TO anon, authenticated;

-- ==============================================================================
-- FIN DEL SCRIPT
-- ==============================================================================
