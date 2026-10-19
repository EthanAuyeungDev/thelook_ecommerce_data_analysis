-- TheLook Ecommerce Analytics - Revenue and Order Analysis -- Purpose : Provide interview-ready business analysis queries with bilingual comments.

USE thelook_ecommerce_dw;
-- TheLook Ecommerce Analytics — Revenue & Order Analysis
-- =============================================================================
-- Skills Demonstrated: Aggregations, GROUP BY, HAVING, DATE functions,
--                      CASE WHEN, window functions for contribution %
-- =============================================================================


-- =============================================================================
-- 1. HIGH-LEVEL KPIs
-- Business Question: What are the headline revenue metrics?
-- =============================================================================
-- QA check : DESC thelook_ecommerce_dw.fct_order_items;
SELECT
    COUNT(DISTINCT order_id)                     AS total_orders,
    COUNT(*)                                     AS total_order_items,
    COUNT(DISTINCT customer_key)                 AS total_customers,
    ROUND(SUM(sale_price), 2)                    AS total_revenue,
    ROUND(SUM(gross_profit), 2)                  AS total_gross_profit,
    ROUND(AVG(sale_price), 2)                    AS avg_item_price,
    ROUND(SUM(sale_price) / COUNT(DISTINCT order_id), 2) AS avg_order_value,
    ROUND(SUM(gross_profit) / SUM(sale_price) * 100, 2)  AS overall_margin_pct
FROM fct_order_items
WHERE order_status NOT IN ('Cancelled');

-- =============================================================================
-- 2. MONTHLY REVENUE TREND
-- Business Question: How has revenue grown over time?
-- Why it matters: Shows growth trajectory — critical for investor stakeholder decks
-- =============================================================================

SELECT
    CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE)    AS order_month,
    COUNT(DISTINCT order_id)                     AS orders,
    COUNT(DISTINCT customer_key)                 AS customers,
    ROUND(SUM(sale_price), 2)                    AS revenue,
    ROUND(SUM(gross_profit), 2)                  AS gross_profit,
    ROUND(AVG(sale_price), 2)                    AS avg_item_price
FROM fct_order_items
WHERE order_status NOT IN ('Cancelled')
GROUP BY CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE)
ORDER BY order_month;

-- =============================================================================
-- 3. MONTH-OVER-MONTH REVENUE GROWTH
-- Business Question: What is the MoM growth rate?
-- Skills: LAG window function, percentage calculation
-- =============================================================================
WITH monthly_revenue AS (
	SELECT 
	CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE) AS order_month,
	ROUND(SUM(sale_price), 2) AS revenue
	FROM fct_order_items
	WHERE order_status NOT IN ('Cancelled')
	GROUP BY CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE)
)
SELECT
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0) * 100,
        2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;


-- 4. QUARTERLY REVENUE WITH YoY COMPARISON
-- Business Question: How does each quarter compare to the same quarter last year?
-- Skills: CTE, LAG with PARTITION BY
-- =============================================================================
WITH quarterly_revenue AS (
    SELECT
        YEAR(order_date_key)    		AS order_year,
        QUARTER(order_date_key) 		AS order_quarter,
        ROUND(SUM(sale_price), 2)   AS revenue,
        COUNT(DISTINCT order_id)    AS orders
    FROM fct_order_items
    WHERE order_status NOT IN ('Cancelled')
    GROUP BY
        YEAR(order_date_key),
        QUARTER(order_date_key)
)
SELECT
    order_year,
    order_quarter,
    revenue,
    orders,
    LAG(revenue) OVER (
        PARTITION BY order_quarter
        ORDER BY order_year
    )                                             AS same_quarter_last_year,
    ROUND(
        (revenue - LAG(revenue) OVER (
            PARTITION BY order_quarter ORDER BY order_year
        )) / NULLIF(LAG(revenue) OVER (
            PARTITION BY order_quarter ORDER BY order_year
        ), 0) * 100,
        2
    )                                             AS yoy_growth_pct
FROM quarterly_revenue
ORDER BY order_year, order_quarter;


-- =============================================================================
-- 5. REVENUE BY COUNTRY — TOP 10
-- Business Question: Which markets generate the most revenue?
-- Skills: JOIN, GROUP BY, ORDER BY with LIMIT
-- =============================================================================
SELECT
    c.country,
    COUNT(DISTINCT f.order_id)      AS orders,
    COUNT(DISTINCT f.customer_key)  AS customers,
    ROUND(SUM(f.sale_price), 2)     AS revenue,
    ROUND(SUM(f.gross_profit), 2)   AS gross_profit,
    ROUND(AVG(f.sale_price), 2)     AS avg_item_price,
    -- Revenue share using window function
    ROUND(
        SUM(f.sale_price) / SUM(SUM(f.sale_price)) OVER () * 100,
        2
    ) AS revenue_share_pct
FROM fct_order_items f
JOIN dim_customers c ON f.customer_key = c.customer_key
WHERE f.order_status NOT IN ('Cancelled')
GROUP BY c.country
ORDER BY revenue DESC
LIMIT 10;

-- =============================================================================
-- 6. REVENUE BY PRODUCT CATEGORY
-- Business Question: Which categories drive the business?
-- Skills: Window function for cumulative contribution (Pareto analysis)
-- =============================================================================
WITH category_revenue AS (
    SELECT
        p.category,
        p.department,
        COUNT(DISTINCT f.order_id)    AS orders,
        ROUND(SUM(f.sale_price), 2)   AS revenue,
        ROUND(SUM(f.gross_profit), 2) AS gross_profit,
        ROUND(AVG(f.margin_pct), 2)   AS avg_margin_pct
    FROM fct_order_items f
    JOIN dim_products p ON f.product_key = p.product_key
    WHERE f.order_status NOT IN ('Cancelled')
    GROUP BY p.category, p.department
)
SELECT
    category,
    department,
    orders,
    revenue,
    gross_profit,
    avg_margin_pct,
    -- Revenue contribution % (out of total)
    ROUND(revenue / SUM(revenue) OVER () * 100, 2)  AS revenue_contribution_pct,
    -- Cumulative contribution (for Pareto 80-20 analysis)
    ROUND(
        SUM(revenue) OVER (ORDER BY revenue DESC)
        / SUM(revenue) OVER () * 100,
        2
    )                                                AS cumulative_contribution_pct
FROM category_revenue
ORDER BY revenue DESC;


-- =============================================================================
-- 7. ORDER STATUS DISTRIBUTION
-- Business Question: What % of orders are completed vs cancelled vs returned?
-- Skills: CASE WHEN, conditional aggregation
-- =============================================================================
SELECT
    order_status,
    COUNT(*)                                     	   AS item_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
    ROUND(SUM(sale_price), 2)                    	   AS status_revenue
FROM fct_order_items
GROUP BY order_status
ORDER BY item_count DESC;

-- =============================================================================
-- 8. REVENUE BY DAY OF WEEK
-- Business Question: Which days generate the most revenue? (operational planning)
-- Skills: JOIN to dim_date, day-level aggregation
-- =============================================================================
SELECT
    d.day_of_name,
    d.day_of_week,
    COUNT(DISTINCT f.order_id)                   AS orders,
    ROUND(SUM(f.sale_price), 2)                  AS revenue,
    ROUND(AVG(f.sale_price), 2)                  AS avg_item_price
FROM fct_order_items f
JOIN dim_date d ON f.order_date_key = d.date_key
WHERE f.order_status NOT IN ('Cancelled')
GROUP BY d.day_of_name, d.day_of_week
ORDER BY d.day_of_week;

-- =============================================================================
-- 9. WEEKEND VS WEEKDAY PERFORMANCE
-- Business Question: Do customers spend more on weekends or weekdays?
-- Skills: Boolean grouping, comparative analysis
-- =============================================================================
SELECT
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(DISTINCT f.order_id)                   AS orders,
    ROUND(SUM(f.sale_price), 2)                  AS revenue,
    ROUND(AVG(f.sale_price), 2)                  AS avg_item_price,
    ROUND(SUM(f.sale_price) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value
FROM fct_order_items f
JOIN dim_date d ON f.order_date_key = d.date_key
WHERE f.order_status NOT IN ('Cancelled')
GROUP BY CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END;


-- =============================================================================
-- 10. AVERAGE DELIVERY TIME ANALYSIS
-- Business Question: How fast are orders being delivered, and is it improving?
-- Skills: Date arithmetic, HAVING filter, trend analysis
-- =============================================================================
SELECT
    CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE)      AS order_month,
    COUNT(*)                                     AS delivered_items,
    ROUND(AVG(delivery_days), 1)                 AS avg_delivery_days,
    MIN(delivery_days)                           AS min_delivery_days,
    MAX(delivery_days)                           AS max_delivery_days
FROM fct_order_items
WHERE delivery_days IS NOT NULL
  AND order_status = 'Complete'
GROUP BY CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE)
HAVING COUNT(*) >= 10
ORDER BY order_month;

-- =============================================================================
-- 11. RETURN RATE TREND
-- Business Question: Is the return rate getting worse or better?
-- Skills: Conditional aggregation, trend analysis
-- =============================================================================
SELECT
    CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE)      	AS order_month,
    COUNT(*)                                     	AS total_items,
    SUM(is_returned)                             	AS returned_items,
    ROUND(SUM(is_returned) * 100.0 / COUNT(*), 2) 	AS return_rate_pct,
    ROUND(SUM(CASE WHEN is_returned = 1 THEN sale_price ELSE 0 END), 2) AS returned_revenue
FROM fct_order_items
GROUP BY CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE)
ORDER BY order_month;