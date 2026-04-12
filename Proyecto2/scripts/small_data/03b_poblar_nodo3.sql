-- ===========================================
-- DATA — NODO 3
-- pagos: 500.000 (órdenes no canceladas)
-- ===========================================

INSERT INTO pagos (orden_id, metodo, estado, fecha, monto)
SELECT
    i AS orden_id,
    (ARRAY['tarjeta','pse','efectivo'])[1 + (i % 3)],
    CASE
        WHEN (i % 5) = 0 THEN 'pendiente'
        ELSE 'aprobado'
    END,
    NOW() - (random() * INTERVAL '730 days'),
    ROUND((10000 + random() * 990000)::numeric, 2)
FROM generate_series(1, 500000) AS i
WHERE (i % 5) != 4;

ANALYZE pagos;
