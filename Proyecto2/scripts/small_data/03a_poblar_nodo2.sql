-- ===========================================
-- DATA — NODO 2
-- Ejecutar SOLO desde el Query Tool del Nodo 2
--
-- productos: 1.000 (tabla local del Nodo 2)
-- ===========================================

INSERT INTO productos (nombre, categoria, precio, stock, created_at)
SELECT
    'Producto ' || i,
    (ARRAY['electronica','ropa','hogar','deportes','libros','juguetes','alimentos','belleza'])[1 + (i % 8)],
    ROUND((5000 + random() * 4995000)::numeric, 2),
    (random() * 10000)::int,
    NOW() - (random() * INTERVAL '730 days')
FROM generate_series(1, 1000) AS i;

ANALYZE productos;
