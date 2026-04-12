-- Diferentes optimizaciones para las consultas

-- Consulta 1) Indices

CREATE INDEX idx_orders_order_date 
ON orders(order_date);

CREATE INDEX idx_orders_date_customer 
ON orders(order_date, customer_id);

-- Consulta 2) Reestructuracion de la consulta

SELECT p.name, sub.total_sold 
FROM product p 
JOIN ( 
SELECT product_id, SUM(quantity) AS total_sold 
FROM order_item 
GROUP BY product_id
) sub ON p.product_id = sub.product_id 
ORDER BY sub.total_sold DESC 
LIMIT 10;

-- Consulta 3) Indice

CREATE INDEX IF NOT EXISTS idx_orders_customer_date_desc 
ON orders(customer_id, order_date DESC);

-- Consulta 4) Indice y extension

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_product_name_trgm 
ON product USING gin (name gin_trgm_ops);

-- Consulta 5) Reestructuracion de la consulta

SELECT count(*)
FROM orders
WHERE order_date >= TIMESTAMPTZ '2023-11-15 00:00:00'
  AND order_date <  TIMESTAMPTZ '2023-11-16 00:00:00';

-- Consulta 6) Indice

CREATE INDEX idx_payment_status_order 
ON payment(payment_status, order_id);

-- Consulta 7) Indices

CREATE INDEX IF NOT EXISTS idx_orders_customer_id
ON orders(customer_id);

CREATE INDEX IF NOT EXISTS idx_payment_order_id 
ON payment(order_id);
