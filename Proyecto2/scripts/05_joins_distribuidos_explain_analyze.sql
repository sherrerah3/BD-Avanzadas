-- =======================================================
-- JOINS DISTRIBUIDOS CON EXPLAIN ANALYZE
-- Ejecutar TODO desde el Query Tool del NODO 1
-- El nodo 1 es el coordinador y tiene visibilidad
-- de todas las particiones vía FDW
-- =======================================================


-- ─────────────────────────────────────────────────────
-- QUERY 1: Join simple — órdenes con nombre de usuario
-- Cruza: usuarios (local Nodo1) + ordenes (3 particiones)
-- ─────────────────────────────────────────────────────

EXPLAIN ANALYZE
SELECT
    u.nombre,
    u.region,
    o.id        AS orden_id,
    o.estado,
    o.total,
    o.fecha
FROM ordenes o
JOIN usuarios u ON u.id = o.usuario_id
WHERE o.estado = 'completada'
ORDER BY o.fecha DESC
LIMIT 20;

/*
QUÉ OBSERVAR EN EL PLAN:
- "Foreign Scan on ordenes_nodo1" → acceso remoto a Nodo 2 vía FDW
- "Foreign Scan on ordenes_nodo2" → acceso remoto a Nodo 3 vía FDW
- "Seq Scan on ordenes_nodo0"     → acceso local en Nodo 1
- "Append" → el coordinador une los resultados de las 3 particiones
- Compara el costo estimado vs tiempo real (rows, loops)
*/


-- ─────────────────────────────────────────────────────
-- QUERY 2: Join triple — órdenes + usuarios + order_items
-- Cruza las 3 tablas distribuidas
-- ─────────────────────────────────────────────────────

EXPLAIN ANALYZE
SELECT
    u.nombre,
    u.region,
    o.id        AS orden_id,
    o.fecha,
    COUNT(oi.id)        AS num_items,
    SUM(oi.cantidad * oi.precio_unitario) AS total_calculado
FROM ordenes o
JOIN usuarios u  ON u.id       = o.usuario_id
JOIN order_items oi ON oi.orden_id = o.id
WHERE o.estado = 'completada'
  AND o.fecha >= NOW() - INTERVAL '1 year'
GROUP BY u.nombre, u.region, o.id, o.fecha
ORDER BY total_calculado DESC
LIMIT 10;

/*
QUÉ OBSERVAR EN EL PLAN:
- El coordinador hace Foreign Scans en paralelo a Nodo 2 y Nodo 3
- "Hash Join" o "Nested Loop" → estrategia elegida para cruzar particiones
- Tiempo de planificación vs ejecución
- rows=X vs actual rows=Y → qué tan preciso es el estimador de Postgres
  con tablas distribuidas (suele subestimar porque no tiene estadísticas
  completas de los nodos remotos)
*/


-- ─────────────────────────────────────────────────────
-- QUERY 3: OLAP — ventas por región y mes
-- Agrega datos de todas las particiones
-- ─────────────────────────────────────────────────────

EXPLAIN ANALYZE
SELECT
    u.region,
    DATE_TRUNC('month', o.fecha) AS mes,
    COUNT(o.id)                  AS total_ordenes,
    SUM(o.total)                 AS ingresos,
    AVG(o.total)                 AS ticket_promedio
FROM ordenes o
JOIN usuarios u ON u.id = o.usuario_id
WHERE o.estado = 'completada'
  AND o.fecha BETWEEN '2025-01-01' AND '2026-12-31'
GROUP BY u.region, DATE_TRUNC('month', o.fecha)
ORDER BY mes DESC, ingresos DESC;

/*
QUÉ OBSERVAR EN EL PLAN:
- "Parallel Append" → Postgres puede paralelizar el scan de particiones
- Costo total del plan con agregaciones sobre datos distribuidos
- Comparar este tiempo vs una query equivalente en una sola tabla
  (este es el argumento para documentar el trade-off de distribución)
*/


-- ─────────────────────────────────────────────────────
-- QUERY 4: Verificar partition pruning
-- Esta query solo debe tocar ordenes_nodo0 (hash remainder 0)
-- El coordinador debe descartar las otras 2 particiones
-- ─────────────────────────────────────────────────────

EXPLAIN
SELECT COUNT(*)
FROM ordenes
WHERE usuario_id = 100042;

/*
QUÉ OBSERVAR:
- Si el plan muestra solo 1 partición → partition pruning funcionando
- Si muestra las 3 → el optimizador no puede hacer pruning con HASH
  (esto es un comportamiento conocido de Postgres con hash partitioning
  y es interesante documentarlo: el pruning solo funciona con rangos)
*/
