USE thelook_ecommerce_dw;

-- TheLook Ecommerce Analytics - Fulfillment and Delivery Analysis -- Purpose : Analyze shipment speed, delivery time, return cancel patterns, and DC performance.

-- 1. Delivery time distribution 
SELECT
    CASE
        WHEN delivery_days IS NULL THEN 'Not Delivered / 未送达'
        WHEN delivery_days <= 2 THEN '0-2 Days / 0-2天'
        WHEN delivery_days <= 5 THEN '3-5 Days / 3-5天'
        WHEN delivery_days <= 10 THEN '6-10 Days / 6-10天'
        ELSE '10+ Days / 10天以上'
    END AS delivery_bucket,
    COUNT(*) AS item_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS item_share_pct
FROM fct_order_items
GROUP BY delivery_bucket
ORDER BY item_count DESC;

-- 2. Monthly delivery SLA trend 
SELECT
    DATE_FORMAT(order_date_key, '%Y-%m') AS order_month,
    COUNT(*) AS delivered_items,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(SUM(CASE WHEN delivery_days <= 5 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS delivered_within_5_days_pct,
    ROUND(SUM(is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM fct_order_items
WHERE delivery_days IS NOT NULL
GROUP BY DATE_FORMAT(order_date_key, '%Y-%m')
ORDER BY order_month;

-- 3. Distribution center performance SELECT
    p.distribution_center_name,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    ROUND(SUM(f.sale_price), 2) AS revenue,
    ROUND(AVG(f.delivery_days), 2) AS avg_delivery_days,
    ROUND(SUM(CASE WHEN f.delivery_days <= 5 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(f.delivery_days), 0), 2) AS delivered_within_5_days_pct,
    ROUND(SUM(f.is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct,
    ROUND(SUM(f.is_cancelled) * 100.0 / COUNT(*), 2) AS cancel_rate_pct
FROM fct_order_items f
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.distribution_center_name
ORDER BY revenue DESC;

-- 4. Return timing 
SELECT
    DATE_FORMAT(returned_at_utc, '%Y-%m') AS return_month,
    COUNT(*) AS returned_items,
    ROUND(AVG(DATEDIFF(returned_at_utc, delivered_at_utc)), 2) AS avg_days_from_delivery_to_return,
    ROUND(SUM(sale_price), 2) AS returned_revenue
FROM fct_order_items
WHERE is_returned = 1
  AND returned_at_utc IS NOT NULL
  AND delivered_at_utc IS NOT NULL
GROUP BY DATE_FORMAT(returned_at_utc, '%Y-%m')
ORDER BY return_month;

-- Business question: Where in the order lifecycle do fulfillment delays occur, and
-- how long does each stage take? Stage durations are summarized separately. The fact
-- table clamps negative durations to zero, so use is_time_inverted to assess source-time
-- anomalies and do not interpret a zero duration as necessarily same-day fulfillment.
SELECT
    DATE_FORMAT(order_date_key, '%Y-%m') AS order_month,
    COUNT(*) AS order_items,
    ROUND(AVG(CASE WHEN created_at_utc IS NOT NULL AND shipped_at_utc IS NOT NULL THEN ship_days END), 2) AS avg_create_to_ship_days,
    ROUND(AVG(CASE WHEN shipped_at_utc IS NOT NULL AND delivered_at_utc IS NOT NULL THEN delivery_days END), 2) AS avg_ship_to_delivery_days,
    ROUND(AVG(CASE WHEN delivered_at_utc IS NOT NULL AND returned_at_utc IS NOT NULL
        THEN DATEDIFF(returned_at_utc, delivered_at_utc) END), 2) AS avg_delivery_to_return_days,
    SUM(is_time_inverted) AS inverted_create_ship_timestamps,
    ROUND(100.0 * SUM(is_time_inverted) / NULLIF(COUNT(*), 0), 2) AS inverted_timestamp_pct
FROM fct_order_items
GROUP BY DATE_FORMAT(order_date_key, '%Y-%m')
ORDER BY order_month;

-- Business question: Do order-level lifecycle durations tell the same operational
-- story as item-level durations? Each order contributes once here, unlike item-level
-- analysis where large orders contribute multiple rows.
SELECT
    DATE_FORMAT(order_date_key, '%Y-%m') AS order_month,
    COUNT(*) AS orders,
    ROUND(AVG(ship_days), 2) AS avg_order_create_to_ship_days,
    ROUND(AVG(delivery_days), 2) AS avg_order_ship_to_delivery_days,
    ROUND(AVG(CASE WHEN delivered_at_utc IS NOT NULL AND returned_at_utc IS NOT NULL
        THEN DATEDIFF(returned_at_utc, delivered_at_utc) END), 2) AS avg_order_delivery_to_return_days
FROM fct_orders
GROUP BY DATE_FORMAT(order_date_key, '%Y-%m')
ORDER BY order_month;
