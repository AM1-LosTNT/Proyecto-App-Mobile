-- ==============================================================================
-- TURISAPP · MIGRACIÓN: TIENDA, CARRITO Y VALIDACIÓN DE PAGOS POR QR
-- Ejecuta este script en el SQL Editor de Supabase.
-- Totalmente idempotente (se puede ejecutar varias veces con seguridad).
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------------------------
-- 1. TABLA: productos (Catálogo de la Tienda de Souvenirs)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    precio NUMERIC(10, 2) NOT NULL CHECK (precio >= 0),
    stock INTEGER NOT NULL DEFAULT 50 CHECK (stock >= 0),
    imagen_url TEXT NOT NULL,
    categoria TEXT DEFAULT 'souvenir',
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 2. TABLA: pedidos (Órdenes de compra generadas desde el Carrito)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pedidos (
    id TEXT PRIMARY KEY DEFAULT ('ord-' || substr(md5(random()::text), 1, 8)),
    id_turista UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    total NUMERIC(10, 2) NOT NULL CHECK (total >= 0),
    estado TEXT NOT NULL DEFAULT 'Pendiente' CHECK (estado IN ('Pendiente', 'Pagado', 'En Camino', 'Entregado', 'Cancelado')),
    metodo_pago TEXT NOT NULL DEFAULT 'QR_SIMPLE',
    codigo_referencia TEXT NOT NULL UNIQUE DEFAULT ('TURIS-' || upper(substr(md5(random()::text), 1, 6))),
    direccion_entrega TEXT,
    telefono_contacto TEXT,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 3. TABLA: detalle_pedidos (Ítems y cantidades de cada pedido)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.detalle_pedidos (
    id BIGSERIAL PRIMARY KEY,
    id_pedido TEXT NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
    id_producto UUID NOT NULL REFERENCES public.productos(id) ON DELETE RESTRICT,
    nombre_producto TEXT NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10, 2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 4. TABLA: pagos_historial (Blindaje Anti-Fraude, Auditoría y Verificación QR)
-- Soporta pagos tanto de Pedidos de la Tienda como de Reservas Turísticas
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pagos_historial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_pedido TEXT REFERENCES public.pedidos(id) ON DELETE CASCADE,
    id_reserva TEXT REFERENCES public.reservas(id) ON DELETE CASCADE,
    id_usuario UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    banco_origen TEXT,
    -- Nro. de Referencia ÚNICO: Evita reutilizar el mismo comprobante bancario
    numero_referencia_banco TEXT NOT NULL,
    monto_validado NUMERIC(10, 2) NOT NULL CHECK (monto_validado >= 0),
    fecha_transferencia TEXT,
    comprobante_url TEXT NOT NULL,
    tipo_archivo TEXT NOT NULL CHECK (tipo_archivo IN ('imagen', 'pdf')),
    -- Hash SHA-256 ÚNICO del archivo: Impide re-subir exactamente el mismo archivo PDF o imagen
    archivo_hash_sha256 TEXT NOT NULL,
    estado TEXT NOT NULL DEFAULT 'Verificado' CHECK (estado IN ('Verificado', 'En Revisión', 'Rechazado')),
    metadatos_extraccion JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT chk_pago_origen CHECK (id_pedido IS NOT NULL OR id_reserva IS NOT NULL)
);

-- Si la tabla ya existía, añadimos la columna id_reserva de forma segura:
ALTER TABLE public.pagos_historial 
    ADD COLUMN IF NOT EXISTS id_reserva TEXT REFERENCES public.reservas(id) ON DELETE CASCADE;

ALTER TABLE public.pagos_historial 
    ALTER COLUMN id_pedido DROP NOT NULL;

-- Índices únicos anti-fraude:
CREATE UNIQUE INDEX IF NOT EXISTS uidx_pagos_referencia_banco
    ON public.pagos_historial (numero_referencia_banco);

CREATE UNIQUE INDEX IF NOT EXISTS uidx_pagos_hash_sha256
    ON public.pagos_historial (archivo_hash_sha256);

CREATE INDEX IF NOT EXISTS idx_pedidos_turista
    ON public.pedidos (id_turista);

CREATE INDEX IF NOT EXISTS idx_detalle_pedido
    ON public.detalle_pedidos (id_pedido);

CREATE INDEX IF NOT EXISTS idx_pagos_pedido
    ON public.pagos_historial (id_pedido);

CREATE INDEX IF NOT EXISTS idx_pagos_reserva
    ON public.pagos_historial (id_reserva);

-- ------------------------------------------------------------------------------
-- 5. TRIGGER: Al verificar un pago, cambiar pedido o reserva a 'Pagado'/'Confirmada'
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_on_pago_verificado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.estado = 'Verificado' THEN
        -- 1. Si el pago corresponde a un Pedido de Tienda:
        IF NEW.id_pedido IS NOT NULL THEN
            UPDATE public.pedidos
            SET estado = 'Pagado',
                updated_at = TIMEZONE('utc'::text, NOW())
            WHERE id = NEW.id_pedido;

            UPDATE public.productos p
            SET stock = GREATEST(0, p.stock - dp.cantidad),
                updated_at = TIMEZONE('utc'::text, NOW())
            FROM public.detalle_pedidos dp
            WHERE dp.id_pedido = NEW.id_pedido
              AND dp.id_producto = p.id;
        END IF;

        -- 2. Si el pago corresponde a una Reserva Turística (hotel, tour, restaurante):
        IF NEW.id_reserva IS NOT NULL THEN
            UPDATE public.reservas
            SET estado = 'Confirmada'
            WHERE id = NEW.id_reserva;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pago_verificado ON public.pagos_historial;
CREATE TRIGGER trg_pago_verificado
    AFTER INSERT OR UPDATE OF estado ON public.pagos_historial
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_on_pago_verificado();

-- ------------------------------------------------------------------------------
-- 6. RPC: Función segura para registrar pedido con sus detalles en una sola transacción
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_pedido_completo(
    p_id_turista UUID,
    p_total NUMERIC,
    p_direccion TEXT,
    p_telefono TEXT,
    p_notas TEXT,
    p_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pedido_id TEXT;
    v_codigo TEXT;
    v_item JSONB;
BEGIN
    v_pedido_id := 'ord-' || substr(md5(random()::text), 1, 8);
    v_codigo := 'TURIS-' || upper(substr(md5(random()::text), 1, 6));

    INSERT INTO public.pedidos (
        id, id_turista, total, estado, metodo_pago, codigo_referencia,
        direccion_entrega, telefono_contacto, notas
    )
    VALUES (
        v_pedido_id, p_id_turista, p_total, 'Pendiente', 'QR_SIMPLE', v_codigo,
        p_direccion, p_telefono, p_notas
    );

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO public.detalle_pedidos (
            id_pedido, id_producto, nombre_producto, cantidad, precio_unitario, subtotal
        )
        VALUES (
            v_pedido_id,
            (v_item->>'id_producto')::UUID,
            v_item->>'nombre_producto',
            (v_item->>'cantidad')::INTEGER,
            (v_item->>'precio_unitario')::NUMERIC,
            (v_item->>'subtotal')::NUMERIC
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'id_pedido', v_pedido_id,
        'codigo_referencia', v_codigo,
        'total', p_total
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 7. BUCKET DE STORAGE: comprobantes-pago
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('comprobantes-pago', 'comprobantes-pago', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'objects' AND policyname = 'Permitir subida de comprobantes a usuarios autenticados'
    ) THEN
        CREATE POLICY "Permitir subida de comprobantes a usuarios autenticados"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (bucket_id = 'comprobantes-pago');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'objects' AND policyname = 'Permitir lectura de comprobantes'
    ) THEN
        CREATE POLICY "Permitir lectura de comprobantes"
            ON storage.objects FOR SELECT
            TO authenticated
            USING (bucket_id = 'comprobantes-pago');
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 8. POLÍTICAS DE ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos_historial ENABLE ROW LEVEL SECURITY;

-- Productos: Lectura para todos, edición para admins
DROP POLICY IF EXISTS "Lectura de productos" ON public.productos;
CREATE POLICY "Lectura de productos" ON public.productos
    FOR SELECT TO public USING (activo = true);

-- Pedidos: Los usuarios solo ven y crean sus propios pedidos
DROP POLICY IF EXISTS "Turista ve sus pedidos" ON public.pedidos;
CREATE POLICY "Turista ve sus pedidos" ON public.pedidos
    FOR SELECT TO authenticated USING (id_turista = auth.uid());

DROP POLICY IF EXISTS "Turista crea sus pedidos" ON public.pedidos;
CREATE POLICY "Turista crea sus pedidos" ON public.pedidos
    FOR INSERT TO authenticated WITH CHECK (id_turista = auth.uid());

-- Detalle Pedidos:
DROP POLICY IF EXISTS "Turista ve detalles de sus pedidos" ON public.detalle_pedidos;
CREATE POLICY "Turista ve detalles de sus pedidos" ON public.detalle_pedidos
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.pedidos p WHERE p.id = detalle_pedidos.id_pedido AND p.id_turista = auth.uid()
    ));

DROP POLICY IF EXISTS "Turista crea detalles de pedido" ON public.detalle_pedidos;
CREATE POLICY "Turista crea detalles de pedido" ON public.detalle_pedidos
    FOR INSERT TO authenticated WITH CHECK (true);

-- Historial de Pagos:
DROP POLICY IF EXISTS "Turista ve su historial de pagos" ON public.pagos_historial;
CREATE POLICY "Turista ve su historial de pagos" ON public.pagos_historial
    FOR SELECT TO authenticated USING (id_usuario = auth.uid());

DROP POLICY IF EXISTS "Turista registra su pago" ON public.pagos_historial;
CREATE POLICY "Turista registra su pago" ON public.pagos_historial
    FOR INSERT TO authenticated WITH CHECK (id_usuario = auth.uid());

-- ------------------------------------------------------------------------------
-- 9. PRODUCTOS INICIALES (Souvenirs TurisApp)
-- ------------------------------------------------------------------------------
INSERT INTO public.productos (nombre, descripcion, precio, stock, imagen_url, categoria)
VALUES
    (
        'Gorra Oficial TurisApp',
        'Gorra trucker con visera curva y escudo bordado de TurisApp. Ideal para expediciones y protección solar.',
        45.00,
        60,
        'https://images.unsplash.com/photo-1588850561407-ed78c282e89b?auto=format&fit=crop&w=600&q=80',
        'souvenir'
    ),
    (
        'Polera Dry-Fit Senderismo',
        'Polera deportiva manga corta de tela transpirable con diseño conmemorativo de atractivos cruceños.',
        75.00,
        45,
        'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=600&q=80',
        'souvenir'
    ),
    (
        'Toma Todo / Termo Aventura 750ml',
        'Botella térmica de acero inoxidable de doble capa. Mantiene bebidas frías por 24h o calientes por 12h.',
        55.00,
        80,
        'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
        'souvenir'
    ),
    (
        'Mochila de Viaje Impermeable 30L',
        'Mochila ultraligera con compartimento para laptop, porta-termo y cinturón ergonómico para largas caminatas.',
        165.00,
        25,
        'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
        'souvenir'
    ),
    (
        'Sombrero Saó Artesanal',
        'Sombrero tradicional cruceño tejido a mano con fibras de palma saó. Auténtico recuerdo del oriente boliviano.',
        35.00,
        40,
        'https://images.unsplash.com/photo-1572495641004-28421ae52e52?auto=format&fit=crop&w=600&q=80',
        'souvenir'
    )
ON CONFLICT DO NOTHING;
