-- ===========================================
-- DATA — NODO 1 (Coordinador)
-- Ejecutar SOLO desde el Query Tool del Nodo 1
--
-- usuarios:    10.000
-- ordenes:     500.000  → enrutadas automáticamente a los 3 nodos vía FDW
-- order_items: 1.500.000 → enrutados automáticamente a los 3 nodos vía FDW
-- ===========================================

-- ─────────────────────────────────────────
-- 1. Usuarios (tabla local del Nodo 1)
-- ─────────────────────────────────────────
INSERT INTO usuarios (nombre, email, region, created_at)
SELECT
    'Usuario ' || i,
    'user_' || i || '@email.com',
    (ARRAY['bogota','medellin','cali','barranquilla','bucaramanga','cartagena'])[1 + (i % 6)],
    NOW() - (random() * INTERVAL '730 days')
FROM generate_series(1, 10000) AS i;

-- ─────────────────────────────────────────
-- 2. Órdenes (el Nodo 1 enruta cada fila
--    a la partición correcta vía FDW)
-- ─────────────────────────────────────────
INSERT INTO ordenes (id, usuario_id, fecha, estado, total)
SELECT
    i,
    1 + (i % 10000),
    NOW() - (random() * INTERVAL '730 days'),
    (ARRAY['pendiente','completada','completada','completada','cancelada'])[1 + (i % 5)],
    0
FROM generate_series(1, 500000) AS i;

-- ─────────────────────────────────────────
-- 3. Order items (el Nodo 1 enruta cada fila
--    a la partición correcta vía FDW)
-- ─────────────────────────────────────────
INSERT INTO order_items (id, orden_id, producto_id, cantidad, precio_unitario)
SELECT
    i,
    1 + ((i - 1) / 3),
    1 + (i % 1000),
    1 + (i % 5),
    ROUND((5000 + random() * 495000)::numeric, 2)
FROM generate_series(1, 1500000) AS i;

-- ─────────────────────────────────────────
-- 4. El "Join Distribuido": Actualizar totales
-- ─────────────────────────────────────────
UPDATE ordenes o
SET total = sub.suma
FROM (
    SELECT orden_id, SUM(cantidad * precio_unitario) as suma
    FROM order_items
    GROUP BY orden_id
) sub
WHERE o.id = sub.orden_id;

ANALYZE usuarios;
ANALYZE ordenes;
ANALYZE order_items;
