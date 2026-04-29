-- 02_dataset_cockroachdb.sql
-- Persona 3 — Generacion de dataset (10% del dataset completo)
-- EAFIT - Bases de Datos Avanzadas
--
-- Volumenes (10% del dataset original):
--   customer:   100,000 filas
--   product:     10,000 filas
--   orders:     500,000 filas
--   order_item: 2,000,000 filas
--   payment:    400,000 filas
--   TOTAL:      3,010,000 filas
--
-- IMPORTANTE: Ejecutar desde PowerShell con --execute, no desde el shell interactivo.
-- Ver README.md para los comandos completos.
--
-- ADVERTENCIA: La insercion de order_item usa random()*499999 para evitar
-- foreign key violations (no la formula original gs/4 del script de PostgreSQL).

-- Customers (100,000)
INSERT INTO ecommerce.customer (customer_id, name, email, city, created_at)
SELECT
  gs AS customer_id,
  'Customer ' || gs,
  'customer' || gs || '@example.com',
  (ARRAY['Medellin','Bogota','Cali','Barranquilla','Bucaramanga',
         'Cartagena','Manizales','Pereira','Santa Marta','Ibague'])[1 + (random()*9)::int],
  now() - (random() * interval '8 years')
FROM generate_series(1, 100000) gs;

-- Products (10,000)
INSERT INTO ecommerce.product (product_id, name, category, price)
SELECT
  gs AS product_id,
  'Product ' || gs,
  (ARRAY['Electronica','Hogar','Deportes','Libros','Moda',
         'Juguetes','Salud','Alimentos','Automotor','Ferreteria'])[1 + (random()*9)::int],
  round((random()*990 + 10)::numeric, 2)
FROM generate_series(1, 10000) gs;

-- Orders (500,000)
INSERT INTO ecommerce.orders (order_id, customer_id, order_date, status, total_amount)
SELECT
  gs AS order_id,
  1 + (random()*99999)::bigint AS customer_id,
  now() - (random() * interval '5 years') AS order_date,
  (ARRAY['CREATED','PAID','SHIPPED','COMPLETED','CANCELLED'])[1 + (random()*4)::int],
  round((random()*800 + 10)::numeric, 2)
FROM generate_series(1, 500000) gs;

-- Order Items (2,000,000)
-- NOTA: Se usa random()*499999 en lugar de (gs-1)/4 para evitar FK violations
INSERT INTO ecommerce.order_item (order_item_id, order_id, product_id, quantity, unit_price)
SELECT
  gs AS order_item_id,
  1 + (random()*499999)::bigint AS order_id,
  1 + (random()*9999)::bigint AS product_id,
  1 + (random()*4)::int AS quantity,
  round((random()*400 + 5)::numeric, 2) AS unit_price
FROM generate_series(1, 2000000) gs;

-- Payments (400,000 = 80% de orders)
INSERT INTO ecommerce.payment (payment_id, order_id, payment_date, payment_method, payment_status)
SELECT
  gs AS payment_id,
  1 + (random()*499999)::bigint AS order_id,
  now() - (random() * interval '5 years'),
  (ARRAY['CARD','PSE','CASH_ON_DELIVERY','TRANSFER','WALLET'])[1 + (random()*4)::int],
  (ARRAY['APPROVED','REJECTED','PENDING'])[1 + (random()*2)::int]
FROM generate_series(1, 400000) gs;
