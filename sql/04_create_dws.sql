-- TheLook Ecommerce Analytics - DWS Summary Layer DWS 
-- Purpose: Build reusable subject-level summary tables from dim fact tables.
-- Grain: Each table has its own analytical grain and is designed for repeated downstream analysis.

DROP DATABASE IF EXISTS thelook_ecommerce_dws;
CREATE DATABASE IF NOT EXISTS thelook_ecommerce_dws
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE thelook_ecommerce_dws;

-- Business question: Which categories drive daily order volume, revenue, margin, and
-- item-level return/cancellation rates? Counts include all order-item statuses; revenue
-- and profit should exclude cancelled items for consistent net sales reporting.
DROP TABLE IF EXISTS dws_daily_sales;
CREATE TABLE dws_daily_sales AS
SELECT
    f.order_date_key AS order_date,
    p.category,
    p.department,
    COUNT(DISTINCT f.order_id) AS order_count,
    COUNT(*) AS item_count,
    COUNT(DISTINCT f.customer_key) AS customer_count,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.sale_price ELSE 0 END), 2) AS revenue,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.gross_profit ELSE 0 END), 2) AS gross_profit,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.gross_profit ELSE 0 END)
        / NULLIF(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.sale_price ELSE 0 END), 0) * 100, 2) AS margin_pct,
    ROUND(SUM(f.is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct,
    ROUND(SUM(f.is_cancelled) * 100.0 / COUNT(*), 2) AS cancel_rate_pct
FROM thelook_ecommerce_dw.fct_order_items f
JOIN thelook_ecommerce_dw.dim_products p ON f.product_key = p.product_key
GROUP BY f.order_date_key, p.category, p.department;

-- Business question: How are monthly net sales, order volume, customer reach, and margin
-- changing over time? Cancelled items are excluded from revenue and margin.
DROP TABLE IF EXISTS dws_monthly_sales;
CREATE TABLE dws_monthly_sales AS
SELECT
    CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE) AS order_month,
    COUNT(DISTINCT order_id) AS order_count,
    COUNT(*) AS item_count,
    COUNT(DISTINCT customer_key) AS customer_count,
    ROUND(SUM(CASE WHEN order_status <> 'Cancelled' THEN sale_price ELSE 0 END), 2) AS revenue,
    ROUND(SUM(CASE WHEN order_status <> 'Cancelled' THEN gross_profit ELSE 0 END), 2) AS gross_profit,
    ROUND(
        SUM(CASE WHEN order_status <> 'Cancelled' THEN gross_profit ELSE 0 END)
        / NULLIF(SUM(CASE WHEN order_status <> 'Cancelled' THEN sale_price ELSE 0 END), 0) * 100,
        2
    ) AS margin_pct
FROM thelook_ecommerce_dw.fct_order_items
GROUP BY CAST(DATE_FORMAT(order_date_key, '%Y-%m-01') AS DATE);

-- Business question: What are each customer's lifetime purchase frequency, net value,
-- recency, and return/cancellation history? The summary retains customers with no orders.
DROP TABLE IF EXISTS dws_user_order_summary;
CREATE TABLE dws_user_order_summary AS
SELECT
    c.customer_key,
    c.customer_id,
    c.gender,
    c.age_group,
    c.country,
    c.city,
    c.traffic_source,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(f.order_id) AS total_items,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.sale_price ELSE 0 END), 2) AS total_revenue,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.gross_profit ELSE 0 END), 2) AS total_gross_profit,
    MIN(CASE WHEN f.order_status <> 'Cancelled' THEN f.order_date_key END) AS first_order_date,
    MAX(CASE WHEN f.order_status <> 'Cancelled' THEN f.order_date_key END) AS last_order_date,
    DATEDIFF(CURDATE(), MAX(CASE WHEN f.order_status <> 'Cancelled' THEN f.order_date_key END)) AS recency_days,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.sale_price ELSE 0 END) / NULLIF(COUNT(DISTINCT CASE WHEN f.order_status <> 'Cancelled' THEN f.order_id END), 0), 2) AS avg_order_value,
    SUM(f.is_returned) AS returned_items,
    SUM(f.is_cancelled) AS cancelled_items
FROM thelook_ecommerce_dw.dim_customers c
LEFT JOIN thelook_ecommerce_dw.fct_order_items f ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.customer_id, c.gender, c.age_group, c.country, c.city, c.traffic_source;

-- 4. Product sales summary
DROP TABLE IF EXISTS dws_product_sales;
CREATE TABLE dws_product_sales AS
SELECT
    p.product_key,
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    p.department,
    p.distribution_center_name,
    SUM(CASE WHEN f.order_status <> 'Cancelled' THEN 1 ELSE 0 END) AS units_sold,
    COUNT(DISTINCT f.order_id) AS order_count,
    COUNT(DISTINCT f.customer_key) AS customer_count,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.sale_price ELSE 0 END), 2) AS revenue,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.gross_profit ELSE 0 END), 2) AS gross_profit,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.gross_profit ELSE 0 END) / NULLIF(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.sale_price ELSE 0 END), 0) * 100, 2) AS margin_pct,
    ROUND(SUM(f.is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct,
    ROUND(SUM(f.is_cancelled) * 100.0 / COUNT(*), 2) AS cancel_rate_pct
FROM thelook_ecommerce_dw.fct_order_items f
JOIN thelook_ecommerce_dw.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_key, p.product_id, p.product_name, p.category, p.brand, p.department, p.distribution_center_name;

-- Business question: Which customer acquisition sources produce daily order volume,
-- net revenue, average order value, and returned-item rates? Attribution uses the
-- customer's recorded acquisition source, not event-session attribution.
DROP TABLE IF EXISTS dws_channel_performance;
CREATE TABLE dws_channel_performance AS
SELECT
    c.traffic_source,
    f.order_date_key AS order_date,
    COUNT(DISTINCT c.customer_key) AS customers,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.sale_price ELSE 0 END), 2) AS revenue,
    ROUND(SUM(CASE WHEN f.order_status <> 'Cancelled' THEN f.sale_price ELSE 0 END) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS avg_order_value,
    ROUND(SUM(f.is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM thelook_ecommerce_dw.fct_order_items f
JOIN thelook_ecommerce_dw.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.traffic_source, f.order_date_key;
