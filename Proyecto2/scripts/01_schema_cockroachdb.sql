-- 01_schema_cockroachdb.sql
-- Persona 3 — Schema adaptado para CockroachDB
-- EAFIT - Bases de Datos Avanzadas
--
-- NOTA: El schema original (PostgreSQL) usa CREATE TYPE order_status AS ENUM
-- CockroachDB no soporta DO $$ ni DROP TYPE de la misma forma.
-- Se adapto usando TEXT en la columna status de orders.

USE ecommerce;

DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS order_item CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS product CASCADE;
DROP TABLE IF EXISTS customer CASCADE;

CREATE TABLE customer (
  customer_id   BIGINT PRIMARY KEY,
  name          TEXT NOT NULL,
  email         TEXT NOT NULL,
  city          TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE product (
  product_id    BIGINT PRIMARY KEY,
  name          TEXT NOT NULL,
  category      TEXT NOT NULL,
  price         NUMERIC(12,2) NOT NULL CHECK (price >= 0)
);

CREATE TABLE orders (
  order_id      BIGINT PRIMARY KEY,
  customer_id   BIGINT NOT NULL REFERENCES customer(customer_id),
  order_date    TIMESTAMPTZ NOT NULL,
  status        TEXT NOT NULL,
  total_amount  NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0)
);

CREATE TABLE order_item (
  order_item_id BIGINT PRIMARY KEY,
  order_id      BIGINT NOT NULL REFERENCES orders(order_id),
  product_id    BIGINT NOT NULL REFERENCES product(product_id),
  quantity      INT NOT NULL CHECK (quantity > 0),
  unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE payment (
  payment_id     BIGINT PRIMARY KEY,
  order_id       BIGINT NOT NULL REFERENCES orders(order_id),
  payment_date   TIMESTAMPTZ NOT NULL,
  payment_method TEXT NOT NULL,
  payment_status TEXT NOT NULL
);
