-- ===========================================
-- NODO 2
-- Responsabilidad: productos, y la partición
-- 1 de ordenes y order_items
-- ===========================================

-- Tabla maestra de productos
CREATE TABLE productos (
    id         SERIAL PRIMARY KEY,
    nombre     VARCHAR(200),
    categoria  VARCHAR(100),
    precio     NUMERIC(10,2),
    stock      INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

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
CREATE TABLE ordenes_nodo1 PARTITION OF ordenes
    FOR VALUES WITH (modulus 3, remainder 1);

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
CREATE TABLE order_item_nodo1 PARTITION OF order_items
    FOR VALUES WITH (modulus 3, remainder 1);
