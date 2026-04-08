-- Habilitar extensión
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- 1. Definir servidores remotos
CREATE SERVER nodo2_server 
    FOREIGN DATA WRAPPER postgres_fdw 
    OPTIONS (host 'pg_nodo2', port '5432', dbname 'ecommerce');

CREATE SERVER nodo3_server 
    FOREIGN DATA WRAPPER postgres_fdw 
    OPTIONS (host 'pg_nodo3', port '5432', dbname 'ecommerce');

-- 2. Mapeo de usuarios (El admin del Nodo 1 puede entrar a los otros)
CREATE USER MAPPING FOR admin 
    SERVER nodo2_server 
    OPTIONS (user 'admin', password 'admin123');

CREATE USER MAPPING FOR admin 
    SERVER nodo3_server 
    OPTIONS (user 'admin', password 'admin123');

-- 3. Importar definición de tablas (PRODUCTOS vive en Nodo 2)
CREATE FOREIGN TABLE productos (
    id         INTEGER,
    nombre     VARCHAR(200),
    categoria  VARCHAR(100),
    precio     NUMERIC(10,2),
    stock      INTEGER,
    created_at TIMESTAMP
) SERVER nodo2_server OPTIONS (schema_name 'public', table_name 'productos');

-- 4. Importar particiones de ORDENES
CREATE FOREIGN TABLE ordenes_nodo1 (
    id         INTEGER,
    usuario_id INTEGER,
    fecha      TIMESTAMP,
    estado     VARCHAR(20) CONSTRAINT ordenes_estado_check CHECK (estado IN ('pendiente','completada','cancelada')),
    total      NUMERIC(12,2)
) SERVER nodo2_server OPTIONS (schema_name 'public', table_name 'ordenes_nodo1');

CREATE FOREIGN TABLE ordenes_nodo2 (
    id         INTEGER,
    usuario_id INTEGER,
    fecha      TIMESTAMP,
    estado     VARCHAR(20) CONSTRAINT ordenes_estado_check CHECK (estado IN ('pendiente','completada','cancelada')),
    total      NUMERIC(12,2)
) SERVER nodo3_server OPTIONS (schema_name 'public', table_name 'ordenes_nodo2');

-- 5. Importar particiones de ORDER_ITEMS
CREATE FOREIGN TABLE order_item_nodo1 (
    id              INTEGER,
    orden_id        INTEGER,
    producto_id     INTEGER,
    cantidad        INTEGER,
    precio_unitario NUMERIC(10,2)
) SERVER nodo2_server OPTIONS (schema_name 'public', table_name 'order_item_nodo1');

CREATE FOREIGN TABLE order_item_nodo2 (
    id              INTEGER,
    orden_id        INTEGER,
    producto_id     INTEGER,
    cantidad        INTEGER,
    precio_unitario NUMERIC(10,2)
) SERVER nodo3_server OPTIONS (schema_name 'public', table_name 'order_item_nodo2');

-- 6. Adjuntar las tablas foráneas a las tablas PADRE del Nodo 1
ALTER TABLE ordenes ATTACH PARTITION ordenes_nodo1 
    FOR VALUES WITH (modulus 3, remainder 1);

ALTER TABLE ordenes ATTACH PARTITION ordenes_nodo2 
    FOR VALUES WITH (modulus 3, remainder 2);

ALTER TABLE order_items ATTACH PARTITION order_item_nodo1 
    FOR VALUES WITH (modulus 3, remainder 1);

ALTER TABLE order_items ATTACH PARTITION order_item_nodo2 
    FOR VALUES WITH (modulus 3, remainder 2);

-- 7. Traer PAGOS (Nodo 3) como tabla foránea para reportes
CREATE FOREIGN TABLE pagos_remote (
    id       INTEGER,
    orden_id INTEGER,
    metodo   VARCHAR(30),
    estado   VARCHAR(20),
    fecha    TIMESTAMP,
    monto    NUMERIC(12,2)
) SERVER nodo3_server OPTIONS (schema_name 'public', table_name 'pagos');