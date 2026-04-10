-- Cada consulta se realiza en el Primary (pg_nodo1) y en la replica (pg_replica1)
-- Consulta 1: Agregado por región
EXPLAIN ANALYZE
SELECT region, COUNT(*) AS total, AVG(id) AS promedio_id
FROM usuarios
GROUP BY region
ORDER BY total DESC;

-- Consulta 2: Filtro por región y fecha 
EXPLAIN ANALYZE
SELECT *
FROM usuarios
WHERE region = 'medellin'
AND created_at >= NOW() - INTERVAL '365 days';

-- Consulta 3: Ordenar por fecha con límite 
EXPLAIN ANALYZE
SELECT nombre, email, created_at
FROM usuarios
ORDER BY created_at DESC
LIMIT 100;

-- El primary es marginalmente más rápido en los 3 casos,
-- pero la diferencia es pequeña. Esto demuestra que se puede
-- distribuir carga de lecturas en las réplicas sin perder rendimiento.

-- ── Impacto del número de réplicas (con sync ON) ─────────────
-- Activar modo síncrono primero:
-- ALTER SYSTEM SET synchronous_commit = on;
-- ALTER SYSTEM SET synchronous_standby_names = 'FIRST 1 (*)';
-- SELECT pg_reload_conf();

-- Medir con 2 réplicas activas
DO $$
DECLARE
    v_inicio TIMESTAMPTZ := clock_timestamp();
    v_ms     NUMERIC;
BEGIN
    INSERT INTO usuarios (nombre, email, region)
    SELECT '2rep' || i, '2rep' || i || '@test.com', 'cali'
    FROM generate_series(1, 500) i;

    v_ms := extract(epoch from (clock_timestamp() - v_inicio)) * 1000;
    RAISE NOTICE '2 replicas: % ms', round(v_ms, 3);
END;
$$;

-- Detener una réplica desde la TERMINAL: docker stop pg_replica2

-- Medir con 1 réplica activa
DO $$
DECLARE
    v_inicio TIMESTAMPTZ := clock_timestamp();
    v_ms     NUMERIC;
BEGIN
    INSERT INTO usuarios (nombre, email, region)
    SELECT '1rep' || i, '1rep' || i || '@test.com', 'cali'
    FROM generate_series(1, 500) i;

    v_ms := extract(epoch from (clock_timestamp() - v_inicio)) * 1000;
    RAISE NOTICE '1 replica: % ms', round(v_ms, 3);
END;
$$;

-- Con 1 réplica en sync es más rápido porque el primary
-- solo espera confirmación de un nodo en lugar de dos.

-- Restaurar réplica2 desde la TERMINAL: docker start pg_replica2