# Persona 3 — Cluster NewSQL con CockroachDB

**EAFIT - Bases de Datos Avanzadas | Unidad 2**

## Descripcion

Este repositorio contiene la implementacion de la Persona 3 del proyecto de bases de datos distribuidas. Se levanta un cluster NewSQL de 3 nodos con CockroachDB en Docker, se carga el dataset del equipo (10% del dataset completo) y se realizan experimentos de latencia, consistencia y tolerancia a fallas.

---

## Diagrama de arquitectura

```
┌─────────────────────────────────────────────────────┐
│                   Docker Network                     │
│                  (cockroachnet)                      │
│                                                      │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐       │
│  │  roach1  │◄──►│  roach2  │◄──►│  roach3  │       │
│  │          │    │          │    │          │       │
│  │ :26257   │    │ :26258   │    │ :26259   │       │
│  │ :8080    │    │ :8081    │    │ :8082    │       │
│  └──────────┘    └──────────┘    └──────────┘       │
│       │               │               │             │
│       └───────────────┴───────────────┘             │
│                   Raft Consensus                     │
│              replicas: {1, 2, 3}                    │
│              leaseholder: nodo 3                    │
└─────────────────────────────────────────────────────┘
```

**Motor:** CockroachDB v26.1.1
**Nodos:** 3 (roach1, roach2, roach3)
**Replicacion:** Automatica en los 3 nodos (factor 3)
**Consenso:** Protocolo Raft
**Consistencia:** Serializable (linealizable)

---

## Estructura del repositorio

```
/
├── infra/
│   └── docker-compose.yml       # Cluster de 3 nodos CockroachDB
├── scripts/
│   ├── 01_schema_cockroachdb.sql    # Creacion de tablas
│   ├── 02_dataset_cockroachdb.sql   # Generacion de datos (10%)
│   └── 03_experimentos_cockroachdb.sql  # Experimentos de Raft y latencia
└── README.md
```

---

## Requisitos previos

- Windows 10/11 AMD64
- WSL 2 instalado (`wsl --install`)
- Docker Desktop v29+ con WSL2 backend

Verificar arquitectura:
```powershell
(Get-WmiObject Win32_Processor).Architecture
# 9 = AMD64, 12 = ARM64
```

Verificar Docker:
```powershell
docker --version
docker compose version
```

---

## Levantar el cluster

```powershell
cd infra/
docker compose up -d

# Solo la primera vez:
docker exec -it roach1 ./cockroach init --insecure --cluster-name=cluster1
```

Verificar nodos:
```powershell
docker exec -it roach1 ./cockroach node status --insecure --host=localhost:26257
```

Resultado esperado: 3 nodos con `is_available=true` e `is_live=true`.

UI web: http://localhost:8080

---

## Cargar el dataset

Crear la base de datos:
```powershell
docker exec -it roach1 ./cockroach sql --insecure --host=localhost:26257 --execute="CREATE DATABASE ecommerce;"
```

Crear tablas:
```powershell
docker exec -it roach1 ./cockroach sql --insecure --host=localhost:26257 -f scripts/01_schema_cockroachdb.sql
```

Insertar datos (ejecutar por tabla — ver `02_dataset_cockroachdb.sql` para los comandos completos):

| Tabla | Filas | Tiempo aprox. |
|-------|-------|---------------|
| customer | 100,000 | ~1 min |
| product | 10,000 | ~5 seg |
| orders | 500,000 | ~8 seg |
| order_item | 2,000,000 | ~40 seg |
| payment | 400,000 | ~12 seg |
| **TOTAL** | **3,010,000** | **~2 min** |

---

## Experimentos de Raft

### Ver auto-sharding y leaseholder

```powershell
docker exec -it roach1 ./cockroach sql --insecure --host=localhost:26257 --execute="SHOW RANGES FROM DATABASE ecommerce WITH DETAILS;"
```

**Resultado observado con 196MB de datos:**
- `range_id: 81`
- `lease_holder: 3` (Nodo 3 coordina todas las operaciones)
- `replicas: {1,2,3}` (replicado automaticamente en los 3 nodos)

### Transferir leaseholder

```powershell
docker exec -it roach1 ./cockroach sql --insecure --host=localhost:26257 --execute="ALTER RANGE 81 RELOCATE LEASE TO 1;"
```

### Experimentos de quorum Raft

```powershell
# Pausar un nodo (quorum mantenido — 2 de 3)
docker pause roach2

# Consulta sigue funcionando
docker exec -it roach1 ./cockroach sql --insecure --host=localhost:26257 --execute="SELECT COUNT(*) FROM ecommerce.orders;"

# Pausar segundo nodo (quorum perdido)
docker pause roach3

# Consulta falla: ERROR: lost quorum
docker exec -it roach1 ./cockroach sql --insecure --host=localhost:26257 --execute="SELECT COUNT(*) FROM ecommerce.orders;"

# Recuperar nodos
docker unpause roach2
docker unpause roach3

# Consulta se recupera automaticamente
docker exec -it roach1 ./cockroach sql --insecure --host=localhost:26257 --execute="SELECT COUNT(*) FROM ecommerce.orders;"
```

---

## Resultados de experimentos

### Latencia con 3,010,000 filas

| Operacion | Tiempo | Notas |
|-----------|--------|-------|
| JOIN customer + orders (600K filas) | 344ms | Sin indices, full scan |
| GROUP BY en orders (500K filas) | 272ms | Agregacion distribuida |
| INSERT single row | 4ms | Incluye replicacion 3 nodos |
| Consulta por PK | 2ms | Lookup directo |

### Tolerancia a fallas

| Escenario | Resultado |
|-----------|-----------|
| 1 nodo caido (1 de 3) | Sistema funciona — quorum mantenido |
| 2 nodos caidos (2 de 3) | ERROR: lost quorum — sistema bloqueado |
| Recuperacion | Automatica, sin intervencion manual |

### Consistencia

CockroachDB garantiza **consistencia linealizable** (nivel serializable). Un dato escrito en roach1 es inmediatamente visible en roach2 y roach3.

---

## Hallazgos tecnicos

### Diferencias con PostgreSQL

| Aspecto | PostgreSQL | CockroachDB |
|---------|-----------|-------------|
| ENUM types | CREATE TYPE ... AS ENUM | No soporta DO $$/DROP TYPE — usar TEXT |
| IDs SERIAL | Secuencial (1, 2, 3...) | Distribuido (IDs largos) — usar IDs explicitos |
| Replicacion | Manual (streaming replication) | Automatica (factor 3 por defecto) |
| Particionamiento | Manual (PARTITION BY) | Auto-sharding automatico |
| Consistencia | Configurable | Serializable por defecto |
| Quorum | No aplica | Raft — necesita mayoria (2 de 3) |

### Limitaciones encontradas

- `tc netem`: no disponible en contenedores CockroachDB ni en kernel WSL2
- Pumba: no descargable en redes universitarias con restricciones
- Solucion aplicada: `docker pause` para simular fallas de nodo

---

## Detener el cluster

```powershell
docker compose down

# Para eliminar tambien los volumenes (datos):
docker compose down -v
```
