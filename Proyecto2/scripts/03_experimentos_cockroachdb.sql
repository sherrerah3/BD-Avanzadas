-- 03_experimentos_cockroachdb.sql
-- Persona 3 — Experimentos de latencia, consistencia y Raft
-- EAFIT - Bases de Datos Avanzadas

-- ============================================================
-- 1. AUTO-SHARDING: ver distribucion de rangos
-- ============================================================

SHOW RANGES FROM DATABASE ecommerce WITH DETAILS;

SHOW RANGES FROM TABLE ecommerce.orders WITH DETAILS;
SHOW RANGES FROM TABLE ecommerce.customer WITH DETAILS;

-- ============================================================
-- 2. PROTOCOLO RAFT: leaseholder
-- ============================================================

-- Ver leaseholder actual
SHOW RANGES FROM DATABASE ecommerce WITH DETAILS;

-- Transferir leaseholder al nodo 1
ALTER RANGE 81 RELOCATE LEASE TO 1;

-- Verificar transferencia
SHOW RANGES FROM TABLE ecommerce.orders WITH DETAILS;

-- Regresar leaseholder al nodo 3
ALTER RANGE 81 RELOCATE LEASE TO 3;

-- ============================================================
-- 3. EXPERIMENTOS DE LATENCIA
-- ============================================================

-- Lectura simple con filtro
SELECT city, COUNT(*) as total
FROM ecommerce.customer
WHERE city = 'Medellin';

-- JOIN distribuido (600K filas)
SELECT c.city, COUNT(o.order_id) as total_ordenes, SUM(o.total_amount) as ingresos
FROM ecommerce.customer c
JOIN ecommerce.orders o ON c.customer_id = o.customer_id
GROUP BY c.city
ORDER BY ingresos DESC;

-- Agregacion en orders (500K filas)
SELECT status, COUNT(*) as total, AVG(total_amount) as promedio
FROM ecommerce.orders
GROUP BY status
ORDER BY total DESC;

-- Escritura individual
INSERT INTO ecommerce.customer (customer_id, name, email, city)
VALUES (999999999, 'Test Perf', 'test@perf.com', 'Medellin');

-- Limpieza
DELETE FROM ecommerce.customer WHERE customer_id = 999999999;

-- ============================================================
-- 4. EXPLAIN ANALYZE — plan de ejecucion del JOIN
-- ============================================================

EXPLAIN ANALYZE
SELECT c.city, COUNT(o.order_id) as total_ordenes, SUM(o.total_amount) as ingresos
FROM ecommerce.customer c
JOIN ecommerce.orders o ON c.customer_id = o.customer_id
GROUP BY c.city
ORDER BY ingresos DESC;

-- ============================================================
-- 5. CONSISTENCIA LINEALIZABLE
-- ============================================================

-- Paso 1: Escribir en roach1 (ejecutar conectado a roach1)
INSERT INTO ecommerce.product (product_id, name, category, price)
VALUES (99999, 'Producto Consistencia Test', 'test', 9.99);

-- Paso 2: Leer desde roach2 (ejecutar conectado a roach2)
-- docker exec -it roach2 ./cockroach sql --insecure --host=roach2:26257
SELECT * FROM ecommerce.product WHERE product_id = 99999;
-- Resultado esperado: aparece inmediatamente (consistencia linealizable)

-- Limpieza
DELETE FROM ecommerce.product WHERE product_id = 99999;

-- ============================================================
-- 6. SIMULACION DE FALLAS (ejecutar desde PowerShell)
-- ============================================================
-- Ver README.md seccion "Experimentos de quorum Raft"
--
-- docker pause roach2
-- [ejecutar consulta]
-- docker pause roach3
-- [ejecutar consulta — debe fallar con "lost quorum"]
-- docker unpause roach2
-- docker unpause roach3
-- [ejecutar consulta — debe recuperarse automaticamente]
