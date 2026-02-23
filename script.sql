
-- Q1: Ventas por ciudad en un año
-- Escaneo costoso si no hay índices en orders.order_date ni orders.customer_id.
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.city, SUM(o.total_amount) AS total_sales
FROM customer c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date >= TIMESTAMPTZ '2023-01-01'
  AND o.order_date <  TIMESTAMPTZ '2024-01-01'
GROUP BY c.city
ORDER BY total_sales DESC;

-- -----------------------------------------------------------------------------

-- Q2: Top productos vendidos (agregación masiva)
-- Evalúa el performance de joins entre tablas de gran volumen (order_item y product).
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.name, SUM(oi.quantity) AS total_sold
FROM order_item oi
JOIN product p ON oi.product_id = p.product_id
GROUP BY p.name
ORDER BY total_sold DESC
LIMIT 10;

-- -----------------------------------------------------------------------------

-- Q3: Dashboard: últimas órdenes de un cliente (filtro + sort)
-- Clave para verificar si existe un índice compuesto (customer_id, order_date).
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE customer_id = 12345
ORDER BY order_date DESC
LIMIT 20;

-- -----------------------------------------------------------------------------

-- Q4: Degradación típica: LIKE con comodín inicial (No SARGable)
-- El comodín '%' al inicio suele invalidar índices B-Tree estándar.
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM product
WHERE name ILIKE '%42%'
LIMIT 50;

-- -----------------------------------------------------------------------------

-- Q5: Anti-pattern: Función sobre columna en WHERE
-- Aplicar date_trunc impide que el optimizador use índices normales en order_date.
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM orders
WHERE date_trunc('day', order_date) = TIMESTAMPTZ '2023-11-15';

-- -----------------------------------------------------------------------------

-- Q6: Join + filtro por status (sin índices)
-- Analiza la eficiencia del Join cuando se filtra por una columna de estado no indexada.
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.status, count(*) AS n
FROM orders o
JOIN payment p ON p.order_id = o.order_id
WHERE p.payment_status = 'APPROVED'
GROUP BY o.status
ORDER BY n DESC;

-- -----------------------------------------------------------------------------

-- Q7: Métodos de pago usados por un cliente
-- Consulta específica para obtener la frecuencia de uso de métodos de pago por ID de cliente.
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.payment_method, count(*) AS total_orders
FROM orders o
JOIN payment p ON p.order_id = o.order_id
WHERE o.customer_id = 8
GROUP BY p.payment_method
ORDER BY total_orders DESC;

-- -----------------------------------------------------------------------------

-- Q8: Ingresos aprobados por categoría y mes (Consulta pesada: 4-Way Join + Agregación)
-- Desafíos: Multi-join, date_trunc en GROUP BY y COUNT DISTINCT sobre tablas de gran volumen.
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    date_trunc('month', o.order_date) AS month,
    p.category,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN payment pmt ON pmt.order_id = o.order_id
JOIN order_item oi ON oi.order_id = o.order_id
JOIN product p ON p.product_id = oi.product_id
WHERE o.order_date >= TIMESTAMPTZ '2023-01-01'
  AND o.order_date <  TIMESTAMPTZ '2024-01-01'
  AND pmt.payment_status = 'APPROVED'
GROUP BY month, p.category
ORDER BY month, total_revenue DESC;