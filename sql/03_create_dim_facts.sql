DROP DATABASE IF EXISTS thelook_ecommerce_dw;

-- thelook_ecommerce_dw: create dimension and fact tables
CREATE DATABASE IF NOT EXISTS thelook_ecommerce_dw
	DEFAULT CHARACTER SET utf8mb4
	DEFAULT COLLATE utf8mb4_unicode_ci;

USE thelook_ecommerce_dw;

-- =============================================================================
-- DIMENSION: dim_customers
-- Purpose: Customer demographics + acquisition info + derived features
-- Grain: One row per unique customer
-- Source: users table + order data
-- =============================================================================

DROP TABLE IF EXISTS dim_customers;
-- QA check: DESC thelook_ecommerce_dwd.users_dwd;

CREATE TABLE IF NOT EXISTS dim_customers(
	customer_key			INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Customer dimension table Auto-incrementing primary key',
	customer_id				INT UNSIGNED NOT NULL UNIQUE COMMENT 'Customer id, extracted from raw data',
	first_name				VARCHAR(30) COMMENT 'Customer first_name',
	last_name				VARCHAR(30) COMMENT 'Customer last_name',
	full_name				VARCHAR(60) COMMENT 'Customer full_name',
	email					VARCHAR(60) COMMENT 'Customer email',
	age						INT UNSIGNED COMMENT 'Customer age',
	age_group				VARCHAR(10) COMMENT '0-17, 18-24, 25-34, 35-44, 45-54, 55-64, 65+, Unknown',
	gender					VARCHAR(10) COMMENT 'Customer gender(Male/Female)',
	state					VARCHAR(150) COMMENT 'Customer state',
	street_address			VARCHAR(150) COMMENT 'Customer street address',
	postal_code				VARCHAR(20) COMMENT 'Customer postal code',
	city					VARCHAR(100) COMMENT 'Customer city',
	country					VARCHAR(50) COMMENT 'Customer country',
	latitude				DECIMAL(10,7) COMMENT 'Customer latitude',
	longitude				DECIMAL(10,7) COMMENT 'Customer longitude',
	traffic_source			VARCHAR(15) COMMENT 'Search, Organic, Facebook, Email, Display',
	registration_date		DATETIME COMMENT 'Customer registration date',
	first_order_date		DATETIME COMMENT 'Customer first order date',
	customer_tenure_days	INT UNSIGNED COMMENT 'Days since registration'
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

INSERT INTO dim_customers(
	customer_id, first_name, last_name, full_name, email, age, age_group, 
	gender, state, street_address, postal_code, city, country, latitude, 
	longitude, traffic_source, registration_date, first_order_date, customer_tenure_days
)
SELECT 
	u.id AS customer_id,
	u.first_name,
	u.last_name,
	CONCAT(u.first_name,' ',u.last_name) AS full_name,
	u.email,
	u.age,
CASE 
	WHEN u.age < 18 THEN '0-17'
	WHEN u.age BETWEEN 18 AND 24 THEN '18-24'
	WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
	WHEN u.age BETWEEN 35 AND 44 THEN '35-44'
	WHEN u.age BETWEEN 45 AND 54 THEN '45-54'
	WHEN u.age BETWEEN 55 AND 64 THEN '55-64'
	WHEN u.age >= 65 THEN '65+'
	ELSE 'Unknown'
END AS age_group,
	u.gender,
	u.state,
	u.street_address,
	u.postal_code,
	u.city,
	u.country,
	u.latitude,
	u.longitude,
	u.traffic_source,
	u.created_at_utc AS registration_date,
	tmp.first_order_date,
DATEDIFF(CURDATE(), u.created_at_utc) AS customer_tenure_days
FROM thelook_ecommerce_dwd.users_dwd u
LEFT JOIN (
	SELECT
		user_id,
		min(created_at_utc) AS first_order_date 
	FROM thelook_ecommerce_dwd.orders_dwd 
	WHERE status NOT IN ('Cancelled')
	GROUP BY user_id
) tmp
ON u.id = tmp.user_id;

-- =============================================================================
-- DIMENSION: dim_products
-- Purpose: Product catalog with cost, pricing, margin, and supply chain info
-- Grain: One row per unique product
-- Source: products + distribution_centers
-- =============================================================================
DROP TABLE IF EXISTS dim_products;
-- QA check: DESC thelook_ecommerce_dwd.products_dwd;
CREATE TABLE IF NOT EXISTS dim_products (
	product_key 					INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Products dimension table Auto-incrementing primary key',
	product_id					INT UNSIGNED NOT NULL UNIQUE COMMENT 'Product id, extracted from raw data',
	product_name				VARCHAR(300) COMMENT 'Product name',
	category					VARCHAR(45)	COMMENT 'Product category',
	brand						VARCHAR(60) COMMENT 'Product brand',
	department					VARCHAR(10) COMMENT 'Product department',
	cost						DECIMAL(10,2) COMMENT 'Product cost',
	retail_price				DECIMAL(10,2) COMMENT 'Product retail price',
	margin_amount				DECIMAL(10,2) COMMENT 'retail_price - cost',
	margin_pct					DECIMAL(10,2) COMMENT '(retail_price - cost) / retail_price * 100',
	sku							VARCHAR(50) COMMENT 'Stock keeping unit',
	distribution_center_id		INT UNSIGNED COMMENT 'Distribution center id',
	distribution_center_name    VARCHAR(50) COMMENT 'Distribution name'
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

INSERT INTO dim_products(
	product_id, product_name, category, brand, department, cost, retail_price,
	margin_amount, margin_pct, sku, distribution_center_id, distribution_center_name
)
SELECT 
	p.id,
	p.name,
	p.category,
	p.brand,
	p.department,
	p.cost,
	p.retail_price,
	p.retail_price - p.cost AS margin_amount,
CASE 
	WHEN p.retail_price > 0 THEN ROUND((p.retail_price - p.cost) / p.retail_price * 100,2)
	ELSE 0
END AS margin_pct,
p.sku,
p.distribution_center_id,
d.name AS distribution_center_name
FROM thelook_ecommerce_dwd.products_dwd p
LEFT JOIN thelook_ecommerce_dwd.distribution_centers_dwd d
ON p.distribution_center_id = d.id;

-- QA check: SELECT * FROM thelook_ecommerce_dw.dim_products;

-- =============================================================================
-- DIMENSION: dim_distribution_centers
-- Purpose: Distribution center attributes for inventory and fulfillment analysis.
-- Grain: One row per distribution center.
-- Source: distribution_centers_dwd.
-- =============================================================================
DROP TABLE IF EXISTS dim_distribution_centers;

CREATE TABLE IF NOT EXISTS dim_distribution_centers (
    distribution_center_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Distribution center surrogate key',
    distribution_center_id  INT UNSIGNED NOT NULL UNIQUE COMMENT 'Distribution center ID from source',
    distribution_center_name VARCHAR(50) COMMENT 'Distribution center name',
    latitude                DECIMAL(10,7) COMMENT 'Distribution center latitude',
    longitude               DECIMAL(10,7) COMMENT 'Distribution center longitude'
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

INSERT INTO dim_distribution_centers (
    distribution_center_id, distribution_center_name, latitude, longitude
)
SELECT
    id AS distribution_center_id,
    name AS distribution_center_name,
    latitude,
    longitude
FROM thelook_ecommerce_dwd.distribution_centers_dwd;

-- =============================================================================
-- DIMENSION: dim_order_status
-- Purpose: Standardized order and order-item status values.
-- Grain: One row per status.
-- Source: orders_dwd + order_items_dwd.
-- =============================================================================
DROP TABLE IF EXISTS dim_order_status;

CREATE TABLE IF NOT EXISTS dim_order_status (
    order_status_key  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Order status surrogate key',
    order_status      VARCHAR(20) NOT NULL UNIQUE COMMENT 'Order or order-item status',
    status_group      VARCHAR(30) COMMENT 'Business status group',
    is_success_status TINYINT NOT NULL COMMENT '1 = shipped/complete/returned, 0 = cancelled/processing',
    is_terminal_status TINYINT NOT NULL COMMENT '1 = final status, 0 = still in process'
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

INSERT INTO dim_order_status (order_status, status_group, is_success_status, is_terminal_status)
SELECT
    s.order_status,
    CASE
        WHEN s.order_status = 'Complete' THEN 'Completed'
        WHEN s.order_status = 'Returned' THEN 'Returned'
        WHEN s.order_status = 'Cancelled' THEN 'Cancelled'
        WHEN s.order_status = 'Shipped' THEN 'In Fulfillment'
        WHEN s.order_status = 'Processing' THEN 'In Progress'
        ELSE 'Other'
    END AS status_group,
    CASE WHEN s.order_status IN ('Complete', 'Returned', 'Shipped') THEN 1 ELSE 0 END AS is_success_status,
    CASE WHEN s.order_status IN ('Complete', 'Returned', 'Cancelled') THEN 1 ELSE 0 END AS is_terminal_status
FROM (
    SELECT DISTINCT status AS order_status FROM thelook_ecommerce_dwd.orders_dwd WHERE status IS NOT NULL
    UNION
    SELECT DISTINCT status AS order_status FROM thelook_ecommerce_dwd.order_items_dwd WHERE status IS NOT NULL
) s;

-- =============================================================================
-- DIMENSION: dim_traffic_sources
-- Purpose: Traffic source values for acquisition, channel, and funnel analysis.
-- Grain: One row per traffic source.
-- Source: users_dwd + events_dwd.
-- =============================================================================
DROP TABLE IF EXISTS dim_traffic_sources;

CREATE TABLE IF NOT EXISTS dim_traffic_sources (
    traffic_source_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Traffic source surrogate key',
    traffic_source     VARCHAR(30) NOT NULL UNIQUE COMMENT 'Traffic source name',
    source_group       VARCHAR(30) COMMENT 'High-level source group'
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

INSERT INTO dim_traffic_sources (traffic_source, source_group)
SELECT
    s.traffic_source,
    CASE
        WHEN s.traffic_source IN ('Email') THEN 'Owned'
        WHEN s.traffic_source IN ('Organic') THEN 'Organic'
        WHEN s.traffic_source IN ('Facebook', 'Adwords', 'YouTube', 'Display') THEN 'Paid'
        WHEN s.traffic_source IN ('Search') THEN 'Search'
        ELSE 'Other'
    END AS source_group
FROM (
    SELECT DISTINCT traffic_source FROM thelook_ecommerce_dwd.users_dwd WHERE traffic_source IS NOT NULL
    UNION
    SELECT DISTINCT traffic_source FROM thelook_ecommerce_dwd.events_dwd WHERE traffic_source IS NOT NULL
) s;

-- =============================================================================
-- DIMENSION: dim_date
-- Purpose: Calendar date attributes for date-based analysis and reporting.
-- Grain: One row per calendar date.
-- Source: Generated date range.
-- =============================================================================
DROP TABLE IF EXISTS dim_date ;
CREATE TABLE IF NOT EXISTS dim_date (

	date_key		DATE		PRIMARY KEY COMMENT 'Calendar date (YYYY--MM--DD)',
	year_num 		INT 		NOT NULL COMMENT 'Year',
	quarter_num		INT 		NOT NULL COMMENT 'Quarter(1-4)',
	month_num		INT 		NOT NULL COMMENT 'Month(1-12)',
	month_name		VARCHAR(15) NOT NULL COMMENT 'Month name (January,...)',
	week_of_year 	INT			NOT NULL COMMENT 'ISO week number',
	iso_year_week	INT			NOT NULL COMMENT 'ISO year-week(e.g., 202601)',
	day_of_month	INT 		NOT NULL COMMENT 'Day of month(1-31)',
	day_of_week		INT			NOT NULL COMMENT 'Day of week(1=Monday,7=Sunday)',
	day_of_name		VARCHAR(10) NOT NULL COMMENT 'Day of name(Monday,...)',
	is_weekend		TINYINT		NOT NULL COMMENT '1 = weekend, 0 = weekday',
	fiscal_quarter	VARCHAR(10) NOT NULL COMMENT 'Fiscal quarter (e.g., FY2026-Q1)'
)ENGINE = InnoDB
 DEFAULT CHARSET=utf8mb4
 COLLATE=utf8mb4_unicode_ci;

SET SESSION cte_max_recursion_depth = 10000;

INSERT INTO dim_date (
	date_key, year_num, quarter_num, month_num, month_name, week_of_year, iso_year_week, 
	day_of_month, day_of_week, day_of_name, is_weekend, fiscal_quarter
)
WITH RECURSIVE date_range AS (
	SELECT CAST('2018-10-01' AS DATE ) AS d
	UNION ALL 
	SELECT d + INTERVAL 1 DAY 
	FROM date_range
	WHERE d < '2026-12-31'
)
SELECT 
	d AS date_key,
	YEAR(d) AS year_num,
	QUARTER(d) quarter_num,
	MONTH(d) AS month_num,
	MONTHNAME(d) AS month_name,
	WEEK(d,3) AS week_of_year,
	YEARWEEK(d,3) AS iso_year_week,
	DAY(d) AS day_of_month,
	WEEKDAY(d) + 1 AS day_of_week,
	DAYNAME(d) AS day_of_name,
	CASE WHEN WEEKDAY(d) IN (5,6) THEN 1 ELSE 0 END AS is_weekend,
	CONCAT('FY', YEAR(d), '-Q',QUARTER(d)) AS fiscal_quarter
FROM date_range;

	
-- ============================================================
-- FACT: fct_order_items
-- Grain: One row per order item.
-- Source: order_items_dwd + dim_customers + dim_products + dim_order_status.
--
-- Known data quality issue:
--   TheLook source data generates shipped_at as created_at + Uniform(-3, +12) days.
--   About 20% of rows therefore have shipped_at_utc < created_at_utc.
--   This is a source-level issue, not introduced by the ETL.
--
--   Mitigation:
--     1. Original timestamps are kept as-is (source-faithful, not modified).
--     2. is_time_inverted flags affected rows so downstream can filter them out.
--     3. ship_days delivery_days are clamped to >= 0 via GREATEST(0, ...).
-- ============================================================
DROP TABLE IF EXISTS fct_order_items;

CREATE TABLE fct_order_items (
    order_item_key      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate key',
    order_item_id       INT UNSIGNED    NOT NULL COMMENT 'Order item ID from source',
    order_id            INT UNSIGNED    NOT NULL COMMENT 'Order ID',
    customer_key        INT UNSIGNED    COMMENT 'FK to dim_customers',
    product_key         INT UNSIGNED    COMMENT 'FK to dim_products',
    order_date_key      DATE            COMMENT 'FK to dim_date',
    inventory_item_id   INT UNSIGNED    COMMENT 'Inventory item ID from source',
    order_status_key    INT UNSIGNED    COMMENT 'FK to dim_order_status',
    order_status        VARCHAR(20)     NOT NULL COMMENT 'Degenerate dimension: Complete, Shipped, ...',

    -- Measures
    sale_price          DECIMAL(10,2)   NOT NULL COMMENT 'Actual price paid',
    retail_price        DECIMAL(10,2)   COMMENT 'Product retail price snapshot',
    discount_amount     DECIMAL(10,2)   COMMENT 'retail_price - sale_price',
    discount_pct        DECIMAL(5,2)    COMMENT 'Discount percentage',
    product_cost        DECIMAL(10,2)   COMMENT 'Product cost',
    gross_profit        DECIMAL(10,2)   COMMENT 'sale_price - product_cost',
    margin_pct          DECIMAL(5,2)    COMMENT 'gross_profit / sale_price * 100',

    -- Original timestamps (full precision, source-faithful)
    created_at_utc      DATETIME        COMMENT 'Order created time (UTC)',
    shipped_at_utc      DATETIME        COMMENT 'Shipped time (UTC)',
    delivered_at_utc    DATETIME        COMMENT 'Delivered time (UTC)',
    returned_at_utc     DATETIME        COMMENT 'Returned time (UTC)',

    -- Derived durations (clamped to >= 0 to neutralize source time inversion)
    ship_days           INT             COMMENT 'Days from created to shipped; clamped to >= 0',
    delivery_days       INT             COMMENT 'Days from shipped to delivered; clamped to >= 0',

    -- Status flags
    is_success          TINYINT DEFAULT 0 COMMENT '1 = Complete/Shipped',
    is_returned         TINYINT DEFAULT 0 COMMENT '1 = returned',
    is_cancelled        TINYINT DEFAULT 0 COMMENT '1 = cancelled',

    -- Data quality flag
    is_time_inverted    TINYINT DEFAULT 0 COMMENT '1 = shipped_at_utc < created_at_utc; source data quality issue, not ETL',

    CONSTRAINT fk_fct_oi_customer
        FOREIGN KEY (customer_key) REFERENCES dim_customers(customer_key),
    CONSTRAINT fk_fct_oi_product
        FOREIGN KEY (product_key) REFERENCES dim_products(product_key),
    CONSTRAINT fk_fct_oi_date
        FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
    CONSTRAINT fk_fct_oi_status
        FOREIGN KEY (order_status_key) REFERENCES dim_order_status(order_status_key)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Order items fact table';

INSERT INTO fct_order_items (
    order_item_id, order_id, customer_key, product_key, order_date_key,
    inventory_item_id, order_status_key, order_status,
    sale_price, retail_price, discount_amount, discount_pct,
    product_cost, gross_profit, margin_pct,
    created_at_utc, shipped_at_utc, delivered_at_utc, returned_at_utc,
    ship_days, delivery_days,
    is_success, is_returned, is_cancelled, is_time_inverted
)
SELECT
    oi.id AS order_item_id,
    oi.order_id,
    dc.customer_key,
    dp.product_key,
    DATE(oi.created_at_utc) AS order_date_key,
    oi.inventory_item_id,
    ds.order_status_key,
    oi.status AS order_status,

    -- Measures
    oi.sale_price,
    dp.retail_price,
    dp.retail_price - oi.sale_price AS discount_amount,
    CASE
        WHEN dp.retail_price > 0
        THEN (dp.retail_price - oi.sale_price) / dp.retail_price * 100
        ELSE NULL
    END AS discount_pct,
    dp.cost AS product_cost,
    oi.sale_price - dp.cost AS gross_profit,
    CASE
        WHEN oi.sale_price > 0
        THEN (oi.sale_price - dp.cost) / oi.sale_price * 100
        ELSE NULL
    END AS margin_pct,

    -- Original timestamps (source-faithful, not modified)
    oi.created_at_utc,
    oi.shipped_at_utc,
    oi.delivered_at_utc,
    oi.returned_at_utc,

    -- Derived durations: clamped to >= 0 to neutralize time inversion
    CASE
        WHEN oi.created_at_utc IS NOT NULL AND oi.shipped_at_utc IS NOT NULL
        THEN GREATEST(0, DATEDIFF(oi.shipped_at_utc, oi.created_at_utc))
        ELSE NULL
    END AS ship_days,
    CASE
        WHEN oi.shipped_at_utc IS NOT NULL AND oi.delivered_at_utc IS NOT NULL
        THEN GREATEST(0, DATEDIFF(oi.delivered_at_utc, oi.shipped_at_utc))
        ELSE NULL
    END AS delivery_days,

    -- Status flags
    CASE WHEN oi.status IN ('Complete', 'Shipped') THEN 1 ELSE 0 END AS is_success,
    CASE WHEN oi.status = 'Returned'  THEN 1 ELSE 0 END AS is_returned,
    CASE WHEN oi.status = 'Cancelled' THEN 1 ELSE 0 END AS is_cancelled,

    -- Time inversion flag: marks source rows where shipped < created
    CASE
        WHEN oi.created_at_utc IS NOT NULL
         AND oi.shipped_at_utc IS NOT NULL
         AND oi.shipped_at_utc < oi.created_at_utc THEN 1
        ELSE 0
    END AS is_time_inverted

FROM thelook_ecommerce_dwd.order_items_dwd oi
LEFT JOIN dim_customers   dc ON oi.user_id    = dc.customer_id
LEFT JOIN dim_products    dp ON oi.product_id = dp.product_id
LEFT JOIN dim_order_status ds ON oi.status    = ds.order_status;


-- ===================================================================
-- FACT: fct_orders
-- Purpose : Order-level fact table for order count, AOV, status, and fulfillment analysis.
-- Grain: One row per order.
-- Source: orders_dwd + fct_order_items aggregation.
-- ===================================================================
DROP TABLE IF EXISTS fct_orders;

CREATE TABLE fct_orders (
    order_key           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Surrogate key',
    order_id            INT UNSIGNED NOT NULL UNIQUE COMMENT 'Order ID from source',
    customer_key        INT UNSIGNED COMMENT 'FK to dim_customers',
    order_date_key      DATE COMMENT 'FK to dim_date',
    order_status_key    INT UNSIGNED COMMENT 'FK to dim_order_status',
    order_status        VARCHAR(20) NOT NULL COMMENT 'Degenerate dimension: order status',

    -- Customer gender as recorded at order time (snapshot, not current value)
    customer_gender_at_order VARCHAR(10) COMMENT 'Customer gender snapshot at order time',

    -- Item count declared by the source system in orders_dwd.
    -- Used to cross-check against actual order item rows (see has_item_mismatch).
    num_of_item         INT UNSIGNED COMMENT 'Source-declared item count from orders_dwd',
    
    -- Actual number of item rows found in fct_order_items for this order.
    -- Includes all statuses (Complete Shipped Cancelled Returned).
    order_item_count    INT UNSIGNED COMMENT 'Actual item rows from fct_order_items',
    
    -- Item count excluding Cancelled items.
    -- Aligned with order_gross_amount so that amount count yields a consistent average.
    valid_item_count    INT UNSIGNED COMMENT 'Item count excluding Cancelled',


    -- Gross revenue: sum of non-cancelled item sale prices.
    -- Returned items are still included here, because the sale originally happened.
    -- Use this for GMV gross sales analysis.
    order_gross_amount  DECIMAL(12,2) COMMENT 'Gross: sum of non-cancelled items (includes Returned)',
    
    -- Net revenue: sum of non-cancelled AND non-returned item sale prices.
    -- Use this for realized revenue P&L analysis.
    order_net_amount    DECIMAL(12,2) COMMENT 'Net: sum of non-cancelled, non-returned items',
    
    -- Gross profit: sum of (sale_price - product_cost) for non-cancelled items.
    -- Same scope as order_gross_amount so that profit margin stays consistent.
    order_gross_profit  DECIMAL(12,2) COMMENT 'Gross profit for non-cancelled items',
    
    -- Average sale price per valid (non-cancelled) item.
    -- NULL when the order has no valid items (e.g. all items cancelled), because the average is undefined.
    avg_item_price      DECIMAL(10,2) COMMENT 'Avg price of non-cancelled items; NULL if none',

    -- Timestamps (order lifecycle milestones)
    created_at_utc      DATETIME COMMENT 'Order created time',
    shipped_at_utc      DATETIME COMMENT 'Order shipped time',
    delivered_at_utc    DATETIME COMMENT 'Order delivered time',
    returned_at_utc     DATETIME COMMENT 'Order returned time',

    -- Derived fulfillment durations
    ship_days           INT COMMENT 'Days from created to shipped',
    delivery_days       INT COMMENT 'Days from shipped to delivered',

    -- Status flags
    -- 1 = order reached a successful fulfilled state (Complete or Shipped).
    -- Mirrors is_success in fct_order_items for consistent filtering across fact tables.
    is_success          TINYINT DEFAULT 0 COMMENT '1 = Complete/Shipped',
    is_returned         TINYINT DEFAULT 0 COMMENT '1 = returned order',
    is_cancelled        TINYINT DEFAULT 0 COMMENT '1 = cancelled order',

    -- Data quality flag
    -- 1 = source-declared item count (num_of_item) does not match actual item rows (order_item_count).
    -- Useful for detecting missing order items, deleted products, or upstream data issues.
    has_item_mismatch   TINYINT DEFAULT 0 COMMENT '1 = num_of_item <> order_item_count',

    CONSTRAINT fk_fct_orders_customer
        FOREIGN KEY (customer_key) REFERENCES dim_customers(customer_key),
    CONSTRAINT fk_fct_orders_date
        FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
    CONSTRAINT fk_fct_orders_status
        FOREIGN KEY (order_status_key) REFERENCES dim_order_status(order_status_key)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Order-level fact table';

INSERT INTO fct_orders (
    order_id, customer_key, order_date_key, order_status_key, order_status,
    customer_gender_at_order,
    num_of_item, order_item_count, valid_item_count,
    order_gross_amount, order_net_amount, order_gross_profit, avg_item_price,
    created_at_utc, shipped_at_utc, delivered_at_utc, returned_at_utc,
    ship_days, delivery_days,
    is_success, is_returned, is_cancelled,
    has_item_mismatch
)
SELECT
    o.order_id,
    dc.customer_key,
    DATE(o.created_at_utc) AS order_date_key,
    ds.order_status_key,
    o.status AS order_status,
    o.gender AS customer_gender_at_order,
    o.num_of_item,
    COALESCE(oi.order_item_count, 0) AS order_item_count,
    COALESCE(oi.valid_item_count, 0) AS valid_item_count,
    COALESCE(oi.order_gross_amount, 0) AS order_gross_amount,
    COALESCE(oi.order_net_amount, 0) AS order_net_amount,
    COALESCE(oi.order_gross_profit, 0) AS order_gross_profit,
    oi.avg_item_price,
    o.created_at_utc,
    o.shipped_at_utc,
    o.delivered_at_utc,
    o.returned_at_utc,
    CASE
        WHEN o.created_at_utc IS NOT NULL AND o.shipped_at_utc IS NOT NULL
        THEN DATEDIFF(o.shipped_at_utc, o.created_at_utc)
        ELSE NULL
    END AS ship_days,
    CASE
        WHEN o.shipped_at_utc IS NOT NULL AND o.delivered_at_utc IS NOT NULL
        THEN DATEDIFF(o.delivered_at_utc, o.shipped_at_utc)
        ELSE NULL
    END AS delivery_days,
    CASE WHEN o.status IN ('Complete', 'Shipped') THEN 1 ELSE 0 END AS is_success,
    CASE WHEN o.status = 'Returned' THEN 1 ELSE 0 END AS is_returned,
    CASE WHEN o.status = 'Cancelled' THEN 1 ELSE 0 END AS is_cancelled,
    CASE
        WHEN COALESCE(o.num_of_item, 0) <> COALESCE(oi.order_item_count, 0) THEN 1
        ELSE 0
    END AS has_item_mismatch
FROM thelook_ecommerce_dwd.orders_dwd o
LEFT JOIN dim_customers dc ON o.user_id = dc.customer_id
LEFT JOIN dim_order_status ds ON o.status = ds.order_status
LEFT JOIN (
    SELECT
        order_id,
        COUNT(*) AS order_item_count,
        SUM(CASE WHEN order_status <> 'Cancelled' THEN 1 ELSE 0 END) AS valid_item_count,
        -- Gross revenue: excludes Cancelled items only.
        ROUND(SUM(CASE WHEN order_status <> 'Cancelled' THEN sale_price ELSE 0 END), 2) AS order_gross_amount,
        -- Net revenue: excludes both Cancelled AND Returned items.
        ROUND(SUM(CASE WHEN order_status NOT IN ('Cancelled', 'Returned') THEN sale_price ELSE 0 END), 2) AS order_net_amount,
        -- Gross profit: excludes Cancelled items only.
        ROUND(SUM(CASE WHEN order_status <> 'Cancelled' THEN gross_profit ELSE 0 END), 2) AS order_gross_profit,
        
        -- Average sale price per valid (non-cancelled) item.
        -- Uses non-cancelled item count as the denominator to stay aligned with order_gross_amount.
        -- Returns NULL when the order has no valid items (e.g. all items cancelled),
        -- because the average is undefined in that case.
        CASE
            WHEN SUM(CASE WHEN order_status <> 'Cancelled' THEN 1 ELSE 0 END) > 0
            THEN ROUND(
                SUM(CASE WHEN order_status <> 'Cancelled' THEN sale_price ELSE 0 END)
                / SUM(CASE WHEN order_status <> 'Cancelled' THEN 1 ELSE 0 END),
                2
            )
            ELSE NULL
        END AS avg_item_price
    FROM fct_order_items
    GROUP BY order_id
) oi ON o.order_id = oi.order_id;
