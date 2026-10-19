-- TheLook Ecommerce Analytics - ADS Application Layer ADS 
-- Purpose : Create dashboard-ready and interview-ready analytical tables.
-- Note : These tables are derived from DWS and DW tables and can be used directly in BI dashboards.

DROP DATABASE IF EXISTS thelook_ecommerce_ads;
CREATE DATABASE IF NOT EXISTS thelook_ecommerce_ads
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE thelook_ecommerce_ads;

-- Business question: How are monthly net revenue, order value, customer reach, and
-- month-over-month growth changing? Net sales inherit the cancellation policy from DWS.
DROP TABLE IF EXISTS ads_sales_dashboard;
CREATE TABLE ads_sales_dashboard AS
WITH monthly AS (
    SELECT
        order_month,
        order_count,
        item_count,
        customer_count,
        revenue,
        gross_profit,
        margin_pct,
        LAG(revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
        LAG(order_count) OVER (ORDER BY order_month) AS prev_month_orders
    FROM thelook_ecommerce_dws.dws_monthly_sales
)
SELECT
    order_month,
    order_count,
    item_count,
    customer_count,
    revenue,
    gross_profit,
    margin_pct,
    ROUND(revenue / NULLIF(order_count, 0), 2) AS avg_order_value,
    ROUND((revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0) * 100, 2) AS revenue_mom_growth_pct,
    ROUND((order_count - prev_month_orders) / NULLIF(prev_month_orders, 0) * 100, 2) AS order_mom_growth_pct
FROM monthly;

-- Business question: Which active customers are champions, loyal, promising, or at
-- risk based on recency, purchase frequency, and net monetary value?
DROP TABLE IF EXISTS ads_rfm_segments;
CREATE TABLE ads_rfm_segments AS
WITH base AS (
    SELECT
        customer_key,
        customer_id,
        recency_days,
        total_orders AS frequency,
        total_revenue AS monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY total_orders ASC) AS f_score,
        NTILE(5) OVER (ORDER BY total_revenue ASC) AS m_score
    FROM thelook_ecommerce_dws.dws_user_order_summary
    WHERE total_orders > 0
)
SELECT
    customer_key,
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New or Promising'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk High Value'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        ELSE 'Regular Customers'
    END AS rfm_segment
FROM base;

-- Business question: What share of each first-purchase cohort returns to purchase in
-- subsequent months? Cancelled items are excluded; month 0 defines cohort size.
DROP TABLE IF EXISTS ads_retention_matrix;
CREATE TABLE ads_retention_matrix AS
WITH customer_cohorts AS (
    SELECT
        customer_key,
        MIN(order_date_key) - INTERVAL (DAY(MIN(order_date_key)) - 1) DAY AS cohort_month
    FROM thelook_ecommerce_dw.fct_order_items
    WHERE order_status NOT IN ('Cancelled')
    GROUP BY customer_key
),
customer_activities AS (
    SELECT DISTINCT
        f.customer_key,
        c.cohort_month,
        f.order_date_key - INTERVAL (DAY(f.order_date_key) - 1) DAY AS activity_month
    FROM thelook_ecommerce_dw.fct_order_items f
    JOIN customer_cohorts c ON f.customer_key = c.customer_key
    WHERE f.order_status NOT IN ('Cancelled')
),
cohort_data AS (
    SELECT
        cohort_month,
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
    d.cohort_month,
    s.cohort_size,
    d.month_offset,
    d.active_customers,
    ROUND(d.active_customers * 100.0 / NULLIF(s.cohort_size, 0), 2) AS retention_pct
FROM cohort_data d
JOIN cohort_sizes s ON d.cohort_month = s.cohort_month
WHERE d.month_offset BETWEEN 0 AND 12;


-- Business question: Which products lead in net revenue or unit volume, and which show
-- elevated return or low-margin signals for merchandising review?
DROP TABLE IF EXISTS ads_product_dashboard;
CREATE TABLE ads_product_dashboard AS
WITH ranked_products AS (
    SELECT
        product_key,
    product_id,
    product_name,
    category,
    brand,
    department,
    distribution_center_name,
    units_sold,
    order_count,
    customer_count,
    revenue,
    gross_profit,
    margin_pct,
    return_rate_pct,
    cancel_rate_pct,
        DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
        DENSE_RANK() OVER (ORDER BY units_sold DESC) AS units_rank
    FROM thelook_ecommerce_dws.dws_product_sales
)
SELECT
    product_key,
    product_id,
    product_name,
    category,
    brand,
    department,
    distribution_center_name,
    units_sold,
    order_count,
    customer_count,
    revenue,
    gross_profit,
    margin_pct,
    return_rate_pct,
    cancel_rate_pct,
    revenue_rank,
    units_rank,
    CASE
        WHEN return_rate_pct >= 15 THEN 'High Return'
        WHEN margin_pct < 20 THEN 'Low Margin'
        WHEN revenue_rank <= 50 THEN 'Top Revenue'
        ELSE 'Normal'
    END AS product_flag
FROM ranked_products;
