-- =======================================================
-- TWO-PHASE COMMIT (2PC) MANUAL 
-- Escenario: Checkout usuario_id = 100002
--
-- orden  → ordenes_nodo0 → vive en NODO 1 (INSERT directo)
-- pago   → pagos         → vive en NODO 3 (INSERT directo)
--
-- IMPORTANTE: Ejecutar cada bloque en el nodo indicado.
-- No usar el coordinador FDW — PostgreSQL no permite
-- PREPARE TRANSACTION en sesiones que usen tablas foráneas.
-- =======================================================


-- ═══════════════════════════════════════════════════════
-- EXPERIMENTO 1: 2PC EXITOSO
-- ═══════════════════════════════════════════════════════

-- ─────────────────────────────────────────
-- PASO 1 — En NODO 1: preparar la orden
-- (INSERT directo en ordenes_nodo0, sin FDW)
-- ─────────────────────────────────────────

BEGIN;

INSERT INTO ordenes_nodo0 (id, usuario_id, fecha, estado, total)
VALUES (999001, 100002, NOW(), 'pendiente', 150000);

PREPARE TRANSACTION 'txn_checkout_001';

-- Verificar que quedó preparada
SELECT gid, prepared, owner, database
FROM pg_prepared_xacts;


-- ─────────────────────────────────────────
-- PASO 2 — En NODO 3: preparar el pago
-- (INSERT directo en pagos, sin FDW)
-- ─────────────────────────────────────────

BEGIN;

INSERT INTO pagos (orden_id, metodo, estado, fecha, monto)
VALUES (999001, 'tarjeta', 'aprobado', NOW(), 150000);

PREPARE TRANSACTION 'txn_checkout_001';

-- Verificar que quedó preparada
SELECT gid, prepared, owner, database
FROM pg_prepared_xacts;


-- ─────────────────────────────────────────
-- PASO 3 — Fase 2: COMMIT en ambos nodos
-- Coordinador decide: ambos prepararon → confirmar
-- ─────────────────────────────────────────

-- En NODO 1:
COMMIT PREPARED 'txn_checkout_001';

-- En NODO 3:
COMMIT PREPARED 'txn_checkout_001';


-- ─────────────────────────────────────────
-- PASO 4 — Verificar resultado
-- ─────────────────────────────────────────

-- En NODO 1: la orden debe existir
SELECT * FROM ordenes_nodo0 WHERE id = 999001;

-- En NODO 3: el pago debe existir
SELECT * FROM pagos WHERE orden_id = 999001;

-- En ambos nodos: pg_prepared_xacts debe estar vacío
SELECT * FROM pg_prepared_xacts;



-- ═══════════════════════════════════════════════════════
-- EXPERIMENTO 2: FALLO DEL COORDINADOR TRAS EL PREPARE
-- Escenario crítico pedido por el enunciado
-- ═══════════════════════════════════════════════════════

-- ─────────────────────────────────────────
-- PASO 1 — En NODO 1: preparar nueva orden
-- ─────────────────────────────────────────

BEGIN;

INSERT INTO ordenes_nodo0 (id, usuario_id, fecha, estado, total)
VALUES (999002, 100002, NOW(), 'pendiente', 250000);

PREPARE TRANSACTION 'txn_checkout_002';


-- ─────────────────────────────────────────
-- PASO 2 — En NODO 3: preparar el pago
-- ─────────────────────────────────────────

BEGIN;

INSERT INTO pagos (orden_id, metodo, estado, fecha, monto)
VALUES (999002, 'pse', 'pendiente', NOW(), 250000);

PREPARE TRANSACTION 'txn_checkout_002';


-- ─────────────────────────────────────────
-- PASO 3 — SIMULAR FALLO DEL COORDINADOR
-- Ambos nodos están preparados. Ahora matar Nodo 1.
-- Desde tu terminal WSL:
--
--   docker stop pg_nodo1
-- ─────────────────────────────────────────


-- ─────────────────────────────────────────
-- PASO 4 — Con Nodo 1 caído, verificar bloqueo en NODO 3
-- ─────────────────────────────────────────

-- La transacción sigue preparada y bloqueando recursos
SELECT gid, prepared, owner, database
FROM pg_prepared_xacts;

-- Intentar insertar otro pago para la misma orden → bloqueado
BEGIN;
INSERT INTO pagos (orden_id, metodo, estado, fecha, monto)
VALUES (999002, 'efectivo', 'pendiente', NOW(), 250000);
-- Esta sesión quedará colgada esperando el lock
-- Cancelar con:
ROLLBACK;


-- ─────────────────────────────────────────
-- PASO 5 — Recuperar Nodo 1
-- Desde tu terminal WSL:
--
--   docker start pg_nodo1
--
-- Verificar en NODO 1 que el prepare sobrevivió el crash:
-- ─────────────────────────────────────────

SELECT gid, prepared, owner, database
FROM pg_prepared_xacts;
-- txn_checkout_002 sigue aquí — el PREPARE se escribió en WAL
-- y sobrevivió el reinicio del contenedor


-- ─────────────────────────────────────────
-- PASO 6 — Decisión final del coordinador recuperado
-- ─────────────────────────────────────────

-- OPCIÓN A: Confirmar la compra (todo estaba bien)
-- En NODO 1:
COMMIT PREPARED 'txn_checkout_002';
-- En NODO 3:
COMMIT PREPARED 'txn_checkout_002';

-- Verificar
SELECT * FROM ordenes_nodo0 WHERE id = 999002;
SELECT * FROM pagos WHERE orden_id = 999002;

-- OPCIÓN B: Cancelar la compra (algo falló)
-- En NODO 1:
-- ROLLBACK PREPARED 'txn_checkout_002';
-- En NODO 3:
-- ROLLBACK PREPARED 'txn_checkout_002';
