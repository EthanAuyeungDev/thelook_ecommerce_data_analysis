-- TheLook Ecommerce Analytics - Product Analysis -- Purpose : Provide interview-ready business analysis queries with bilingual comments.

USE thelook_ecommerce_dw;

-- TheLook Ecommerce Analytics — Product Analysis
-- =============================================================================
-- Skills Demonstrated: Window functions (RANK, DENSE_RANK, ROW_NUMBER),
--                      TOP-N queries, margin analysis, product affinity
-- =============================================================================


-- =============================================================================
-- 1. TOP 15 PRODUCTS BY REVENUE
-- Business Question: Which individual products generate the most revenue?
-- Skills: DENSE_RANK window function
-- =============================================================================
SELECT 
	DENSE_RANK() OVER (ORDER BY SUM(foi.sale_price) DESC) AS sales_rank,
	dp.product_name,
    dp.category,
    dp.brand,
    dp.department,
    COUNT(*)                                     		AS units_sold,
    ROUND(SUM(foi.sale_price), 2)                  		AS total_revenue,
    ROUND(SUM(foi.gross_profit), 2)                		AS total_profit,
    ROUND(SUM(foi.gross_profit) / SUM(foi.sale_price) * 100,2)   AS avg_margin_pct,
    -- Return rate for this product
    ROUND(SUM(foi.is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM thelook_ecommerce_dw.fct_order_items foi
JOIN thelook_ecommerce_dw.dim_products dp
ON foi.product_key = dp.product_key
WHERE foi.order_status NOT IN ('Cancelled')
GROUP BY dp.product_key, dp.product_name, dp.category, dp.brand, dp.department
ORDER BY total_revenue DESC
LIMIT 15;

-- =============================================================================
-- 2. TOP 15 BRANDS BY REVENUE AND VOLUME
-- Business Question: Which brands dominate sales?
-- Skills: Multi-metric aggregation, ranking
-- =============================================================================
SELECT 
	DENSE_RANK() OVER (ORDER BY SUM(foi.sale_price) DESC ) AS revenue_rank,
	dp.brand,
    COUNT(DISTINCT dp.product_key)   					AS products_in_catalog,
    COUNT(*)                        						AS units_sold,
    ROUND(SUM(foi.sale_price), 2)               			AS total_revenue,
    ROUND(SUM(foi.gross_profit), 2)               		AS total_profit,
    ROUND(SUM(foi.gross_profit) / SUM(foi.sale_price) * 100,2)   AS avg_margin_pct,
    ROUND(SUM(foi.is_returned) * 100.0 / COUNT(*), 2) 	AS return_rate_pct,
    ROUND(SUM(foi.sale_price) / COUNT(DISTINCT dp.product_key), 2) AS revenue_per_product
FROM fct_order_items foi
JOIN dim_products dp ON foi.product_key = dp.product_key
WHERE foi.order_status NOT IN ('Cancelled')
  AND dp.brand IS NOT NULL
  AND dp.brand != ''
GROUP BY dp.brand
HAVING COUNT(*) >= 10       -- filter out tiny brands with few sales
ORDER BY total_revenue DESC
LIMIT 15;


-- =============================================================================
-- 3. CATEGORY PERFORMANCE MATRIX
-- Business Question: How does each category perform on revenue, margin, returns?
-- Skills: Multi-metric GROUP BY, conditional aggregation
-- Interview value: Shows ability to build a "performance scorecard"
-- =============================================================================
SELECT 
	dp.category,
    dp.department,
    COUNT(*)                                     		AS units_sold,
    COUNT(DISTINCT foi.order_id)                 		AS orders,
    COUNT(DISTINCT foi.customer_key)              		AS unique_customers,
    ROUND(SUM(foi.sale_price), 2)                  		AS revenue,
    ROUND(SUM(foi.gross_profit), 2)                		AS gross_profit,
    ROUND(AVG(foi.sale_price), 2)                  		AS avg_sale_price,
    ROUND(SUM(foi.gross_profit) / SUM(foi.sale_price) * 100,2)  AS avg_margin_pct,
    ROUND(SUM(foi.is_returned) * 100.0 / COUNT(*), 2) 	AS return_rate_pct,
    ROUND(SUM(foi.is_cancelled) * 100.0 / COUNT(*), 2) 	AS cancel_rate_pct,
    -- Revenue contribution
    ROUND(
        SUM(foi.sale_price) / SUM(SUM(foi.sale_price)) OVER () * 100,
        2
    )                                            		AS revenue_share_pct
FROM fct_order_items foi
JOIN dim_products dp ON foi.product_key = dp.product_key
WHERE foi.order_status NOT IN ('Cancelled')
GROUP BY dp.category, dp.department
ORDER BY revenue DESC;

-- =============================================================================
-- 4. PRICE TIER ANALYSIS
-- Business Question: How do different price ranges perform?
-- Skills: CASE WHEN for bucketing, segment comparison
-- =============================================================================
SELECT 
  CASE
        WHEN foi.sale_price < 10       THEN '01. Under $10'
        WHEN foi.sale_price < 25       THEN '02. $10 - $24'
        WHEN foi.sale_price < 50       THEN '03. $25 - $49'
        WHEN foi.sale_price < 100      THEN '04. $50 - $99'
        WHEN foi.sale_price < 200      THEN '05. $100 - $199'
        WHEN foi.sale_price < 500      THEN '06. $200 - $499'
        ELSE                              '07. $500+'
    END AS price_tier,
    COUNT(*) AS units_sold,
    ROUND(SUM(foi.sale_price), 2) AS revenue,
    ROUND(SUM(foi.gross_profit) / SUM(foi.sale_price) * 100,2)  AS avg_margin_pct,
    ROUND(SUM(foi.is_returned) * 100.0 / COUNT(*), 2)  AS return_rate_pct,
    ROUND(
        SUM(foi.sale_price) / SUM(SUM(foi.sale_price)) OVER () * 100,
        2
    ) 
FROM fct_order_items foi
WHERE foi.order_status NOT IN ('Cancelled')
GROUP BY 
	CASE
        WHEN foi.sale_price < 10       THEN '01. Under $10'
        WHEN foi.sale_price < 25       THEN '02. $10 - $24'
        WHEN foi.sale_price < 50       THEN '03. $25 - $49'
        WHEN foi.sale_price < 100      THEN '04. $50 - $99'
        WHEN foi.sale_price < 200      THEN '05. $100 - $199'
        WHEN foi.sale_price < 500      THEN '06. $200 - $499'
        ELSE                              '07. $500+'
    END
ORDER BY price_tier;

-- =============================================================================
-- 5. UNDERPERFORMING PRODUCTS (HIGH RETURN, LOW MARGIN)
-- Business Question: Which products are problematic and should be investigated?
-- Skills: HAVING with multiple conditions, risk identification
-- =============================================================================
SELECT
    dp.product_name,
    dp.category,
    dp.brand,
    COUNT(*)                                     			AS units_sold,
    ROUND(SUM(foi.sale_price), 2)                	  		AS revenue,
    ROUND(SUM(foi.gross_profit) / SUM(foi.sale_price) * 100,2)		AS overall_margin_pct,
    ROUND(SUM(foi.is_returned) * 100.0 / COUNT(*), 2) 	 	AS return_rate_pct,
    -- Flag: high return AND low margin
    CASE
        WHEN SUM(foi.gross_profit) / SUM(foi.sale_price) * 100  < 20
         AND SUM(foi.is_returned) * 100.0 / COUNT(*) > 15
        THEN 'CRITICAL'
        WHEN SUM(foi.gross_profit) / SUM(foi.sale_price) * 100  < 30
         AND SUM(foi.is_returned) * 100.0 / COUNT(*) > 10
        THEN 'WARNING'
        ELSE 'OK'
    END  AS risk_flag
FROM fct_order_items foi
JOIN dim_products dp ON foi.product_key = dp.product_key
WHERE foi.order_status NOT IN ('Cancelled')
GROUP BY dp.product_key, dp.product_name, dp.category, dp.brand
HAVING COUNT(*) >= 5    							-- at least 5 sales (statistical significance)
ORDER BY return_rate_pct DESC, overall_margin_pct ASC
LIMIT 25;

-- =============================================================================
-- 6. CATEGORY TREND — MONTHLY REVENUE BY CATEGORY
-- Business Question: Which categories are growing and which are declining?
-- Skills: PIVOT-style analysis, multi-dimensional trend, MoM growth, ranking
-- =============================================================================
WITH monthly_category AS (
    SELECT
        DATE_FORMAT(foi.order_date_key, '%Y-%m')       AS order_month,
        dp.category,
        ROUND(SUM(foi.sale_price), 2)                  AS revenue,
        COUNT(*)                                     AS units_sold
    FROM fct_order_items foi
    JOIN dim_products dp ON foi.product_key = dp.product_key
    WHERE foi.order_status NOT IN ('Cancelled')
    GROUP BY DATE_FORMAT(foi.order_date_key, '%Y-%m'), dp.category
),
enriched AS (
    SELECT
        order_month,
        category,
        revenue,
        units_sold,
        -- 
        RANK() OVER (
            PARTITION BY order_month
            ORDER BY revenue DESC
        ) AS monthly_rank,
        -- （）
        LAG(revenue) OVER (
            PARTITION BY category
            ORDER BY order_month
        ) AS prev_month_revenue,
        -- （）
        SUM(revenue) OVER (
            PARTITION BY order_month
        ) AS month_total_revenue,
        -- 
        CASE
            WHEN RANK() OVER (PARTITION BY order_month ORDER BY revenue DESC) <= 3 THEN 'Top 3'
            WHEN RANK() OVER (PARTITION BY order_month ORDER BY revenue DESC) <= 5 THEN 'Top 5'
            ELSE 'Others'
        END AS tier
    FROM monthly_category
)
SELECT
    order_month,
    category,
    revenue,
    prev_month_revenue,
    units_sold,
    monthly_rank,
    tier,
    -- 
    ROUND(
        (revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0) * 100,
        2
    ) AS mom_growth_pct,
    -- 
    ROUND(revenue / month_total_revenue * 100, 2) AS revenue_share_pct
FROM enriched
ORDER BY order_month, monthly_rank;


-- =============================================================================
-- 7. DEPARTMENT COMPARISON: MEN VS WOMEN
-- Business Question: How do Men's and Women's departments compare?
-- Skills: Conditional aggregation, side-by-side comparison
-- Notes:
--   - catalog_size  =  SKU （product_key ）
--   - avg_price     = （）
--   - margin_pct    = （ ）
--   - revenue_per_customer = （ ）
-- =============================================================================

SELECT
    dp.department,
    -- 
    COUNT(DISTINCT dp.product_key)                    AS catalog_size,
    -- 
    COUNT(*)                                         AS units_sold,
    COUNT(DISTINCT foi.customer_key)                   AS unique_customers,
    COUNT(DISTINCT foi.order_id)                       AS total_orders,
    -- 
    ROUND(SUM(foi.sale_price), 2)                      AS revenue,
    ROUND(SUM(foi.gross_profit), 2)                    AS gross_profit,
    -- 
    ROUND(AVG(foi.sale_price), 2)                      AS avg_item_price,
    ROUND(SUM(foi.sale_price) / COUNT(DISTINCT foi.order_id), 2) AS avg_order_value,
    -- （）
    ROUND(SUM(foi.gross_profit) / SUM(foi.sale_price) * 100, 2) AS overall_margin_pct,
    -- 
    ROUND(SUM(foi.is_returned) * 100.0 / COUNT(*), 2)  AS return_rate_pct,
    -- 
    ROUND(SUM(foi.sale_price) / COUNT(DISTINCT foi.customer_key), 2) AS revenue_per_customer
FROM fct_order_items foi
JOIN dim_products dp ON foi.product_key = dp.product_key
WHERE foi.order_status NOT IN ('Cancelled')
  AND foi.order_date_key >= '2025-01-01'    -- 时间过滤：只看最近一年，可调整
GROUP BY dp.department
ORDER BY revenue DESC;

-- =============================================================================
-- 8. PRODUCT AFFINITY — FREQUENTLY BOUGHT TOGETHER (PAIR ANALYSIS)
-- Business Question: Which product categories tend to appear in the same order?
-- Skills: Self-join, pair analysis, support confidence lift
-- =============================================================================
-- QA check : SELECT * FROM fct_order_items LIMIT 100;
WITH valid_orders AS (
    -- （）
    SELECT DISTINCT order_id
    FROM fct_order_items
    WHERE order_status NOT IN ('Cancelled')
),
order_categories AS (
    -- （）
    SELECT DISTINCT
        foi.order_id,
        dp.category
    FROM fct_order_items foi
    JOIN dim_products dp ON foi.product_key = dp.product_key
    WHERE foi.order_status NOT IN ('Cancelled')
    ORDER BY order_id
),
category_orders AS (
    -- （）
    SELECT
        category,
        COUNT(DISTINCT order_id) AS category_order_count
    FROM order_categories
    GROUP BY category
),
total_orders AS (
    -- （）
    SELECT COUNT(*) AS total_order_count FROM valid_orders
),
pairs AS (
    -- 
    SELECT
        a.category AS category_a,
        b.category AS category_b,
        COUNT(*)   AS times_bought_together
    FROM order_categories a
    JOIN order_categories b
        ON a.order_id = b.order_id
        AND a.category < b.category   -- 避免自配对和重复方向
    GROUP BY a.category, b.category
    HAVING COUNT(*) >= 50             -- 过滤低频组合，避免噪音
)
SELECT
    p.category_a,
    p.category_b,
    p.times_bought_together,
    -- ：
    ROUND(p.times_bought_together * 100.0 / t.total_order_count, 2) AS support_pct,
    --  A→B： A ， B 
    ROUND(p.times_bought_together * 100.0 / ca.category_order_count, 2) AS confidence_a_to_b,
    --  B→A： B ， A 
    ROUND(p.times_bought_together * 100.0 / cb.category_order_count, 2) AS confidence_b_to_a,
    -- ： (A × B)
    ROUND(
        (p.times_bought_together * 1.0 / t.total_order_count)
        / ((ca.category_order_count * 1.0 / t.total_order_count)
           * (cb.category_order_count * 1.0 / t.total_order_count)),
        2
    ) AS lift
FROM pairs p
JOIN category_orders ca ON p.category_a = ca.category
JOIN category_orders cb ON p.category_b = cb.category
CROSS JOIN total_orders t
ORDER BY p.times_bought_together DESC
LIMIT 20;

-- =============================================================================
-- 9. DISTRIBUTION CENTER PERFORMANCE
-- Business Question: Which distribution centers are most effective?
-- Skills: JOIN to dim_products (which includes DC info), operational analysis
-- Notes:
--   - avg_delivery_days （delivery_days IS NOT NULL）
--   - return_rate_pct 
--   - ：
-- =============================================================================

SELECT
    dp.distribution_center_name,
    -- 
    COUNT(DISTINCT dp.product_key)                          AS products_served,
    COUNT(DISTINCT foi.order_id)                            AS total_orders,
    COUNT(*)                                                AS items_shipped,
    -- 
    ROUND(SUM(foi.sale_price), 2)                           AS revenue,
    ROUND(SUM(foi.gross_profit), 2)                         AS gross_profit,
    ROUND(SUM(foi.gross_profit) / SUM(foi.sale_price) * 100, 2) AS margin_pct,
    -- 
    ROUND(SUM(foi.sale_price) / COUNT(DISTINCT foi.order_id), 2) AS avg_order_value,
    ROUND(AVG(foi.sale_price), 2)                           AS avg_item_price,
    -- 
    ROUND(AVG(foi.delivery_days), 1)                        AS avg_delivery_days,
    CASE
        WHEN AVG(foi.delivery_days) <= 3 THEN 'Fast'
        WHEN AVG(foi.delivery_days) <= 5 THEN 'Average'
        ELSE 'Slow'
    END                                                     AS delivery_speed,
    -- 
    ROUND(SUM(foi.is_returned) * 100.0 / COUNT(*), 2)       AS return_rate_pct,
    -- 
    RANK() OVER (ORDER BY SUM(foi.sale_price) DESC)         AS revenue_rank
FROM fct_order_items foi
JOIN dim_products dp ON foi.product_key = dp.product_key
WHERE foi.order_status NOT IN ('Cancelled')
  AND dp.distribution_center_name IS NOT NULL
  AND foi.order_date_key >= '2025-01-01'    -- 时间过滤，可调整
GROUP BY dp.distribution_center_name
ORDER BY revenue DESC;