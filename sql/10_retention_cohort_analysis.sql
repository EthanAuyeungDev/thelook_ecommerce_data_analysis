-- TheLook Ecommerce Analytics - Retention Cohort Analysis -- Purpose : Provide interview-ready business analysis queries with bilingual comments.

USE thelook_ecommerce_dw;

-- =============================================================================
-- 1. COHORT ASSIGNMENT
-- Step 1: Assign each customer to a cohort based on their first purchase month
-- Logic: Cohort = month of customer's first ever purchase
-- =============================================================================
-- This CTE is the foundation for all cohort queries below
-- We create it once and reference it throughout

WITH customer_cohorts AS (
	SELECT 
		customer_key,
		DATE_FORMAT(MIN(order_date_key) , '%Y-%m') AS cohort_month
	FROM fct_order_items
	WHERE order_status NOT IN ('Cancelled')
	GROUP BY customer_key
)
SELECT
    cohort_month,
    COUNT(*) AS cohort_size
FROM customer_cohorts
GROUP BY cohort_month
ORDER BY cohort_month;

-- =============================================================================
-- 2. COHORT RETENTION MATRIX (THE KEY DELIVERABLE)
-- Business Question: What % of customers from each cohort come back in month 1,
--                    month 2, month 3, ..., month 12?
-- Skills: Multiple CTEs, date arithmetic, conditional aggregation
-- This is the query that impresses in interviews
-- =============================================================================

-- Find the first order date for each customer
WITH customer_cohorts AS (
	SELECT 
		customer_key,
		MIN(order_date_key) - INTERVAL(DAY(MIN(order_date_key)) - 1) DAY AS cohort_month
	FROM fct_order_items
	WHERE order_status NOT IN ('Cancelled')
	GROUP BY customer_key
),
-- Find each customer's active months using MONTH(order_date_key).
-- Multiple orders by the same customer within a single month count as one active month.
customer_activities AS (
    SELECT DISTINCT
        foi.customer_key,
        cc.cohort_month,
        order_date_key - INTERVAL (DAY(order_date_key) - 1) DAY AS activity_month
    FROM fct_order_items foi
    JOIN customer_cohorts cc ON foi.customer_key = cc.customer_key
    WHERE foi.order_status NOT IN ('Cancelled')
),
cohort_data AS (
    SELECT
        cohort_month,
        -- Month offset: how many months after the cohort month
        TIMESTAMPDIFF(MONTH, cohort_month, activity_month) AS month_offset,
        COUNT(DISTINCT customer_key) AS active_customers
    FROM customer_activities
    GROUP BY cohort_month, TIMESTAMPDIFF(MONTH, cohort_month, activity_month)
),
cohort_sizes AS (
    SELECT cohort_month, active_customers AS cohort_size
    FROM cohort_data
    WHERE month_offset = 0
)
SELECT 
    cd.cohort_month,
    cs.cohort_size,
    cd.month_offset,
    cd.active_customers,
    ROUND(cd.active_customers * 100.0 / cs.cohort_size, 2) AS retention_pct
FROM cohort_data cd
JOIN cohort_sizes cs ON cd.cohort_month = cs.cohort_month
WHERE cd.month_offset <= 12
ORDER BY cd.cohort_month, cd.month_offset;

-- =============================================================================
-- 3. COHORT RETENTION MATRIX — PIVOTED FORMAT
-- Same data as above but in the classic "heatmap" format for visualization
-- Skills: Conditional aggregation (CASE WHEN + pivot pattern)
-- =============================================================================
WITH customer_cohorts AS (
	SELECT 
		customer_key,
		MIN(order_date_key) - INTERVAL(DAY(MIN(order_date_key)) - 1) DAY AS cohort_month
	FROM fct_order_items
	WHERE order_status NOT IN ('Cancelled')
	GROUP BY customer_key
),
customer_activities AS (
    SELECT DISTINCT
        foi.customer_key,
        cc.cohort_month,
        order_date_key - INTERVAL (DAY(order_date_key) - 1) DAY AS activity_month
    FROM fct_order_items foi
    JOIN customer_cohorts cc ON foi.customer_key = cc.customer_key
    WHERE foi.order_status NOT IN ('Cancelled')
),
cohort_data AS (
    SELECT
        cohort_month,
        -- Month offset: how many months after the cohort month
        TIMESTAMPDIFF(MONTH, cohort_month, activity_month) AS month_offset,
        COUNT(DISTINCT customer_key) AS active_customers
    FROM customer_activities
    GROUP BY cohort_month, TIMESTAMPDIFF(MONTH, cohort_month, activity_month)
),
cohort_sizes AS (
    SELECT cohort_month, active_customers AS cohort_size
    FROM cohort_data
    WHERE month_offset = 0
)
SELECT
    cd.cohort_month,
    cs.cohort_size,
    -- Pivot: show retention % for months 0–12 as columns
    MAX(CASE WHEN cd.month_offset = 0  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M0",
    MAX(CASE WHEN cd.month_offset = 1  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M1",
    MAX(CASE WHEN cd.month_offset = 2  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M2",
    MAX(CASE WHEN cd.month_offset = 3  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M3",
    MAX(CASE WHEN cd.month_offset = 4  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M4",
    MAX(CASE WHEN cd.month_offset = 5  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M5",
    MAX(CASE WHEN cd.month_offset = 6  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M6",
    MAX(CASE WHEN cd.month_offset = 7  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M7",
    MAX(CASE WHEN cd.month_offset = 8  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M8",
    MAX(CASE WHEN cd.month_offset = 9  THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M9",
    MAX(CASE WHEN cd.month_offset = 10 THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M10",
    MAX(CASE WHEN cd.month_offset = 11 THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M11",
    MAX(CASE WHEN cd.month_offset = 12 THEN ROUND(cd.active_customers * 100.0 / cs.cohort_size, 1) END) AS "M12"
FROM cohort_data cd
JOIN cohort_sizes cs ON cd.cohort_month = cs.cohort_month
GROUP BY cd.cohort_month, cs.cohort_size
ORDER BY cd.cohort_month;

-- =============================================================================
-- 4. COHORT REVENUE ANALYSIS
-- Business Question: How much revenue does each cohort generate over time?
-- Skills: Same cohort framework but measuring revenue instead of retention
-- =============================================================================
WITH customer_cohorts AS (
    SELECT
        customer_key,
        MIN(order_date_key) - INTERVAL (DAY(MIN(order_date_key)) - 1) DAY AS cohort_month
    FROM fct_order_items
    WHERE order_status NOT IN ('Cancelled')
    GROUP BY customer_key
),
cohort_sizes AS (
    -- Total number of people in each queue, calculated independently
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_key) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
)
SELECT
    cc.cohort_month,
    cs.cohort_size,
    foi.order_date_key - INTERVAL (DAY(foi.order_date_key) - 1) DAY AS activity_month,
    TIMESTAMPDIFF(
        MONTH,
        cc.cohort_month,
        foi.order_date_key - INTERVAL (DAY(foi.order_date_key) - 1) DAY
    ) AS month_offset,
    COUNT(DISTINCT foi.customer_key)                             AS active_customers,
    ROUND(SUM(foi.sale_price), 2)                                AS cohort_revenue,
    ROUND(SUM(foi.sale_price) / COUNT(DISTINCT foi.customer_key), 2) AS revenue_per_active_customer
FROM fct_order_items foi
JOIN customer_cohorts cc ON foi.customer_key = cc.customer_key
JOIN cohort_sizes cs    ON cc.cohort_month = cs.cohort_month
WHERE foi.order_status NOT IN ('Cancelled')
GROUP BY
    cc.cohort_month,
    cs.cohort_size,
    activity_month,
    month_offset
HAVING month_offset <= 12
ORDER BY cc.cohort_month, month_offset;

-- =============================================================================
-- 5. BEST AND WORST COHORTS BY RETENTION
-- Business Question: Which cohorts retained best worst at the 3-month mark?
-- Skills: Filtering on computed metrics, business narrative
-- =============================================================================
WITH customer_cohorts AS (
    SELECT
        customer_key,
        MIN(order_date_key) - INTERVAL (DAY(MIN(order_date_key)) - 1) DAY AS cohort_month
    FROM fct_order_items
    WHERE order_status NOT IN ('Cancelled')
    GROUP BY customer_key
),
cohort_retention AS (
    SELECT
        cc.cohort_month,
        COUNT(DISTINCT cc.customer_key)          AS cohort_size,
        COUNT(DISTINCT CASE
            WHEN TIMESTAMPDIFF(
                    MONTH,
                    cc.cohort_month,
                    foi.order_date_key - INTERVAL (DAY(foi.order_date_key) - 1) DAY
                 ) = 3
            THEN foi.customer_key
        END)                                     AS active_at_month_3
    FROM customer_cohorts cc
    LEFT JOIN fct_order_items foi
        ON cc.customer_key = foi.customer_key
        AND foi.order_status NOT IN ('Cancelled')
    GROUP BY cc.cohort_month
    HAVING COUNT(DISTINCT cc.customer_key) >= 50
)
SELECT
    cohort_month,
    cohort_size,
    active_at_month_3,
    ROUND(active_at_month_3 * 100.0 / cohort_size, 2) AS retention_3m_pct,
    CASE
        WHEN active_at_month_3 * 100.0 / cohort_size >= 10 THEN 'STRONG'
        WHEN active_at_month_3 * 100.0 / cohort_size >= 5  THEN 'AVERAGE'
        ELSE 'WEAK'
    END AS retention_rating
FROM cohort_retention
ORDER BY retention_3m_pct DESC;

-- =============================================================================
-- 6. MONTHLY REPEAT PURCHASE RATE
-- Business Question: What % of customers who bought in month N also bought in month N+1?
-- Skills: Self-join on consecutive months, retention rate
-- =============================================================================
WITH month_customer AS (
	SELECT DISTINCT 
	customer_key,
	order_date_key - INTERVAL (DAY(order_date_key) - 1) DAY AS order_month
	FROM fct_order_items
	WHERE order_status NOT IN ('Cancelled')
),
retention AS (
	SELECT 
	cur.order_month,
	count(cur.customer_key) AS customers_this_month,
	count(next_m.customer_key) AS retained_next_month
	FROM month_customer cur
	LEFT JOIN month_customer next_m
	ON cur.customer_key = next_m.customer_key 
		AND (cur.order_month + INTERVAL 1 MONTH ) = next_m.order_month
	GROUP BY cur.order_month
)
SELECT 
	order_month,
	customers_this_month,
	retained_next_month,
	ROUND(retained_next_month * 1.0 / customers_this_month , 2) AS retention_rate_pct,
	ROUND(1 - retained_next_month * 1.0 / customers_this_month , 2) AS churn_rate_pct
FROM retention
ORDER BY order_month;

-- =============================================================================
-- 7. ORDER GAP ANALYSIS
-- Business Question: How many days pass between consecutive customer orders?
-- Skills: LAG window function, date arithmetic
-- Interview insight: Helps define "churn" threshold (e.g., >90 days = churned)
-- =============================================================================
WITH customer_order_date AS (
	SELECT 
		sub.customer_key,
		sub.order_date_key,
		LAG(order_date_key) OVER (PARTITION BY sub.customer_key ORDER BY sub.order_date_key) AS previous_order_date
	FROM (
		SELECT DISTINCT 
		customer_key,
		order_date_key
		FROM fct_order_items
		WHERE order_status NOT IN ('Cancelled')
	) sub
),
order_gaps AS (
	SELECT 
		customer_key,
		order_date_key,
		previous_order_date,
		order_date_key - previous_order_date AS days_between_orders
	FROM customer_order_date
	WHERE previous_order_date IS NOT NULL 
)
SELECT 
	CASE WHEN days_between_orders <= 7   THEN '01. Within 1 week'
	     WHEN days_between_orders <= 14  THEN '02. 1-2 weeks'
         WHEN days_between_orders <= 30  THEN '03. 2-4 weeks'
         WHEN days_between_orders <= 60  THEN '04. 1-2 months'
         WHEN days_between_orders <= 90  THEN '05. 2-3 months'
         WHEN days_between_orders <= 180 THEN '06. 3-6 months'
         ELSE                                 '07. 6+ months'
	END AS gap_bucket,
	COUNT(*) AS occurrences,
	ROUND(
   		COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (),
   		2
   ) AS pct_of_total,
   ROUND(AVG(days_between_orders), 0) AS avg_gap_days
   FROM order_gaps
   GROUP BY 
   		CASE
			 WHEN days_between_orders <= 7   THEN '01. Within 1 week'
			 WHEN days_between_orders <= 14  THEN '02. 1-2 weeks'
			 WHEN days_between_orders <= 30  THEN '03. 2-4 weeks'
			 WHEN days_between_orders <= 60  THEN '04. 1-2 months'
			 WHEN days_between_orders <= 90  THEN '05. 2-3 months'
			 WHEN days_between_orders <= 180 THEN '06. 3-6 months'
			 ELSE                                 '07. 6+ months'
   		END
  ORDER BY gap_bucket;

-- =============================================================================
-- 8. CHURN ANALYSIS
-- Business Question: How many customers have churned (no purchase in 90+ days)?
-- Skills: Date comparison, conditional classification
-- =============================================================================
WITH customer_last_order AS (
	SELECT 
		foi.customer_key,
		dc.traffic_source,
		dc.country,
		dc.age_group,
		MAX(foi.order_date_key) AS last_order_date, 
		COUNT(DISTINCT foi.order_id) AS total_orders,
		ROUND(SUM(foi.sale_price),2) AS total_revenue
	FROM fct_order_items foi
	JOIN dim_customers dc
	ON foi.customer_key = dc.customer_key
	GROUP BY foi.customer_key, dc.traffic_source, dc.country, dc.age_group
),
churn_classified AS (
	SELECT 
	*,
	(SELECT MAX(order_date_key) FROM fct_order_items) - last_order_date AS days_since_last_order,
	CASE 
		WHEN (SELECT MAX(order_date_key) FROM fct_order_items) - last_order_date <= 30
			THEN 'Active'
		WHEN (SELECT MAX(order_date_key) FROM fct_order_items) - last_order_date <= 60
            THEN 'Warm (31-60 days)'
        WHEN (SELECT MAX(order_date_key) FROM fct_order_items) - last_order_date <= 90
            THEN 'Cooling (61-90 days)'
        WHEN (SELECT MAX(order_date_key) FROM fct_order_items) - last_order_date <= 180
            THEN 'At Risk (91-180 days)'
        ELSE 'Churned (180+ days)'
	END AS churn_status
	FROM customer_last_order
)
SELECT
churn_status,
COUNT(*) AS customers,
ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
ROUND(AVG(total_orders), 2) AS avg_orders,
ROUND(AVG(total_revenue),2) AS avg_revenue,
ROUND(SUM(total_revenue),2) AS group_total_revenue
FROM churn_classified
GROUP BY churn_status
ORDER BY 
	CASE churn_status 
		WHEN 'Active' THEN 1
		WHEN 'Warm (31-60 days)' THEN 2
		WHEN 'Cooling (61-90 days)' THEN 3
		WHEN 'At Risk (91-180 days)' THEN 4
		WHEN 'Churned (180+ days)' THEN 5
	END;

-- =============================================================================
-- 9. RETENTION BY ACQUISITION CHANNEL
-- Business Question: Which traffic source has the best long-term retention?
-- Skills: Multi-CTE pipeline, channel comparison
-- =============================================================================
WITH customer_cohorts AS (
	SELECT 
	foi.customer_key,
	dc.traffic_source,
	MIN(foi.order_date_key) AS first_order_date
	FROM fct_order_items foi
	JOIN dim_customers dc
	ON foi.customer_key = dc.customer_key
	WHERE foi.order_status NOT IN ('Cancelled')
	GROUP BY foi.customer_key, dc.traffic_source
),
customer_activity AS (
    SELECT DISTINCT
        foi.customer_key,
        cc.traffic_source,
        cc.first_order_date,
        foi.order_date_key
    FROM fct_order_items foi
    JOIN customer_cohorts cc ON foi.customer_key = cc.customer_key
    WHERE foi.order_status NOT IN ('Cancelled')
)
SELECT 
	traffic_source,
	COUNT(DISTINCT customer_key) AS total_customers,
	-- 30-day retention
	ROUND(
		COUNT(DISTINCT 
			CASE WHEN order_date_key - first_order_date BETWEEN 1 AND 30 THEN customer_key 
			END 
			) * 100.0 / COUNT(DISTINCT customer_key), 2
		) AS retention_30d_pct,
	-- 60-day retention
	ROUND(
		COUNT(DISTINCT 
			CASE WHEN order_date_key - first_order_date BETWEEN 31 AND 60 THEN customer_key 
			END 
			) * 100.0 / COUNT(DISTINCT customer_key), 2
		) AS retention_60d_pct,	
	-- 90-day retention
	ROUND(
		COUNT(DISTINCT 
			CASE WHEN order_date_key - first_order_date BETWEEN 61 AND 90 THEN customer_key 
			END 
			) * 100.0 / COUNT(DISTINCT customer_key), 2
		) AS retention_90d_pct
FROM customer_activity
GROUP BY traffic_source;

-- =============================================================================
-- 10. RETENTION BY FIRST PURCHASE CATEGORY
-- Business Question: Does the category of first purchase affect retention?
-- Skills: Subquery for first purchase, JOIN to product, retention calc
-- Interview insight: Actionable for onboarding strategy

WITH first_order_category AS (
    SELECT
        f.customer_key,
        f.order_date_key,
        p.category,
        SUM(f.sale_price) AS category_revenue
    FROM fct_order_items f
    JOIN dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_status NOT IN ('Cancelled','Returned')
    GROUP BY
        f.customer_key,
        f.order_date_key,
        p.category
),
first_purchase_ranked AS (
    SELECT
        customer_key,
        order_date_key                              AS first_order_date,
        category                                    AS first_purchase_category,
        category_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY customer_key
            ORDER BY
                order_date_key ASC,                 -- earliest first order date
                category_revenue DESC,              -- for same day, pick the category with highest revenue
                category ASC                        -- tie-breaker on category name to guarantee uniqueness
        ) AS rn
    FROM first_order_category
),
-- -----------------------------------------------------------------------------
-- Step 2: Keep only rn = 1 per customer, i.e. the "first purchase category" row
-- -----------------------------------------------------------------------------
first_purchased AS (
    SELECT
        customer_key,
        first_purchase_category,
        first_order_date
    FROM first_purchase_ranked
    WHERE rn = 1
),
-- -----------------------------------------------------------------------------
-- Step 3: Repeat purchase check
-- -----------------------------------------------------------------------------

repeat_check AS (
    SELECT
        fp.customer_key,
        fp.first_purchase_category,
        fp.first_order_date,
        -- Repeat purchase in any category (0 1)
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM fct_order_items f2
                WHERE f2.customer_key = fp.customer_key
                  AND f2.order_date_key >  fp.first_order_date
                  AND f2.order_date_key <= fp.first_order_date + 90
                  AND f2.order_status NOT IN ('Cancelled','Returned')
            ) THEN 1 ELSE 0
        END AS has_repeat_any,
        -- Repeat purchase in the same category (0 1)
        -- This better answers: "does first-purchase category affect repeat purchase?"
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM fct_order_items f2
                JOIN dim_products p2
                    ON f2.product_key = p2.product_key
                WHERE f2.customer_key = fp.customer_key
                  AND f2.order_date_key >  fp.first_order_date
                  AND f2.order_date_key <= fp.first_order_date + 90
                  AND f2.order_status NOT IN ('Cancelled','Returned')
                  AND p2.category = fp.first_purchase_category
            ) THEN 1 ELSE 0
        END AS has_repeat_same,
        -- Number of repeat orders (distinct orders)
        (
            SELECT COUNT(DISTINCT f2.order_id)
            FROM fct_order_items f2
            WHERE f2.customer_key = fp.customer_key
              AND f2.order_date_key >  fp.first_order_date
              AND f2.order_date_key <= fp.first_order_date + 90
              AND f2.order_status NOT IN ('Cancelled','Returned')
        ) AS repeat_order_count
    FROM first_purchased fp
)
-- -----------------------------------------------------------------------------
-- Step 4: Aggregate by first purchase category and output repeat purchase rates
-- -----------------------------------------------------------------------------
SELECT
    first_purchase_category,
    COUNT(*)                                                AS customers,
    SUM(has_repeat_any)                                     AS repeat_any_customers,
    SUM(has_repeat_same)                                    AS repeat_same_customers,
    SUM(repeat_order_count)                                 AS repeat_orders,
    ROUND(SUM(has_repeat_any)  * 100.0 / COUNT(*), 2)       AS repeat_any_rate_pct,
    ROUND(SUM(has_repeat_same) * 100.0 / COUNT(*), 2)       AS repeat_same_rate_pct,
    ROUND(AVG(repeat_order_count), 2)                       AS avg_repeat_orders
FROM repeat_check
GROUP BY first_purchase_category
HAVING COUNT(*) >= 50                                        -- filter out small samples to avoid noise
ORDER BY repeat_same_rate_pct DESC;

