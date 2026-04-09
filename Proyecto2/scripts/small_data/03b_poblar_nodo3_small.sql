-- ===========================================
-- SMALL DATA — NODO 3
-- pagos: ~4.000 (órdenes no canceladas)
-- ===========================================

INSERT INTO pagos (orden_id, metodo, estado, fecha, monto)
SELECT
    i AS orden_id,
    (ARRAY['tarjeta','pse','efectivo'])[1 + (i % 3)],
    CASE
        WHEN (i % 5) = 0 THEN 'pendiente'  -- Índice 1 en Nodo 1 ('pendiente')
        ELSE 'aprobado'                    -- Índices 2, 3 y 4 en Nodo 1 ('completada')
    END,
    NOW() - (random() * INTERVAL '730 days'),
    ROUND((10000 + random() * 990000)::numeric, 2)
FROM generate_series(1, 5000) AS i
WHERE (i % 5) != 4;  -- Excluye exactamente el índice 5 ('cancelada')

ANALYZE pagos;
