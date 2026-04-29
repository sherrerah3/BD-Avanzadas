-- CONFIGURAR NODO 1 COMO PRIMARY PARA REPLICACION
-- Ejecutar en orden linea por linea (por separado) en el Query Tool de pgAdmin en el pg_nodo1
ALTER SYSTEM SET wal_level = replica;

ALTER SYSTEM SET max_wal_senders = 10;

ALTER SYSTEM SET wal_keep_size = '64MB';

-- En este punto se debe reiniciar el nodo desde la terminar:
-- docker restart pg_nodo1

CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replica123';

-- Verificar que se creó:
SELECT rolname, rolreplication, rolcanlogin
FROM pg_roles
WHERE rolname = 'replicator';