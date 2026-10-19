-- TheLook Ecommerce Analytics - Customer Lifecycle Analysis -- Purpose : Provide interview-ready business analysis queries with bilingual comments.

USE thelook_ecommerce_dw;

-- Business question: How long do customers take to place a second valid order after
-- their first, and what share repeat within 30, 60, or 90 days? Order grain is used and
-- cancelled orders are excluded. Returned orders remain included as historically placed
-- orders; use net-value analyses separately when measuring retained revenue.
WITH valid_orders AS (
    SELECT customer_key, order_id, order_date_key
    FROM fct_orders
    WHERE customer_key IS NOT NULL AND is_cancelled = 0
), ranked_orders AS (
    SELECT
        customer_key,
        order_id,
        order_date_key,
        ROW_NUMBER() OVER (PARTITION BY customer_key ORDER BY order_date_key, order_id) AS order_number,
        MIN(order_date_key) OVER (PARTITION BY customer_key) AS first_order_date
    FROM valid_orders
), repeat_gaps AS (
    SELECT customer_key, DATEDIFF(order_date_key, first_order_date) AS days_to_repeat
    FROM ranked_orders
    WHERE order_number = 2
)
SELECT
    COUNT(*) AS repeat_customers,
    ROUND(AVG(days_to_repeat), 1) AS avg_days_to_second_order,
    ROUND(AVG(CASE WHEN days_to_repeat <= 30 THEN 1.0 ELSE 0.0 END) * 100, 2) AS repeat_within_30_days_pct,
    ROUND(AVG(CASE WHEN days_to_repeat <= 60 THEN 1.0 ELSE 0.0 END) * 100, 2) AS repeat_within_60_days_pct,
    ROUND(AVG(CASE WHEN days_to_repeat <= 90 THEN 1.0 ELSE 0.0 END) * 100, 2) AS repeat_within_90_days_pct
FROM repeat_gaps;

-- TheLook Ecommerce Analytics — Customer Analysis
-- =============================================================================
-- Skills Demonstrated: JOINs, subqueries, CTEs, DATEDIFF, window functions,
--                      customer lifecycle analysis
-- =============================================================================


-- =============================================================================
-- 1. CUSTOMER ACQUISITION TREND
-- Business Question: How many new customers are we acquiring each month?
-- Logic: A customer's "acquisition month" = the month of their first order
-- =============================================================================
WITH first_orders AS (
    SELECT
        customer_key,
        MIN(order_date_key) AS first_order_date
    FROM fct_order_items 
    WHERE order_status NOT IN ('Cancelled')
    GROUP BY customer_key
)
SELECT
    CAST(DATE_FORMAT(first_order_date, '%Y-%m-01') AS DATE)  AS acquisition_month,
    COUNT(*) AS new_customers,
    -- Running total of customers acquired
    SUM(COUNT(*)) OVER (ORDER BY CAST(DATE_FORMAT(first_order_date, '%Y-%m-01') AS DATE)) AS cumulative_customers
FROM first_orders
GROUP BY CAST(DATE_FORMAT(first_order_date, '%Y-%m-01') AS DATE)
ORDER BY acquisition_month;

-- =============================================================================
-- 2. NEW VS RETURNING CUSTOMER REVENUE
-- Business Question: What share of revenue comes from new vs returning customers?
-- Logic: "New" = placing their first-ever order that month
--        "Returning" = has ordered before
-- =============================================================================
WITH first_order AS (
	SELECT 
		customer_key,
		min(order_date_key) AS first_order_date
	FROM fct_order_items
	WHERE order_status NOT IN ('Cancelled')
	GROUP BY customer_key 
),
classified_orders AS (
	SELECT 
		foi.order_date_key,
		foi.customer_key,
		foi.sale_price,
	CASE
		WHEN DATE_FORMAT(foi.order_date_key,'%Y-%m') = DATE_FORMAT(fo.first_order_date,'%Y-%m')
		THEN 'New'
		ELSE 'Returning'
	END AS customer_type
	FROM thelook_ecommerce_dw.fct_order_items foi
	JOIN first_order fo
	ON foi.customer_key = fo.customer_key 
	WHERE foi.order_status NOT IN ('Cancelled')
)
SELECT 
	DATE_FORMAT(order_date_key,'%Y-%m') AS order_month,
	customer_type,
	COUNT(DISTINCT customer_key)  AS customers,
	ROUND(SUM(sale_price), 2) AS revenue,
	round(
		sum(sale_price) / sum(sum(sale_price)) 
			OVER (PARTITION BY DATE_FORMAT(order_date_key,'%Y-%m')) * 100,
		2
	) AS pct
FROM classified_orders
GROUP BY DATE_FORMAT(order_date_key,'%Y-%m'), customer_type
ORDER BY order_month, customer_type;


-- =============================================================================
-- 3. CUSTOMER LIFETIME VALUE (CLV)
-- Business Question: What is the average lifetime value of a customer?
-- Skills: Aggregation per customer, then summary statistics
-- =============================================================================
WITH customer_ltv AS (
	SELECT 
	    foi.customer_key,
	    dc.full_name,
	    dc.country,
	    dc.traffic_source,
	    dc.age_group,
	    COUNT(DISTINCT foi.order_id)                AS total_orders,
	    ROUND(SUM(foi.sale_price), 2)               AS lifetime_revenue,
	    ROUND(SUM(foi.gross_profit), 2)             AS lifetime_profit,
	    MIN(foi.order_date_key)                     AS first_order,
	    MAX(foi.order_date_key)                     AS last_order,
	    -- Customer lifespan in days
	    DATEDIFF(MAX(foi.order_date_key), MIN(foi.order_date_key)) AS lifespan_days
	FROM fct_order_items foi
	JOIN dim_customers dc ON foi.customer_key = dc.customer_key
	WHERE foi.order_status NOT IN ('Cancelled')
	GROUP BY foi.customer_key, dc.full_name, dc.country, dc.traffic_source, dc.age_group
)
SELECT
    -- Distribution of LTV
    COUNT(*)                                      AS total_customers,
    ROUND(AVG(lifetime_revenue), 2)               AS avg_ltv,
    ROUND(MIN(lifetime_revenue), 2)               AS min_ltv,
    ROUND(MAX(lifetime_revenue), 2)               AS max_ltv,
    ROUND(AVG(total_orders), 1)                   AS avg_orders_per_customer,
    ROUND(AVG(lifespan_days), 0)                  AS avg_lifespan_days
FROM customer_ltv;

-- =============================================================================
-- 4. TOP 20 CUSTOMERS BY REVENUE
-- Business Question: Who are the highest-value customers?
-- Skills: ORDER BY, LIMIT, DENSE_RANK
-- =============================================================================
SELECT
    DENSE_RANK() OVER (ORDER BY SUM(foi.sale_price) DESC) AS customer_rank,
    dc.full_name,
    dc.country,
    dc.age_group,
    dc.traffic_source,
    COUNT(DISTINCT foi.order_id)    	AS total_orders,
    ROUND(SUM(foi.sale_price), 2)     AS lifetime_revenue,
    ROUND(SUM(foi.gross_profit), 2)   AS lifetime_profit,
    MIN(foi.order_date_key)         AS first_order,
    MAX(foi.order_date_key)         AS last_order
FROM fct_order_items foi
JOIN dim_customers dc ON foi.customer_key = dc.customer_key
WHERE foi.order_status NOT IN ('Cancelled')
GROUP BY dc.customer_key, dc.full_name, dc.country, dc.age_group, dc.traffic_source
ORDER BY lifetime_revenue DESC
LIMIT 20;

-- =============================================================================
-- 5. CUSTOMER DEMOGRAPHICS BREAKDOWN
-- Business Question: What does our customer base look like by age, gender, country?
-- Skills: Multi-dimensional GROUP BY, HAVING
-- =============================================================================

-- 5a. Revenue by Age Group and Gender
SELECT
    dc.age_group,
    dc.gender,
    COUNT(DISTINCT foi.customer_key)               AS customers,
    COUNT(DISTINCT foi.order_id)                   AS orders,
    ROUND(SUM(foi.sale_price), 2)                  AS revenue,
    ROUND(AVG(foi.sale_price), 2)                  AS avg_item_price,
    ROUND(SUM(foi.sale_price) / COUNT(DISTINCT foi.order_id), 2) AS aov
FROM fct_order_items foi
JOIN dim_customers dc ON foi.customer_key = dc.customer_key
WHERE foi.order_status NOT IN ('Cancelled')
GROUP BY dc.age_group, dc.gender
ORDER BY dc.age_group, dc.gender;


-- 5b. Revenue by Traffic Source (Acquisition Channel Effectiveness)
-- This answers: "Which marketing channel brings the most valuable customers?"
SELECT
    dc.traffic_source,
    COUNT(DISTINCT foi.customer_key)               AS customers,
    ROUND(SUM(foi.sale_price), 2)                  AS total_revenue,
    ROUND(SUM(foi.sale_price) / COUNT(DISTINCT foi.customer_key), 2) AS revenue_per_customer,
    ROUND(AVG(foi.sale_price), 2)                  AS avg_item_price,
    COUNT(DISTINCT foi.order_id)                   AS total_orders,
    ROUND(COUNT(DISTINCT foi.order_id) * 1.0 / COUNT(DISTINCT foi.customer_key), 2) AS orders_per_customer
FROM fct_order_items foi
JOIN dim_customers dc ON foi.customer_key = dc.customer_key
WHERE foi.order_status NOT IN ('Cancelled')
GROUP BY dc.traffic_source
ORDER BY total_revenue DESC;

-- =============================================================================
-- 6. ONE-TIME BUYERS VS REPEAT BUYERS
-- Business Question: What % of customers only buy once? (critical retention metric)
-- Skills: HAVING, subquery classification
-- =============================================================================
WITH customer_orders AS (
	SELECT
        customer_key,
        COUNT(DISTINCT order_id) AS order_count
    FROM fct_order_items
    WHERE order_status NOT IN ('Cancelled')
    GROUP BY customer_key
),
buyer_type AS (
    SELECT
    	customer_key,
        CASE
            WHEN order_count = 1 THEN 'One-Time Buyer'
            WHEN order_count BETWEEN 2 AND 3 THEN 'Occasional Buyer (2-3)'
            WHEN order_count BETWEEN 4 AND 6 THEN 'Regular Buyer (4-6)'
            ELSE 'Loyal Buyer (7+)'
        END AS buyer_segment,
        order_count
    FROM customer_orders
)
SELECT 
buyer_segment,
count(*)  AS customer_count,
ROUND(AVG(order_count), 1) AS avg_orders,
round(count(*) * 100.0 / SUM(count(*)) OVER () , 2) AS pct_of_customers
FROM buyer_type
GROUP BY buyer_segment
ORDER BY
    CASE buyer_segment
        WHEN 'One-Time Buyer'        THEN 1
        WHEN 'Occasional Buyer (2-3)' THEN 2
        WHEN 'Regular Buyer (4-6)'   THEN 3
        WHEN 'Loyal Buyer (7+)'      THEN 4
    END;

-- =============================================================================
-- 7. CUSTOMER LIFETIME VALUE BY ACQUISITION CHANNEL
-- Business Question: Which channel brings customers with the highest LTV?
-- Skills: Multi-level CTE, channel comparison
-- =============================================================================
WITH customer_metrics AS (
	SELECT 
		foi.customer_key,
        dc.traffic_source,
        COUNT(DISTINCT foi.order_id)               AS order_count,
        ROUND(SUM(foi.sale_price), 2)              AS lifetime_revenue,
        MIN(foi.order_date_key)                    AS first_order,
        MAX(foi.order_date_key)                    AS last_order
	FROM fct_order_items foi
    JOIN dim_customers dc ON foi.customer_key = dc.customer_key
    WHERE foi.order_status NOT IN ('Cancelled')
    GROUP BY foi.customer_key, dc.traffic_source
)
SELECT
    traffic_source,
    COUNT(*)                                     AS total_customers,
    ROUND(AVG(lifetime_revenue), 2)              AS avg_ltv,
    ROUND(AVG(order_count), 2)                   AS avg_orders,
    -- Repeat purchase rate (customers with >1 order)
    ROUND(
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    )                                            AS repeat_rate_pct,
    ROUND(AVG(DATEDIFF(last_order, first_order)), 0) AS avg_lifespan_days
FROM customer_metrics
GROUP BY traffic_source
ORDER BY avg_ltv DESC;

-- =============================================================================
-- 8. CUSTOMER GEOGRAPHY — REVENUE BY COUNTRY & CITY
-- Business Question: Where are our best customers located?
-- Skills: Multi-level aggregation, TOP-N per group
-- =============================================================================

-- Top 5 cities per country (top 5 countries)
WITH city_revenue AS (
    SELECT
        dc.country,
        dc.city,
        COUNT(DISTINCT foi.customer_key)           AS customers,
        ROUND(SUM(foi.sale_price), 2)              AS revenue,
        ROW_NUMBER() OVER (
            PARTITION BY dc.country
            ORDER BY SUM(foi.sale_price) DESC
        )                                        AS city_rank
    FROM fct_order_items foi
    JOIN dim_customers dc ON foi.customer_key = dc.customer_key
    WHERE foi.order_status NOT IN ('Cancelled')
    		AND dc.city IS NOT NULL
  			AND dc.city <> ''
    GROUP BY dc.country, dc.city
),
top_countries AS (
    SELECT country
    FROM city_revenue
    GROUP BY country
    ORDER BY SUM(revenue) DESC
    LIMIT 5
)
SELECT
    c.country,
    c.city,
    c.customers,
    c.revenue,
    c.city_rank
FROM city_revenue c
JOIN top_countries t ON c.country = t.country
WHERE c.city_rank <= 5
ORDER BY c.country, c.city_rank;
