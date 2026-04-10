# Guia de establecimiento de nodo Primary y los dos nodos réplica

## 1. Agregar dos nodos réplicas al docker compose

Se definen dos nuevos contenedores llamados `pg_replica1` y `pg_replica2` en el archivo `infra/docker-compose.yaml` (ESTO YA SE ENCUENTRA APLICADO EN EL ARCHIVO):

```yaml
replica1:
  image: postgres:17
  container_name: pg_replica1
  environment:
    POSTGRES_USER: admin
    POSTGRES_PASSWORD: admin123
  ports:
    - "5436:5432"
  volumes:
    - replica1_data:/var/lib/postgresql/data
  networks:
    - pg_network

replica2:
  image: postgres:17
  container_name: pg_replica2
  environment:
    POSTGRES_USER: admin
    POSTGRES_PASSWORD: admin123
  ports:
    - "5437:5432"
  volumes:
    - replica2_data:/var/lib/postgresql/data
  networks:
    - pg_network
```

---

## 2. Levantar contenedores

Nos paramos en `Proyecto2/infra/` y ejecutamos:

```bash
docker compose up -d
```

---

## 3. Configurar el nodo 1 como Primary para la replicación

Nos dirigimos a la Query Tool del nodo 1 en pgAdmin y ejecutamos los comandos en `replicacion/01_configurar_primary.sql` **en orden y separadamente**:

```sql
ALTER SYSTEM SET wal_level = replica;
```
```sql
ALTER SYSTEM SET max_wal_senders = 10;
```
```sql
ALTER SYSTEM SET wal_keep_size = '64MB';
```

En este punto reiniciamos el nodo 1 desde la terminal:

```bash
docker restart pg_nodo1
```

Creamos el rol replicator para la replicación:

```sql
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replica123';
```

Verificación de que se creó (esto sí todo junto):

```sql
SELECT rolname, rolreplication, rolcanlogin
FROM pg_roles
WHERE rolname = 'replicator';
```

Resultado esperado:

| rolname | rolreplication | rolcanlogin |
|---|---|---|
| replicator | t | t |

---

## 4. Configurar las réplicas

Ejecutamos en la terminal, posicionados en `Proyecto2/`:

```bash
bash replicacion/02_setup_replicas.sh
```

Seguir las instrucciones que salgan en la consola.

### Notas

- Cuando al principio se pida añadir `host replication replicator 0.0.0.0/0 md5`, se debe asegurar de que se haga en la **última línea** y guardar el archivo (**Ctrl + S**)
- Cuando se pida la contraseña, recordar que es `replica123` y procurar no tardar mucho en ingresarla (esta se pide 2 veces)

---

## Comprobación

**1. Verificar que los contenedores están corriendo:**

```bash
docker ps
```

Tanto `pg_replica1` como `pg_replica2` deben estar `Up`.

**2. Verificar streaming desde el primary** — ejecutar en pg_nodo1:

```sql
SELECT client_addr, state FROM pg_stat_replication;
```

Resultado esperado:

| client_addr | state |
|---|---|
| 172.19.0.7 | streaming |
| 172.19.0.6 | streaming |

**3. Verificar modo solo lectura** — ejecutar en cada réplica:

```sql
SELECT pg_is_in_recovery();
```

Resultado esperado:

| pg_is_in_recovery |
|---|
| true |

> Para verificaciones adicionales, referirse al archivo `replicacion/03_verificar_replicas.sql`