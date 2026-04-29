-- Registrar estado antes de la caída
-- Ejecutar en pg_nodo1

-- 1. Contar usuarios actuales para verificar consistencia después
SELECT COUNT(*) AS total_usuarios FROM usuarios;

-- Registrar posición WAL actual del primary
SELECT pg_current_wal_lsn();

-- 2. Simular caída del primary
-- Ejecutar en la TERMINAL:
-- docker stop pg_nodo1

-- 3. Promover pg_replica1
-- Ejecutar en la TERMINAL:
-- docker exec pg_replica1 su -c "pg_ctl promote -D /var/lib/postgresql/data" postgres

-- 4. Verificar promoción
-- Ejecutar en pg_replica1

-- Debe retornar FALSE — ya no es una réplica de solo lectura
SELECT pg_is_in_recovery();

-- Verificar que acepta escrituras
INSERT INTO usuarios (nombre, email, region)
VALUES ('FailoverTest', 'failover@test.com', 'bogota');

-- El conteo debe ser el mismo de antes + 1
SELECT COUNT(*) FROM usuarios;

-- 5. Reconectar pg_replica2 al nuevo primary
-- Ejecutar en la TERMINAL:
-- docker exec pg_replica2 bash -c "
-- echo \"primary_conninfo = 'host=pg_replica1 port=5432 user=replicator password=replica123'\" >> /var/lib/postgresql/data/postgresql.auto.conf
-- su -c 'pg_ctl reload -D /var/lib/postgresql/data' postgres
-- "

-- 6. Verificar que pg_replica2 está en streaming
-- Ejecutar en pg_replica1 (nuevo primary)
-- Debe aparecer pg_replica2 con state = 'streaming'
SELECT client_addr, state FROM pg_stat_replication;
