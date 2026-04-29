-- ===========================================
-- VERIFICACION SHARDING / DISTRIBUCION
-- Consultas extraidas de scripts de carga SMALL
-- ===========================================

-- [03a_poblar_nodo2_small.sql] Verificar productos insertados
SELECT COUNT(*) AS productos_insertados FROM productos;

-- [03b_poblar_nodo3_small.sql] Verificar distribucion por particion de fecha
SELECT
    tableoid::regclass AS particion,
    COUNT(*) AS filas
FROM pagos
GROUP BY tableoid
ORDER BY particion;

-- [03c_poblar_nodo1_small.sql] Verificar distribucion de particiones
SELECT 'ordenes' AS tabla, tableoid::regclass AS particion, COUNT(*) AS filas
FROM ordenes GROUP BY tableoid
UNION ALL
SELECT 'order_items', tableoid::regclass, COUNT(*)
FROM order_items GROUP BY tableoid
ORDER BY tabla, particion;
