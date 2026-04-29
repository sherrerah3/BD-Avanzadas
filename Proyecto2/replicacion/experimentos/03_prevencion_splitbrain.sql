-- ANTES de promover: ejecutar en la RÉPLICA a promover
-- Verificar que la réplica está al día con el primary.
-- Si wal_recibido = wal_aplicado → seguro promover.
-- Si son distintos → hay transacciones pendientes, esperar.
SELECT
    pg_last_wal_receive_lsn() AS wal_recibido,
    pg_last_wal_replay_lsn()  AS wal_aplicado;

-- ANTES de promover: verificar que el primary está caído
-- Ejecutar en la TERMINAL:
-- docker stop pg_nodo1
-- docker ps   (pg_nodo1 NO debe aparecer como "Up")

-- DESPUÉS del failover: verificar que no hubo divergencia
-- En pg_replica1 (nuevo primary):
SELECT pg_current_wal_lsn();

-- En pg_replica2:
SELECT pg_last_wal_replay_lsn();

-- Si los valores son iguales o muy similares → sin divergencia de datos.
-- Esto confirma que no hubo split-brain.