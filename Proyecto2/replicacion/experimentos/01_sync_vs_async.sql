-- REALIZAR EN EL QUERY TOOL DE pg_nodo1 (primary)
-- Verificar en qué modo estamos actualmente
SHOW synchronous_commit;

-- Cambiar a modo ASÍNCRONO
ALTER SYSTEM SET synchronous_commit = off;
ALTER SYSTEM SET synchronous_standby_names = '';
SELECT pg_reload_conf();

-- Medir 500 inserts en modo asíncrono
DO $$
DECLARE
    v_inicio TIMESTAMPTZ := clock_timestamp();
    v_ms     NUMERIC;
BEGIN
    INSERT INTO usuarios (nombre, email, region)
    SELECT 'Async' || i, 'async' || i || '@test.com', 'bogota'
    FROM generate_series(1, 500) i;

    v_ms := extract(epoch from (clock_timestamp() - v_inicio)) * 1000;
    RAISE NOTICE 'ASYNC: % ms', round(v_ms, 3);
END;
$$;

-- ── Cambiar a modo SÍNCRONO ──────────────────────────────────
ALTER SYSTEM SET synchronous_commit = on;
ALTER SYSTEM SET synchronous_standby_names = 'pg_replica1,pg_replica2';
SELECT pg_reload_conf();

-- Verificar estado de las réplicas
-- Si sync_state aparece 'async', usar FIRST 1 (*) en su lugar
SELECT client_addr, application_name, state, sync_state
FROM pg_stat_replication;

-- Si las réplicas aparecen como async, ejecutar esto en su lugar:
-- ALTER SYSTEM SET synchronous_standby_names = 'FIRST 1 (*)';
-- SELECT pg_reload_conf();

-- Medir 500 inserts en modo síncrono
DO $$
DECLARE
    v_inicio TIMESTAMPTZ := clock_timestamp();
    v_ms     NUMERIC;
BEGIN
    INSERT INTO usuarios (nombre, email, region)
    SELECT 'Sync_' || i, 'sync_' || i || '@test.com', 'medellin'
    FROM generate_series(1, 500) i;

    v_ms := extract(epoch from (clock_timestamp() - v_inicio)) * 1000;
    RAISE NOTICE 'SYNC: % ms', round(v_ms, 3);
END;
$$;

-- El modo síncrono es más lento porque el primary espera confirmación
-- de la réplica antes de responderle al cliente.
-- El modo asíncrono no espera confirmación y por eso es más rápido.