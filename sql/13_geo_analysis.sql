USE thelook_ecommerce_dw;

-- TheLook Ecommerce Analytics 
-- Geographic Analysis 
-- Purpose : Understand revenue, customers, order behavior, and return risk by country, state, and city.

-- 1. Country scorecard 
SELECT
    c.country,
    COUNT(DISTINCT c.customer_key) AS customers,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    ROUND(SUM(f.sale_price), 2) AS revenue,
    ROUND(SUM(f.sale_price) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS avg_order_value,
    ROUND(SUM(f.is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM fct_order_items f
JOIN dim_customers c ON f.customer_key = c.customer_key
WHERE f.order_status NOT IN ('Cancelled')
GROUP BY c.country
ORDER BY revenue DESC;

-- 2. Top cities per country 
WITH city_metrics AS (
    SELECT
        c.country,
        c.city,
        COUNT(DISTINCT c.customer_key) AS customers,
        COUNT(DISTINCT f.order_id) AS orders,
        ROUND(SUM(f.sale_price), 2) AS revenue,
        ROW_NUMBER() OVER (PARTITION BY c.country ORDER BY SUM(f.sale_price) DESC) AS city_rank
    FROM fct_order_items f
    JOIN dim_customers c ON f.customer_key = c.customer_key
    WHERE f.order_status NOT IN ('Cancelled')
      AND c.city IS NOT NULL
    GROUP BY c.country, c.city
)
SELECT *
FROM city_metrics
WHERE city_rank <= 5
ORDER BY country, city_rank;

-- 3. Geographic return risk 
SELECT
    c.country,
    c.state,
    COUNT(*) AS items,
    ROUND(SUM(f.sale_price), 2) AS revenue,
    ROUND(SUM(f.is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct,
    ROUND(SUM(CASE WHEN f.is_returned = 1 THEN f.sale_price ELSE 0 END), 2) AS returned_revenue
FROM fct_order_items f
JOIN dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.country, c.state
HAVING COUNT(*) >= 50
ORDER BY return_rate_pct DESC, returned_revenue DESC
LIMIT 100;
