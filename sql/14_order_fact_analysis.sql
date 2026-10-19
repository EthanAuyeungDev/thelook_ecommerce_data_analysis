USE thelook_ecommerce_dw;

-- TheLook Ecommerce Analytics - Order Fact Analysis -- Purpose : Analyze order-level status, AOV, item count, and fulfillment metrics from fct_orders.
-- Grain : Order-level analysis based on one row per order.

-- 1. Order status scorecard 
SELECT
    s.order_status,
    s.status_group,
    COUNT(*) AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS order_share_pct,
    ROUND(SUM(order_gross_amount), 2) AS gross_sales_including_returns,
    ROUND(SUM(order_net_amount), 2) AS net_sales_excluding_returns,
    ROUND(AVG(order_net_amount), 2) AS avg_net_order_value,
    ROUND(AVG(num_of_item), 2) AS avg_items_per_order
FROM fct_orders o
LEFT JOIN dim_order_status s ON o.order_status_key = s.order_status_key
GROUP BY s.order_status, s.status_group
ORDER BY orders DESC;

-- 2. Monthly order trend 
SELECT
    DATE_FORMAT(order_date_key, '%Y-%m') AS order_month,
    COUNT(*) AS orders,
    COUNT(DISTINCT customer_key) AS customers,
    ROUND(SUM(order_net_amount), 2) AS net_sales,
    ROUND(SUM(order_net_amount) / NULLIF(COUNT(*), 0), 2) AS avg_net_order_value,
    ROUND(AVG(num_of_item), 2) AS avg_items_per_order,
    ROUND(SUM(is_cancelled) * 100.0 / COUNT(*), 2) AS cancel_rate_pct,
    ROUND(SUM(is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM fct_orders
GROUP BY DATE_FORMAT(order_date_key, '%Y-%m')
ORDER BY order_month;

-- 3. AOV distribution by item count 
SELECT
    CASE
        WHEN num_of_item = 1 THEN '1 item / 1件'
        WHEN num_of_item = 2 THEN '2 items / 2件'
        WHEN num_of_item = 3 THEN '3 items / 3件'
        ELSE '4+ items / 4件以上'
    END AS item_count_bucket,
    COUNT(*) AS orders,
    ROUND(AVG(order_net_amount), 2) AS avg_net_order_value,
    ROUND(SUM(order_net_amount), 2) AS net_sales,
    ROUND(SUM(is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct,
    ROUND(SUM(is_cancelled) * 100.0 / COUNT(*), 2) AS cancel_rate_pct
FROM fct_orders
GROUP BY item_count_bucket
ORDER BY orders DESC;

-- 4. Order-level fulfillment SLA SLA
SELECT
    DATE_FORMAT(order_date_key, '%Y-%m') AS order_month,
    COUNT(*) AS shipped_or_completed_orders,
    ROUND(AVG(ship_days), 2) AS avg_ship_days,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(SUM(CASE WHEN delivery_days <= 5 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(delivery_days), 0), 2) AS delivered_within_5_days_pct
FROM fct_orders
WHERE shipped_at_utc IS NOT NULL
GROUP BY DATE_FORMAT(order_date_key, '%Y-%m')
ORDER BY order_month;

-- 5. Customer order frequency from order-level grain
WITH customer_orders AS (
    SELECT
        customer_key,
        COUNT(*) AS orders,
        ROUND(SUM(order_net_amount), 2) AS net_sales,
        MIN(order_date_key) AS first_order_date,
        MAX(order_date_key) AS last_order_date
    FROM fct_orders
    WHERE is_cancelled = 0
      AND customer_key IS NOT NULL      -- 排除无客户归属的订单
    GROUP BY customer_key
),
segmented AS (
    SELECT
        customer_key,
        orders,
        net_sales,
        first_order_date,
        last_order_date,
        CASE
            WHEN orders = 1 THEN '1. One order'
            WHEN orders BETWEEN 2 AND 3 THEN '2. 2-3 orders'
            WHEN orders BETWEEN 4 AND 6 THEN '3. 4-6 orders'
            ELSE '4. 7+ orders'
        END AS order_frequency_segment
    FROM customer_orders
)
SELECT
    order_frequency_segment,
    COUNT(*) AS customers,
    ROUND(AVG(orders), 2) AS avg_orders,
    ROUND(AVG(net_sales), 2) AS avg_customer_revenue,
    -- For 1-order customers, first = last, so span = 0.
    -- NULLIF guard is not needed but the 0 value is documented.
    ROUND(AVG(DATEDIFF(last_order_date, first_order_date)), 1) AS avg_customer_order_span_days
FROM segmented
GROUP BY order_frequency_segment
ORDER BY order_frequency_segment;   -- alphabetical order matches 1. / 2. / 3. / 4.

-- Business question: How do order status, cancellation, returns, and revenue differ
-- when measured at order grain versus order-item grain? Order-level amounts come from
-- fct_orders: gross includes returned items, net excludes returned and cancelled items.
-- Item-level returns/cancellations use item rows; these rates are not interchangeable
-- with the share of orders containing at least one returned/cancelled item.
WITH item_metrics AS (
    SELECT
        COUNT(*) AS item_rows,
        SUM(order_status = 'Cancelled') AS cancelled_item_rows,
        SUM(is_returned = 1) AS returned_item_rows,
        SUM(CASE WHEN order_status <> 'Cancelled' THEN sale_price ELSE 0 END) AS item_gross_sales,
        SUM(CASE WHEN order_status <> 'Cancelled' AND is_returned = 0 THEN sale_price ELSE 0 END) AS item_net_sales
    FROM fct_order_items
), order_metrics AS (
    SELECT
        COUNT(*) AS order_rows,
        SUM(is_cancelled = 1) AS cancelled_orders,
        SUM(is_returned = 1) AS returned_orders,
        SUM(order_gross_amount) AS order_gross_sales,
        SUM(order_net_amount) AS order_net_sales
    FROM fct_orders
)
SELECT
    o.order_rows,
    o.cancelled_orders,
    ROUND(100.0 * o.cancelled_orders / NULLIF(o.order_rows, 0), 2) AS cancelled_order_rate_pct,
    o.returned_orders,
    ROUND(100.0 * o.returned_orders / NULLIF(o.order_rows, 0), 2) AS returned_order_rate_pct,
    ROUND(o.order_gross_sales, 2) AS order_gross_sales,
    ROUND(o.order_net_sales, 2) AS order_net_sales,
    i.item_rows,
    i.cancelled_item_rows,
    ROUND(100.0 * i.cancelled_item_rows / NULLIF(i.item_rows, 0), 2) AS cancelled_item_rate_pct,
    i.returned_item_rows,
    ROUND(100.0 * i.returned_item_rows / NULLIF(i.item_rows, 0), 2) AS returned_item_rate_pct,
    ROUND(i.item_gross_sales, 2) AS item_gross_sales,
    ROUND(i.item_net_sales, 2) AS item_net_sales
FROM order_metrics o
CROSS JOIN item_metrics i;

-- Business question: What fraction of orders contain at least one cancelled or
-- returned item, and how much net value remains after excluding those items? This is
-- an order-grain customer impact metric; order totals are not summed from event data.
WITH per_order AS (
    SELECT
        order_id,
        MAX(is_cancelled) AS has_cancelled_item,
        MAX(is_returned) AS has_returned_item,
        SUM(CASE WHEN order_status <> 'Cancelled' AND is_returned = 0 THEN sale_price ELSE 0 END) AS retained_item_revenue
    FROM fct_order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) AS orders_with_items,
    SUM(has_cancelled_item) AS orders_with_cancelled_item,
    SUM(has_returned_item) AS orders_with_returned_item,
    ROUND(100.0 * SUM(has_cancelled_item) / NULLIF(COUNT(*), 0), 2) AS orders_with_cancelled_item_pct,
    ROUND(100.0 * SUM(has_returned_item) / NULLIF(COUNT(*), 0), 2) AS orders_with_returned_item_pct,
    ROUND(SUM(retained_item_revenue), 2) AS retained_item_revenue
FROM per_order;
