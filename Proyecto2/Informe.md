# Proyecto 2 — Arquitecturas Distribuidas
## SI3009 Bases de Datos Avanzadas, 2026-1
### Persona 1: Infraestructura PostgreSQL + Particionamiento + 2PC

---

## 1. Contexto del dominio

Trabajamos con un sistema de **ecommerce** como dominio de aplicación. Escogimos este dominio porque permite demostrar de forma natural los conceptos de distribución: los usuarios hacen órdenes constantemente, los pagos deben ser atómicos con las órdenes, y el volumen de datos crece rápido.

Reutilizamos el dominio del Proyecto 1 para enfocarnos en los aspectos distribuidos, extendiendo el modelo de datos para soportar particionamiento y transacciones distribuidas.

---

## 2. Modelo de datos

El sistema tiene 5 tablas principales:

| Tabla | Descripción | Nodo principal | Estrategia de particionamiento |
|---|---|---|---|
| `usuarios` | Clientes registrados | Nodo 1 | Sin particionar |
| `productos` | Catálogo con stock | Nodo 2 | Sin particionar |
| `ordenes` | Cabecera de cada compra | Los 3 nodos | Hash por `usuario_id` |
| `order_items` | Líneas de cada orden | Los 3 nodos | Hash por `orden_id` |
| `pagos` | Registro de pago por orden | Nodo 3 | Rango por `fecha` |

**Por qué este diseño:**
- `ordenes` y `order_items` se distribuyen por hash para balancear la carga uniformemente entre nodos. El hash garantiza que todas las órdenes de un mismo usuario caigan en el mismo nodo, lo que hace eficientes las consultas de historial.
- `pagos` se particiona por rango de fecha porque los reportes financieros siempre consultan por períodos. Esto permite que el motor descarte particiones completas en queries analíticas (partition pruning por rango).
- No se usan llaves foráneas entre tablas de nodos distintos porque PostgreSQL no puede enforzarlas entre nodos independientes — este es uno de los trade-offs documentados más adelante.

### Diagrama entidad-relación

```
USUARIOS ||--o{ ORDENES : "realiza"
ORDENES  ||--|{ ORDER_ITEMS : "contiene"
PRODUCTOS ||--o{ ORDER_ITEMS : "aparece en"
ORDENES  ||--o| PAGOS : "se paga con"
```

---

## 3. Volúmenes estimados

| Tabla | Filas objetivo | Filas cargadas | Justificación |
|---|---|---|---|
| `usuarios` | 100.000 | 10.000 | Base de clientes activos |
| `productos` | 10.000 | 1.000 | Catálogo típico |
| `ordenes` | 5.000.000 | 500.000 | ~50 órdenes por usuario |
| `order_items` | 15.000.000 | 1.500.000 | ~3 ítems por orden |
| `pagos` | 5.000.000 | 500.000 | 1 pago por orden |

> Los datos se generaron con scripts SQL usando `generate_series()` de PostgreSQL. Por restricciones de recursos en entorno local (Docker), se trabajó con el 10% del volumen objetivo. La arquitectura y los experimentos son equivalentes y escalables a los volúmenes completos.

---

## 4. Operaciones OLTP y OLAP

**OLTP** (transacciones del día a día, alta frecuencia):
- Registrar nueva orden + pago (escenario del 2PC)
- Consultar estado de una orden por `usuario_id`
- Actualizar stock de un producto
- Cancelar una orden y revertir el pago

**OLAP** (consultas analíticas, cruzan particiones):
- Total de ventas por mes y región
- Productos más vendidos por categoría
- Órdenes completadas vs canceladas por período
- Ingreso promedio por usuario

---

## 5. Infraestructura

### Arquitectura

Levantamos 3 instancias independientes de PostgreSQL 17 usando Docker Compose, simulando 3 nodos físicos en una misma red virtual:

```
┌─────────────────────────────────────────────┐
│              Red Docker: pg_network          │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Nodo 1  │  │  Nodo 2  │  │  Nodo 3  │  │
│  │ :5433    │  │ :5434    │  │ :5435    │  │
│  │          │  │          │  │          │  │
│  │ usuarios │  │productos │  │  pagos   │  │
│  │ordenes_0 │  │ordenes_1 │  │ordenes_2 │  │
│  │items_0   │  │items_1   │  │items_2   │  │
│  └──────────┘  └──────────┘  └──────────┘  │
│                                             │
│  ┌──────────┐                               │
│  │ PgAdmin  │  :5050                        │
│  └──────────┘                               │
└─────────────────────────────────────────────┘
```

**Nodo 1** actúa como coordinador — tiene configurado `postgres_fdw` para ver las particiones de Nodo 2 y Nodo 3 como si fueran locales.

### Levantar el ambiente

Para evitar duplicar comandos en este documento, la ejecución operativa se referencia a archivos fuente:

- `docker compose up`, `docker compose ps` y puertos/servicios: `infra/docker-compose.yaml`
- Definición de esquema por nodo: `scripts/schemas/nodo1_schema.sql`, `scripts/schemas/nodo2_schema.sql`, `scripts/schemas/nodo3_schema.sql`
- Conexiones FDW y attach de particiones remotas: `scripts/02_fdw_setup.sql`

PgAdmin disponible en `http://localhost:5050` — `admin@admin.com` / `admin`

---

## 6. Particionamiento

### Configuración

Usamos dos estrategias de particionamiento según la tabla:

**Hash en `ordenes` y `order_items`** — distribuye filas uniformemente según el hash del campo clave. Cada nodo recibe aproximadamente el mismo número de filas sin importar el patrón de uso.

**Rango en `pagos`** — divide los datos por períodos de tiempo, ideal para queries analíticas que filtran por fecha.

La implementación completa de estas particiones está en `scripts/schemas/nodo1_schema.sql`, `scripts/schemas/nodo2_schema.sql` y `scripts/schemas/nodo3_schema.sql`.

### Resultado de la distribución

Después de insertar 500.000 órdenes y 1.500.000 order_items desde el Nodo 1 coordinador:

**Distribución de `ordenes`:**
| Partición | Filas | Porcentaje |
|---|---|---|
| `ordenes_nodo0` (Nodo 1) | 163850 | 32.77% |
| `ordenes_nodo1` (Nodo 2) | 168450 | 33.69% |
| `ordenes_nodo2` (Nodo 3) | 167700 | 33.54% |

**Distribución de `order_items`:**
| Partición | Filas | Porcentaje |
|---|---|---|
| `order_item_nodo0` (Nodo 1) | 501990 | 33.47% |
| `order_item_nodo1` (Nodo 2) | 499218 | 33.28% |
| `order_item_nodo2` (Nodo 3) | 498792 | 33.25% |

La distribución es casi perfecta en ambas tablas; el hash cumple su objetivo de balancear la carga entre nodos.

### Enrutamiento manual

Una limitación importante de PostgreSQL es que **no es un motor distribuido nativo**. La aplicación o el DBA debe saber en qué nodo vive cada dato. Implementamos esto usando `postgres_fdw` (Foreign Data Wrapper):

La configuración FDW (servers, user mappings, foreign tables y `ATTACH PARTITION`) está documentada y ejecutable en `scripts/02_fdw_setup.sql`.

Con esto el Nodo 1 puede insertar en `ordenes` y el motor enruta automáticamente cada fila al nodo correcto. Esto es lo más parecido a la "transparencia" que ofrece un NewSQL, pero implementado manualmente.

**Limitación encontrada:** PostgreSQL no permite PRIMARY KEY en tablas particionadas cuando alguna partición es una tabla foránea (FOREIGN TABLE). La razón es que el motor no puede garantizar unicidad global entre nodos que no controla directamente. Tuvimos que reemplazar el PRIMARY KEY por un índice simple. Este es uno de los costos concretos de la distribución manual.

---

## 7. Joins distribuidos — EXPLAIN ANALYZE

Un join distribuido es una consulta que necesita datos de particiones en distintos nodos. Por ejemplo, pedir órdenes con nombre de usuario implica cruzar `ordenes` (distribuida en 3 nodos) con `usuarios` (solo en Nodo 1).

Todas las consultas y comandos de esta sección están en: `scripts/05_joins_distribuidos_explain_analyze.sql`.

### Consulta 1 — Join simple (órdenes con nombre de usuario)

**Tiempo total:** 208 ms.

Cruza `ordenes` (3 particiones distribuidas) con `usuarios` (local Nodo 1), filtrando por estado `completada` y ordenando por fecha.

| Operación | Tiempo |
|---|---|
| `Seq Scan on ordenes_nodo0` (local) | 22 ms |
| `Foreign Scan on ordenes_nodo1` (remoto vía FDW) | 439 ms |
| `Foreign Scan on ordenes_nodo2` (remoto vía FDW) | 399 ms |

**Conclusión:** el acceso remoto cuesta aproximadamente 20x más que el local. El coordinador ensambla los resultados de los nodos y los ordena globalmente.

### Consulta 2 — Join triple (órdenes + usuarios + order_items)

**Tiempo total:** 4.718 ms.

Cruza `ordenes`, `usuarios` y `order_items`, y calcula el total por orden.

- Los dos `Foreign Scan` de `order_items` suman 2.459 ms
- `HashAggregate` reporta `Disk Usage: 30.648 kB` (la agregación de ~449k filas desbordó memoria y usó disco)
- El filtro de fecha en `ordenes_nodo1` y `ordenes_nodo2` se ejecuta en el nodo remoto (pushdown)

**Conclusión:** los joins sobre múltiples tablas distribuidas multiplican el costo de red. El spill a disco en la agregación es otro trade-off de trabajar con volúmenes reales en un motor no nativo distribuido.

### Consulta 3 — Query OLAP (ventas por región y mes)

**Tiempo total:** 734 ms.

Agrega ingresos por región y mes para el período 2025-2026.

- `Seq Scan` local: 20 ms
- `Foreign Scan` nodo 1: 234 ms
- `Foreign Scan` nodo 2: 216 ms
- El filtro de fecha y estado se empuja al nodo remoto en los `Foreign Scan` (pushdown)

**Conclusión:** las consultas OLAP con filtros selectivos se benefician del pruning temporal y del pushdown, reduciendo el volumen transferido entre nodos.

### Consulta 4 — Partition pruning hash

**Tiempo total:** 3.9 ms.

Busca las órdenes de un usuario específico (`usuario_id = 100042`).

- Solo toca 1 partición de 3: `ordenes_nodo1`
- PostgreSQL calcula `hash(100042) % 3 = 1` en planificación y descarta las otras dos particiones

**Conclusión:** el partition pruning con hash funciona también con particiones remotas y reduce el tiempo alrededor de 53x frente a un full scan.

---

## 8. Transacciones distribuidas — 2PC

### Por qué no podemos usar el coordinador FDW para el 2PC

PostgreSQL no permite ejecutar `PREPARE TRANSACTION` en una sesión que haya interactuado con tablas foráneas vía FDW. El motor no puede garantizar que el nodo remoto participe correctamente en las dos fases. Por esto, cada fase del 2PC debe ejecutarse **directamente en el nodo físico** donde viven los datos, sin pasar por el FDW.

### Escenario implementado

Un checkout de ecommerce: el usuario `100002` realiza una compra.

- La orden cae en `ordenes_nodo0` → **Nodo 1** (calculado con `hash(100002) % 3 = 0`)
- El pago siempre va a **Nodo 3**

Dos nodos físicos distintos — escenario real de transacción distribuida.

### Experimento 1 — 2PC exitoso

**Fase 1 — Prepare (en cada nodo):** ver `scripts/06_two_phase_commit_manual.sql`.

Después del PREPARE, `pg_prepared_xacts` en ambos nodos muestra la transacción pendiente. Los datos **no son visibles** aún para otras sesiones.

**Fase 2 — Commit:** ver `scripts/06_two_phase_commit_manual.sql`.

**Resultado:** orden `999001` y pago `400001` confirmados en sus respectivos nodos. `pg_prepared_xacts` vacío en ambos.

### Experimento 2 — Fallo del coordinador tras el Prepare

Este es el escenario crítico que expone la principal debilidad del 2PC en PostgreSQL.

**Secuencia:**

1. Ambos nodos preparan `txn_checkout_002` exitosamente
2. `docker stop pg_nodo1` — coordinador caído
3. Nodo 3 sigue mostrando `txn_checkout_002` en `pg_prepared_xacts` — **recursos bloqueados**
4. Intento de otro INSERT sobre `orden_id = 999002` en Nodo 3 — tardó **19 segundos** esperando el lock
5. `docker start pg_nodo1` — coordinador recuperado
6. `pg_prepared_xacts` en Nodo 1 sigue mostrando `txn_checkout_002` — **el PREPARE sobrevivió el crash** gracias al WAL
7. COMMIT final en ambos nodos — orden `999002` y pago `400002` confirmados

**Conclusión del experimento:** cuando el coordinador falla después de la Fase 1, los recursos quedan bloqueados indefinidamente. Ningún nodo puede tomar la decisión de forma autónoma. El tiempo de indisponibilidad depende del tiempo de recuperación del coordinador — no existe un mecanismo automático de resolución.

---

## 9. Análisis crítico

### Lo que aprendimos de PostgreSQL distribuido

Implementar distribución manualmente en PostgreSQL es posible, pero costoso en términos de complejidad. Durante el proyecto encontramos estas fricciones concretas:

**Diseño:** tuvimos que tomar decisiones explícitas sobre dónde vive cada tabla, qué estrategia de particionamiento usar, y cómo configurar el FDW. En un NewSQL como CockroachDB, estas decisiones son automáticas.

**Constraints:** no podemos tener llaves foráneas entre nodos ni PRIMARY KEY en tablas particionadas con particiones foráneas. Esto significa que la integridad referencial es responsabilidad de la aplicación, no de la base de datos.

**2PC:** no funciona a través del FDW. El DBA debe conocer en qué nodo físico vive cada dato para ejecutar el PREPARE directamente. Esto rompe la transparencia de distribución.

**Rendimiento:** el acceso remoto vía FDW cuesta ~20x más que el acceso local. En una tabla con millones de filas distribuidas, más del 50% del tiempo de una query compleja es latencia de red.

### Comparación con NewSQL (anticipando los resultados de Persona 3)

| Aspecto | PostgreSQL + FDW | CockroachDB / YugabyteDB |
|---|---|---|
| Particionamiento | Manual, configurado por el DBA | Automático (auto-sharding) |
| Enrutamiento | Explícito vía FDW | Transparente para la aplicación |
| 2PC | Funciona, pero no a través de FDW | Nativo, sin restricciones |
| Fallo del coordinador | Bloqueo indefinido hasta recuperación manual | Raft elige nuevo líder automáticamente |
| Integridad referencial | Responsabilidad de la aplicación | Garantizada por el motor |
| Complejidad operacional | Alta — el DBA debe entender la topología | Baja — el motor abstrae la distribución |

### Impacto en costos

Implementar y operar una arquitectura distribuida manual con PostgreSQL tiene costos que van más allá del hardware:

**Costos de implementación:** el tiempo de configuración del FDW, diseño del esquema de particionamiento, y scripts de enrutamiento es significativo. En este proyecto nos tomó varios días llegar a un ambiente funcional.

**Costos operacionales:** cualquier cambio en la topología (agregar un nodo, mover particiones) requiere intervención manual del DBA. Un sistema NewSQL administrado en nube (como CockroachDB Cloud o Amazon Aurora) delega toda esa complejidad al proveedor.

**Reflexión final:** PostgreSQL distribuido con FDW es una solución válida cuando se necesita control granular sobre la distribución de datos y se tiene el equipo técnico para operarlo. Para la mayoría de casos de uso empresariales, un NewSQL o un servicio administrado en nube ofrece mejor relación entre complejidad y beneficio. Como decimos en el proyecto: no todo lo distribuido es automáticamente mejor.

---

