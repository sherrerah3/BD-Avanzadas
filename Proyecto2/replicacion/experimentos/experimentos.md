# Experimentos

## Recomendaciones antes de los experimentos

**Crear las tablas en los 3 nodos** — desde la terminal, ubicándonos en `Proyecto2/scripts/`:

```bash
docker exec -i pg_nodo1 psql -U admin -d ecommerce < nodo1_schema.sql
docker exec -i pg_nodo2 psql -U admin -d ecommerce < nodo2_schema.sql
docker exec -i pg_nodo3 psql -U admin -d ecommerce < nodo3_schema.sql
```

**Configurar enrutamiento entre nodos** — en `Proyecto2/scripts/`:

```bash
docker exec -i pg_nodo1 psql -U admin -d ecommerce < 02_fdw_setup.sql
```

**Poblar con small data** — en `Proyecto2/scripts/`:

```bash
docker exec -i pg_nodo2 psql -U admin -d ecommerce < small_data/03a_poblar_nodo2_small.sql
docker exec -i pg_nodo3 psql -U admin -d ecommerce < small_data/03b_poblar_nodo3_small.sql
docker exec -i pg_nodo1 psql -U admin -d ecommerce < small_data/03c_poblar_nodo1_small.sql
```

---

## 1. Replicación síncrona vs asíncrona

Se experimenta con `synchronous_commit` entre su estado ON y OFF para medir qué tan lento se vuelve escribir cuando el primary espera confirmación de las réplicas antes de responderle al cliente.

Verificamos en qué modo estamos, asíncrono (`off`) o síncrono (`on`) — en el nodo primary:

```sql
SHOW synchronous_commit;
```

### Cambiar a modo asíncrono (cada línea por separado)

```sql
ALTER SYSTEM SET synchronous_commit = off;
```
```sql
ALTER SYSTEM SET synchronous_standby_names = '';
```
```sql
SELECT pg_reload_conf();
```

### Cambiar a modo síncrono (cada línea por separado)

```sql
ALTER SYSTEM SET synchronous_commit = on;
```
```sql
ALTER SYSTEM SET synchronous_standby_names = 'pg_replica1,pg_replica2';
```
```sql
SELECT pg_reload_conf();
```

### Verificar el estado de las réplicas

```sql
SELECT client_addr, application_name, state, sync_state
FROM pg_stat_replication;
```

> Si las réplicas aparecen con `sync_state = async`, ejecutar:
> ```sql
> ALTER SYSTEM SET synchronous_standby_names = 'FIRST 1 (*)';
> SELECT pg_reload_conf();
> ```

### Medir 500 inserts en modo asíncrono — en pg_nodo1

```sql
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
```

Resultado obtenido:

```
NOTICE: ASYNC: 10.093 ms
```

### Medir 500 inserts en modo síncrono — en pg_nodo1

```sql
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
```

Resultado obtenido:

```
NOTICE: SYNC: 16.307 ms
```

### Conclusión

Se puede visualizar que el modo síncrono es significativamente más lento que el modo asíncrono, ya que en este último se está esperando una confirmación por parte de la réplica del recibimiento del dato, lo que provoca mayor latencia. Esto también se ve influenciado por la velocidad de la réplica.

En cambio, en el modo asíncrono no se espera una confirmación por parte de la réplica para continuar la inserción de datos.

---

## 2. Caída del líder y promoción

### Registrar estado antes de la caída — en pg_nodo1

```sql
SELECT COUNT(*) AS total_usuarios FROM usuarios;
SELECT pg_current_wal_lsn();
```

Resultado obtenido:

| total_usuarios | pg_current_wal_lsn |
|---|---|
| 3000 | 0/522D248 |

### Simular la caída — desde la terminal

```bash
docker stop pg_nodo1
```

### Promover manualmente la réplica — desde la terminal

```bash
docker exec pg_replica1 su -c "pg_ctl promote -D /var/lib/postgresql/data" postgres
```

### Verificar que pg_replica1 tiene los atributos de un nodo primary — desde pg_replica1

```sql
-- Debe retornar false
SELECT pg_is_in_recovery();
```

### Comprobar que pg_replica1 ya no es de solo lectura — desde pg_replica1

```sql
INSERT INTO usuarios (nombre, email, region)
VALUES ('FailoverTest', 'failover@test.com', 'bogota');
```

```sql
-- Debe ser el conteo anterior + 1
SELECT COUNT(*) FROM usuarios;
```

Resultado:

| count |
|---|
| 3001 |

Como se puede ver, se pudo agregar un dato nuevo desde `pg_replica1`.

### Reconectar pg_replica2 al nuevo primary — desde la terminal

```bash
docker exec pg_replica2 bash -c "
echo \"primary_conninfo = 'host=pg_replica1 port=5432 user=replicator password=replica123'\" >> /var/lib/postgresql/data/postgresql.auto.conf
su -c 'pg_ctl reload -D /var/lib/postgresql/data' postgres
"
```

### Verificar que pg_replica2 aparece como streaming — desde pg_replica1

```sql
SELECT client_addr, state FROM pg_stat_replication;
```

Resultado:

| client_addr | state |
|---|---|
| 172.19.0.6 | streaming |

---

## 3. Prevención de split-brain

Esto más que un experimento, es una documentación sobre la prevención de split-brain en la promoción de réplicas.

### Antes de promover una réplica

Ejecutar en la misma réplica a promover:

```sql
SELECT
    pg_last_wal_receive_lsn() AS wal_recibido,
    pg_last_wal_replay_lsn()  AS wal_aplicado;
```

Si los dos valores son iguales, significa que la réplica está al día. De lo contrario, aún hay transacciones pendientes en la réplica y es conveniente esperar.

Adicionalmente, se debe verificar la realización de `docker stop pg_nodo1` antes de la promoción del nodo. También convendría hacer `docker ps` para verificar que no se encuentra `Up` el nodo1.

### Verificar que no hubo divergencia después del failover

En **pg_replica1** (ahora el primary):

```sql
SELECT pg_current_wal_lsn();
```

En **pg_replica2**:

```sql
SELECT pg_last_wal_replay_lsn();
```

Si los valores de las dos consultas son iguales o muy similares, no debe haber divergencia.

---

## 4. Latencia de lectura/escritura y número de réplicas

Se hacen múltiples consultas con `EXPLAIN ANALYZE` tanto en el primary (`pg_nodo1`) como en una de las réplicas (`pg_replica1`) para comparar el tiempo de ejecución y ver si desde la réplica es igual de rápido que desde el primary.

### Consulta 1 — Agregado por región

```sql
EXPLAIN ANALYZE
SELECT region, COUNT(*) AS total, AVG(id) AS promedio_id
FROM usuarios
GROUP BY region
ORDER BY total DESC;
```

Resultados:

| Nodo | Planning Time | Execution Time |
|---|---|---|
| pg_nodo1 | 0.127 ms | 1.472 ms |
| pg_replica1 | 0.225 ms | 1.779 ms |

### Consulta 2 — Filtro por región y fecha

```sql
EXPLAIN ANALYZE
SELECT *
FROM usuarios
WHERE region = 'medellin'
AND created_at >= NOW() - INTERVAL '365 days';
```

Resultados:

| Nodo | Planning Time | Execution Time |
|---|---|---|
| pg_nodo1 | 0.556 ms | 1.053 ms |
| pg_replica1 | 0.577 ms | 1.370 ms |

### Consulta 3 — Ordenar por fecha con límite

```sql
EXPLAIN ANALYZE
SELECT nombre, email, created_at
FROM usuarios
ORDER BY created_at DESC
LIMIT 100;
```

Resultados:

| Nodo | Planning Time | Execution Time |
|---|---|---|
| pg_nodo1 | 0.099 ms | 2.367 ms |
| pg_replica1 | 0.116 ms | 2.439 ms |

Se puede ver que la diferencia entre el nodo primario y la réplica no es muy amplia, pero en los 3 casos (y en la mayoría de veces que se realizan estas consultas) el nodo primario lleva la delantera en tiempo de ejecución, pero solo por un poco.

---

### Impacto del número de réplicas

Para probar la diferencia de velocidad en un insert cuando hay 2 réplicas activas a comparación de cuando hay solo una, se cambia a **modo síncrono**.

#### Con 2 réplicas activas — en pg_nodo1

```sql
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
```

Resultado:

```
NOTICE: 2 replicas: 21.434 ms
```

#### Con 1 sola réplica

Apagamos una de las dos réplicas:

```bash
docker stop pg_replica2
```

```sql
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
```

Resultado:

```
NOTICE: 1 replica: 10.652 ms
```

### Conclusión

Con una réplica, el sync es mucho más rápido ya que solo requiere de la confirmación de un nodo, y no de dos.