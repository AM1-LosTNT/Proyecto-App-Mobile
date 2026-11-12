-- ==============================================================================
-- TURISAPP - ESQUEMA DE BASE DE DATOS (SUPABASE / POSTGRESQL + POSTGIS)
-- Incluye: Guía Turística, Negocios, Rutas/Tours, Reservas, Reseñas, Favoritos
-- y Sistema Geoespacial para Transporte Público (Micros Santa Cruz de la Sierra)
-- ==============================================================================

-- 1. Habilitar extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- Esencial para calcular distancias, paradas y "cómo llegar"

-- ==============================================================================
-- 2. TABLA: usuarios (Vinculada a Supabase Auth)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    avatar_url TEXT DEFAULT 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    rol TEXT NOT NULL DEFAULT 'user' CHECK (rol IN ('user', 'business', 'admin')),
    nombre_negocio TEXT,
    telefono TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ==============================================================================
-- 3. TABLA: categorias (Hoteles, Restaurantes, Atracciones, Museos, etc.)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS categorias (
    id SERIAL PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL, -- 'hotel', 'restaurant', 'attraction', 'hospital', 'montana', 'playas', etc.
    nombre TEXT NOT NULL,
    descripcion TEXT,
    icono TEXT, -- nombre del icono Ionicons: 'bed-outline', 'restaurant-outline', etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ==============================================================================
-- 4. TABLA: destinos_lugares (Lugares turísticos y negocios registrados)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS destinos_lugares (
    id TEXT PRIMARY KEY DEFAULT ('dest-' || substr(md5(random()::text), 1, 8)),
    id_usuario UUID REFERENCES usuarios(id) ON DELETE SET NULL, -- Dueño que registró el local
    id_categoria INTEGER REFERENCES categorias(id) ON DELETE SET NULL,
    nombre TEXT NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'attraction', -- 'hotel', 'restaurant', 'attraction', 'hospital'
    descripcion TEXT,
    direccion TEXT,
    telefono TEXT,
    precio NUMERIC(10, 2) DEFAULT 0,
    precio_texto TEXT, -- ej. '$35 por persona', '$95 / noche'
    rating NUMERIC(2, 1) DEFAULT 5.0,
    total_reviews INTEGER DEFAULT 0,
    imagen_principal TEXT,
    imagenes TEXT[] DEFAULT ARRAY[]::TEXT[],
    servicios_incluidos TEXT[] DEFAULT ARRAY[]::TEXT[],
    latitud DOUBLE PRECISION NOT NULL,
    longitud DOUBLE PRECISION NOT NULL,
    ubicacion GEOMETRY(Point, 4326) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitud, latitud), 4326)) STORED,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ==============================================================================
-- 5. TABLA: rutas_tours (Planes, circuitos turísticos e itinerarios paso a paso)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS rutas_tours (
    id TEXT PRIMARY KEY DEFAULT ('route-' || substr(md5(random()::text), 1, 8)),
    id_creador UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    titulo TEXT NOT NULL,
    descripcion TEXT,
    duracion TEXT, -- ej. '2 Días / 1 Noche', 'Medio Día'
    dificultad TEXT DEFAULT 'Fácil', -- 'Fácil', 'Moderada', 'Alta'
    distancia TEXT, -- ej. '24 km'
    portada_url TEXT,
    rating NUMERIC(2, 1) DEFAULT 5.0,
    pasos_itinerario JSONB NOT NULL DEFAULT '[]'::JSONB, -- [{ "name": "Plaza Principal", "time": "08:00 AM" }, ...]
    solo_registrados BOOLEAN DEFAULT true, -- Restricción de acceso para usuarios registrados
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ==============================================================================
-- 6. TABLA: reservas (Bookings de turistas para atracciones / negocios)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS reservas (
    id TEXT PRIMARY KEY DEFAULT ('book-' || substr(md5(random()::text), 1, 8)),
    id_destino TEXT REFERENCES destinos_lugares(id) ON DELETE CASCADE,
    id_turista UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    email_propietario TEXT,
    fecha_reserva TEXT NOT NULL,
    cantidad_personas INTEGER NOT NULL DEFAULT 1,
    precio_unitario NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total NUMERIC(10, 2) NOT NULL DEFAULT 0,
    estado TEXT NOT NULL DEFAULT 'Confirmada' CHECK (estado IN ('Pendiente', 'Confirmada', 'Cancelada', 'Completada')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ==============================================================================
-- 7. TABLA: favoritos (Destinos guardados por cada usuario)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS favoritos (
    id SERIAL PRIMARY KEY,
    id_usuario UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    id_destino TEXT REFERENCES destinos_lugares(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(id_usuario, id_destino)
);

-- ==============================================================================
-- 8. TABLA: resenas (Calificaciones y opiniones de turistas)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS resenas (
    id SERIAL PRIMARY KEY,
    id_destino TEXT REFERENCES destinos_lugares(id) ON DELETE CASCADE,
    id_usuario UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    calificacion INTEGER CHECK (calificacion BETWEEN 1 AND 5),
    comentario TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ==============================================================================
-- 9. TRANSPORTE PÚBLICO: lineas_micros & tramos_micros
-- Coincide exactamente con los datos de rutas_scz.geojson
-- ==============================================================================
CREATE TABLE IF NOT EXISTS lineas_micros (
    id TEXT PRIMARY KEY, -- '1', '2', '16 azul', etc.
    numero TEXT NOT NULL,
    sindicato INTEGER,
    medio INTEGER,
    parque_automotor INTEGER, -- Propiedad 'parque_a' del GeoJSON
    color TEXT, -- Para pintar la línea en el mapa
    descripcion TEXT,
    tarifa NUMERIC(5, 2) DEFAULT 2.00, -- Tarifa tradicional en Bs en SCZ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS tramos_micros (
    id SERIAL PRIMARY KEY,
    objectid INTEGER UNIQUE, -- Propiedad 'objectid' del GeoJSON para evitar duplicados al importar
    id_linea TEXT REFERENCES lineas_micros(id) ON DELETE CASCADE,
    sentido INTEGER NOT NULL, -- 1 = Ida, 2 = Vuelta
    origen INTEGER,
    medio INTEGER,
    destino INTEGER,
    desdoble INTEGER DEFAULT 0,
    coordenadas JSONB NOT NULL, -- Formato GeoJSON original
    geom GEOMETRY(MultiLineString, 4326), -- PostGIS MultiLineString para análisis espacial de rutas
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ==============================================================================
-- 10. ÍNDICES DE RENDIMIENTO (Espaciales B-Tree y GIST)
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_destinos_categoria ON destinos_lugares(id_categoria);
CREATE INDEX IF NOT EXISTS idx_destinos_usuario ON destinos_lugares(id_usuario);
CREATE INDEX IF NOT EXISTS idx_destinos_geom ON destinos_lugares USING GIST(ubicacion);
CREATE INDEX IF NOT EXISTS idx_reservas_turista ON reservas(id_turista);
CREATE INDEX IF NOT EXISTS idx_reservas_destino ON reservas(id_destino);
CREATE INDEX IF NOT EXISTS idx_favoritos_usuario ON favoritos(id_usuario);
CREATE INDEX IF NOT EXISTS idx_tramos_id_linea ON tramos_micros(id_linea);
CREATE INDEX IF NOT EXISTS idx_tramos_sentido ON tramos_micros(sentido);
CREATE INDEX IF NOT EXISTS idx_tramos_geom ON tramos_micros USING GIST(geom);

-- ==============================================================================
-- 11. FUNCIÓN POSTGIS: "CÓMO LLEGAR AL DESTINO" (Búsqueda de micros cercanos)
-- Busca qué líneas de micro pasan a menos de N metros de un punto turístico
-- ==============================================================================
CREATE OR REPLACE FUNCTION obtener_micros_cercanos(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_distancia_metros DOUBLE PRECISION DEFAULT 400.0
)
RETURNS TABLE (
    linea TEXT,
    sentido INTEGER,
    distancia_metros DOUBLE PRECISION,
    origen INTEGER,
    destino INTEGER
) LANGUAGE sql STABLE AS $$
    SELECT DISTINCT ON (t.id_linea, t.sentido)
        t.id_linea AS linea,
        t.sentido,
        ROUND(ST_Distance(
            t.geom::geography,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        )::numeric, 1)::double precision AS distancia_metros,
        t.origen,
        t.destino
    FROM tramos_micros t
    WHERE t.geom IS NOT NULL
      AND ST_DWithin(
          t.geom::geography,
          ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
          p_distancia_metros
      )
    ORDER BY t.id_linea, t.sentido, distancia_metros ASC;
$$;

-- ==============================================================================
-- 12. SEGURIDAD Y PERMISOS: Row Level Security (RLS)
-- ==============================================================================
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE destinos_lugares ENABLE ROW LEVEL SECURITY;
ALTER TABLE rutas_tours ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservas ENABLE ROW LEVEL SECURITY;
ALTER TABLE favoritos ENABLE ROW LEVEL SECURITY;
ALTER TABLE resenas ENABLE ROW LEVEL SECURITY;
ALTER TABLE lineas_micros ENABLE ROW LEVEL SECURITY;
ALTER TABLE tramos_micros ENABLE ROW LEVEL SECURITY;

-- Políticas de Usuarios
CREATE POLICY "Lectura de perfiles de usuario" ON usuarios FOR SELECT USING (true);
CREATE POLICY "Usuarios gestionan su propio perfil" ON usuarios FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Usuarios insertan su propio perfil" ON usuarios FOR INSERT WITH CHECK (auth.uid() = id);

-- Políticas Catálogo y Guía (Categorías, Destinos, Rutas, Micros son de lectura pública)
CREATE POLICY "Lectura pública de categorias" ON categorias FOR SELECT USING (true);
CREATE POLICY "Lectura pública de destinos" ON destinos_lugares FOR SELECT USING (activo = true);
CREATE POLICY "Lectura de rutas turísticas" ON rutas_tours FOR SELECT USING (activo = true);
CREATE POLICY "Lectura pública de lineas" ON lineas_micros FOR SELECT USING (true);
CREATE POLICY "Lectura pública de tramos" ON tramos_micros FOR SELECT USING (true);

-- Dueños de negocio y Admin pueden insertar/modificar sus propios lugares
CREATE POLICY "Dueños y admin pueden crear lugares" ON destinos_lugares
    FOR INSERT WITH CHECK (auth.uid() = id_usuario OR (SELECT rol FROM usuarios WHERE id = auth.uid()) = 'admin');

CREATE POLICY "Dueños y admin pueden actualizar sus lugares" ON destinos_lugares
    FOR UPDATE USING (auth.uid() = id_usuario OR (SELECT rol FROM usuarios WHERE id = auth.uid()) = 'admin');

CREATE POLICY "Dueños y admin pueden eliminar sus lugares" ON destinos_lugares
    FOR DELETE USING (auth.uid() = id_usuario OR (SELECT rol FROM usuarios WHERE id = auth.uid()) = 'admin');

-- Reservas: Turistas ven sus reservas; Dueños ven las dirigidas a sus locales; Admin ve todas
CREATE POLICY "Ver reservas propias o de locales administrados" ON reservas
    FOR SELECT USING (
        auth.uid() = id_turista
        OR (SELECT email FROM usuarios WHERE id = auth.uid()) = email_propietario
        OR (SELECT rol FROM usuarios WHERE id = auth.uid()) = 'admin'
    );

CREATE POLICY "Turistas pueden crear reservas" ON reservas
    FOR INSERT WITH CHECK (auth.uid() = id_turista);

-- Favoritos: Cada usuario administra sus favoritos
CREATE POLICY "Usuarios ven sus propios favoritos" ON favoritos
    FOR SELECT USING (auth.uid() = id_usuario);

CREATE POLICY "Usuarios agregan a favoritos" ON favoritos
    FOR INSERT WITH CHECK (auth.uid() = id_usuario);

CREATE POLICY "Usuarios eliminan de favoritos" ON favoritos
    FOR DELETE USING (auth.uid() = id_usuario);

-- Reseñas: Lectura pública, creación por usuarios autenticados
CREATE POLICY "Lectura pública de reseñas" ON resenas FOR SELECT USING (true);
CREATE POLICY "Usuarios registrados crean reseñas" ON resenas FOR INSERT WITH CHECK (auth.uid() = id_usuario);

-- ==============================================================================
-- 13. SEED DE CATEGORÍAS INICIALES (Para TurisApp)
-- ==============================================================================
INSERT INTO categorias (slug, nombre, descripcion, icono) VALUES
('all', 'Todo', 'Todas las categorías', 'grid-outline'),
('montana', 'Montaña', 'Senderismo, miradores y cordillera', 'trail-sign-outline'),
('lugares', 'Lugares', 'Destinos y paseos destacados', 'compass-outline'),
('playas', 'Playas', 'Playas, lagunas y balnearios', 'water-outline'),
('parques', 'Parques', 'Reservas naturales y áreas verdes', 'leaf-outline'),
('cultura', 'Cultura', 'Casco histórico, museos y patrimonio', 'book-outline'),
('hotel', 'Hotel', 'Alojamiento, cabañas y hospedaje', 'bed-outline'),
('restaurant', 'Restaurante', 'Gastronomía y café', 'restaurant-outline'),
('hospital', 'Salud', 'Centros médicos y urgencias', 'medkit-outline')
ON CONFLICT (slug) DO NOTHING;


CREATE OR REPLACE FUNCTION public.manejar_nuevo_usuario()
RETURNS TRIGGER AS $$
DECLARE
    rol_texto TEXT;
    rol_final TEXT;
BEGIN
    -- Extraer el rol de los metadatos como texto
    rol_texto := NEW.raw_user_meta_data->>'rol';

    -- Mapear o validar el rol con los valores permitidos en tu app
    IF rol_texto = 'admin' THEN
        rol_final := 'admin';
    ELSIF rol_texto = 'business' THEN
        rol_final := 'business';
    ELSE
        rol_final := 'user'; -- Valor por defecto seguro
    END IF;

    -- Insertar en la tabla publica usuarios
    INSERT INTO public.usuarios (id, nombre, email, rol)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nombre', 'Usuario'),
        NEW.email,
        rol_final
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Asegurar el disparador (Trigger) en auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.manejar_nuevo_usuario();

-- 1. Mejorar el trigger para que use ON CONFLICT y nunca vuelva a dar error de duplicado
CREATE OR REPLACE FUNCTION public.manejar_nuevo_usuario()
RETURNS TRIGGER AS $$
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

    -- Usamos ON CONFLICT para evitar que falle si el usuario ya existe
    INSERT INTO public.usuarios (id, nombre, email, rol)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nombre', 'Usuario'),
        NEW.email,
        rol_final
    )
    ON CONFLICT (id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Asegurar que el trigger esté vinculado correctamente
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.manejar_nuevo_usuario();

-- 2. Limpiar dependencias y registros previos de prueba
DELETE FROM destinos_lugares WHERE nombre = 'Café 24 - Centro Histórico';
DELETE FROM public.usuarios WHERE email IN ('admin@turisapp.com', 'dueno@turisapp.com', 'turista@turisapp.com');
DELETE FROM auth.users WHERE email IN ('admin@turisapp.com', 'dueno@turisapp.com', 'turista@turisapp.com');

-- 3. Insertar los usuarios limpios en auth.users (el trigger los registrará automáticamente)
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  (
    'a1111111-1111-1111-1111-111111111111', 
    '00000000-0000-0000-0000-000000000000', 
    'authenticated', 
    'authenticated', 
    'admin@turisapp.com', 
    crypt('password123', gen_salt('bf')), 
    NOW(), 
    '{"provider":"email","providers":["email"]}', 
    '{"nombre": "Carlos Administrador", "rol": "admin"}', 
    NOW(), 
    NOW()
  ),
  (
    'b2222222-2222-2222-2222-222222222222', 
    '00000000-0000-0000-0000-000000000000', 
    'authenticated', 
    'authenticated', 
    'dueno@turisapp.com', 
    crypt('password123', gen_salt('bf')), 
    NOW(), 
    '{"provider":"email","providers":["email"]}', 
    '{"nombre": "Mateo Propietario", "rol": "business"}', 
    NOW(), 
    NOW()
  ),
  (
    'c3333333-3333-3333-3333-333333333333', 
    '00000000-0000-0000-0000-000000000000', 
    'authenticated', 
    'authenticated', 
    'turista@turisapp.com', 
    crypt('password123', gen_salt('bf')), 
    NOW(), 
    '{"provider":"email","providers":["email"]}', 
    '{"nombre": "Sofia Turista", "rol": "user"}', 
    NOW(), 
    NOW()
);

-- 4. Actualizar los campos adicionales en la tabla pública usuarios (teléfonos y nombre del negocio)
UPDATE public.usuarios SET telefono = '+59170000001' WHERE id = 'a1111111-1111-1111-1111-111111111111';
UPDATE public.usuarios SET nombre_negocio = 'Amboró Aventura Tours', telefono = '+59170000002' WHERE id = 'b2222222-2222-2222-2222-222222222222';
UPDATE public.usuarios SET telefono = '+59170000003' WHERE id = 'c3333333-3333-3333-3333-333333333333';

-- 5. Insertar el negocio de ejemplo geolocalizado en la Plaza 24 de Septiembre (Santa Cruz)
INSERT INTO destinos_lugares (
    id_usuario, 
    id_categoria, 
    nombre, 
    tipo, 
    descripcion, 
    direccion, 
    telefono, 
    precio, 
    precio_texto, 
    rating, 
    imagen_principal, 
    latitud, 
    longitud
)
VALUES (
    'b2222222-2222-2222-2222-222222222222', 
    3, 
    'Café 24 - Centro Histórico', 
    'restaurant', 
    'Café tradicional ubicado frente a la Plaza Principal de Santa Cruz de la Sierra, ideal para turistas.', 
    'Plaza 24 de Septiembre, Vereda Norte', 
    '+591 3 3322111', 
    25.00, 
    'Bs. 25 promedio', 
    4.8, 
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80',
    -17.783327, 
    -63.182140  
);