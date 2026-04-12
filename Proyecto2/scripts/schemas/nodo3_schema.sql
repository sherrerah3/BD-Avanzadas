-- ===========================================
-- NODO 3
-- Responsabilidad: pagos, y la partición
-- 2 de ordenes y order_items
-- ===========================================

-- Tabla padre de pagos (particionada por rango de fecha)
CREATE TABLE pagos (
    id       SERIAL,
    orden_id INTEGER,
    metodo   VARCHAR(30) CHECK (metodo IN ('tarjeta','pse','efectivo')),
    estado   VARCHAR(20) CHECK (estado IN ('pendiente','aprobado','rechazado')),
    fecha    TIMESTAMP DEFAULT NOW(),
    monto    NUMERIC(12,2),
    PRIMARY KEY (id, fecha)
) PARTITION BY RANGE (fecha);

CREATE TABLE pagos_2024 PARTITION OF pagos
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE pagos_2025 PARTITION OF pagos
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE pagos_2026 PARTITION OF pagos
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- Tabla padre de ordenes (misma definición en los 3 nodos)
CREATE TABLE ordenes (
    id         SERIAL,
    usuario_id INTEGER,
    fecha      TIMESTAMP DEFAULT NOW(),
    estado     VARCHAR(20) CHECK (estado IN ('pendiente','completada','cancelada')),
    total      NUMERIC(12,2),
    PRIMARY KEY (id, usuario_id)
) PARTITION BY HASH (usuario_id);

-- Partición de ordenes que vive en este nodo
CREATE TABLE ordenes_nodo2 PARTITION OF ordenes
    FOR VALUES WITH (modulus 3, remainder 2);

-- Tabla padre de order_items
CREATE TABLE order_items (
    id              SERIAL,
    orden_id        INTEGER,
    producto_id     INTEGER,
    cantidad        INTEGER,
    precio_unitario NUMERIC(10,2),
    PRIMARY KEY (id, orden_id)
) PARTITION BY HASH (orden_id);

-- Partición de order_items que vive en este nodo
CREATE TABLE order_item_nodo2 PARTITION OF order_items
    FOR VALUES WITH (modulus 3, remainder 2);
