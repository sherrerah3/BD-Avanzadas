-- ===========================================
-- NODO 1
-- Responsabilidad: usuarios, y la partición
-- 0 de ordenes y order_items
-- ===========================================

-- Tabla maestra de usuarios
CREATE TABLE usuarios (
    id         SERIAL PRIMARY KEY,
    nombre     VARCHAR(100),
    email      VARCHAR(150) UNIQUE,
    region     VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Tabla padre de ordenes (solo se define aquí,
-- cada nodo aloja su propia partición)
CREATE TABLE ordenes (
    id         SERIAL,
    usuario_id INTEGER,
    fecha      TIMESTAMP DEFAULT NOW(),
    estado     VARCHAR(20) CHECK (estado IN ('pendiente','completada','cancelada')),
    total      NUMERIC(12,2),
    PRIMARY KEY (id, usuario_id)
) PARTITION BY HASH (usuario_id);

-- Partición de ordenes que vive en este nodo
CREATE TABLE ordenes_nodo0 PARTITION OF ordenes
    FOR VALUES WITH (modulus 3, remainder 0);

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
CREATE TABLE order_item_nodo0 PARTITION OF order_items
    FOR VALUES WITH (modulus 3, remainder 0);
