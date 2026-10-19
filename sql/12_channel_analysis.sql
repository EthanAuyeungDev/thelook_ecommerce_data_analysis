USE thelook_ecommerce_dws;

-- TheLook Ecommerce Analytics - Channel Analysis -- Purpose : Compare acquisition and behavior quality across traffic sources.

-- 1. Daily channel performance 
SELECT
    traffic_source,
    order_date,
    customers,
    orders,
    items,
    revenue,
    avg_order_value,
    return_rate_pct
FROM dws_channel_performance
ORDER BY order_date, revenue DESC;

-- 2. Overall channel scorecard 
SELECT
    traffic_source,
    SUM(customers) AS customers,
    SUM(orders) AS orders,
    SUM(items) AS items,
    ROUND(SUM(revenue), 2) AS revenue,
    ROUND(SUM(revenue) / NULLIF(SUM(orders), 0), 2) AS avg_order_value,
    ROUND(AVG(return_rate_pct), 2) AS avg_return_rate_pct,
    ROUND(SUM(revenue) / NULLIF(SUM(customers), 0), 2) AS revenue_per_customer
FROM dws_channel_performance
GROUP BY traffic_source
ORDER BY revenue DESC;

-- 3. Channel user quality 
SELECT
    traffic_source,
    COUNT(*) AS purchasing_customers,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    ROUND(AVG(total_revenue), 2) AS avg_ltv,
    ROUND(SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS repeat_purchase_rate_pct,
    ROUND(AVG(recency_days), 1) AS avg_recency_days
FROM dws_user_order_summary
WHERE total_orders > 0
GROUP BY traffic_source
ORDER BY avg_ltv DESC;

