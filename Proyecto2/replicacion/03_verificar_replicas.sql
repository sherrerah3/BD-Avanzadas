-- DESDE pg_nodo1 :

-- Ver réplicas en streaming
SELECT client_addr, state
FROM pg_stat_replication;
-- Debe aparecer una fila por cada réplica con state = 'streaming'

-- Ver detalles completos de replicación
SELECT * FROM pg_stat_replication;
-- Campos importantes: sent_lsn, write_lsn, flush_lsn, replay_lsn, sync_state

-- ── DESDE pg_replica1 y/o pg_replica2 :

-- Confirmar que está en modo solo lectura
SELECT pg_is_in_recovery();
-- Debe retornar: true (y por ejemplo, nodo1 deberia retornar false)

-- Ver desde dónde replica
SELECT * FROM pg_stat_wal_receiver;