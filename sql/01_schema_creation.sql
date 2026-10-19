DROP DATABASE IF EXISTS thelook_ecommerce_ods;

CREATE DATABASE IF NOT EXISTS thelook_ecommerce_ods
	DEFAULT CHARACTER SET utf8mb4
	DEFAULT COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS thelook_ecommerce_dwd
	DEFAULT CHARACTER SET utf8mb4
	DEFAULT COLLATE utf8mb4_unicode_ci;


USE thelook_ecommerce_ods;


-- =========================================================
-- 1. users_ods table 
-- =========================================================
DROP TABLE IF EXISTS users_ods;

CREATE TABLE IF NOT EXISTS users_ods (
	id					VARCHAR(20),
	first_name			VARCHAR(20),
	last_name			VARCHAR(20),
	email				VARCHAR(100),
	age					VARCHAR(10),
	gender 				VARCHAR(10),
	state				VARCHAR(50),
	street_address		VARCHAR(150),
	postal_code			VARCHAR(20),
	city				VARCHAR(50),
	country				VARCHAR(20),
	latitude			VARCHAR(20),
	longitude			VARCHAR(20),
	traffic_source		VARCHAR(20),
	created_at			VARCHAR(60),
	user_geom			VARCHAR(100)
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv'
INTO TABLE thelook_ecommerce_ods.users_ods
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(id, first_name, last_name, email, age, gender, state, street_address, 
 postal_code, city, country, latitude, longitude, traffic_source, created_at, user_geom);

-- QA check : uncomment for manual validation.
-- SELECT * FROM users_ods LIMIT 100;
-- TRUNCATE TABLE users_ods; -- Disabled to avoid deleting loaded data accidentally. 。
 
-- =========================================================
-- 2. orders_ods table 
-- =========================================================
DROP TABLE IF EXISTS orders_ods;

CREATE TABLE IF NOT EXISTS orders_ods (
	order_id			VARCHAR(20),
	user_id				VARCHAR(20),
	status				VARCHAR(20),
	gender				VARCHAR(10),
	created_at			VARCHAR(60),
	returned_at 		VARCHAR(60),
	shipped_at			VARCHAR(60),
	delivered_at		VARCHAR(60),
	num_of_item			VARCHAR(10)
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/orders.csv'
INTO TABLE thelook_ecommerce_ods.orders_ods
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(order_id, user_id, status, gender, created_at, 
 returned_at, shipped_at, delivered_at, num_of_item);

-- SELECT * FROM orders_ods LIMIT 100;
 
 
-- =========================================================
-- 3. products_ods table 
-- =========================================================
DROP TABLE IF EXISTS products_ods;

CREATE TABLE IF NOT EXISTS products_ods (
	id						VARCHAR(20),
	cost					VARCHAR(20),
	category				VARCHAR(40),
	name					VARCHAR(300),
	brand					VARCHAR(80),
	retail_price 			VARCHAR(20),
	department				VARCHAR(10),
	sku						VARCHAR(50),
	distribution_center_id	VARCHAR(10)
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/products.csv'
INTO TABLE thelook_ecommerce_ods.products_ods
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(id, cost, category, name, brand, 
 retail_price, department, sku, distribution_center_id);

-- SELECT * FROM products_ods LIMIT 100;
-- desc products_ods;
 
 
-- =========================================================
-- 4. order_items_ods table 
-- =========================================================
DROP TABLE IF EXISTS order_items_ods;

CREATE TABLE IF NOT EXISTS order_items_ods (
	id					VARCHAR(20),
	order_id			VARCHAR(20),
	user_id				VARCHAR(20),
	product_id			VARCHAR(20),
	inventory_item_id	VARCHAR(20),
	status 				VARCHAR(20),
	created_at			VARCHAR(60),
	shipped_at			VARCHAR(60),
	delivered_at		VARCHAR(60),
	returned_at			VARCHAR(60),
	sale_price 			VARCHAR(25)
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/order_items.csv'
INTO TABLE thelook_ecommerce_ods.order_items_ods
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(id, order_id, user_id, product_id, inventory_item_id, status, 
 created_at, shipped_at, delivered_at, returned_at, sale_price);

-- SELECT * FROM order_items_ods WHERE ID IN('33556','100110');
-- desc order_items_ods;
 
 
 -- =========================================================
-- 5. distribution_centers table 
-- =========================================================
DROP TABLE IF EXISTS distribution_centers_ods;

CREATE TABLE IF NOT EXISTS distribution_centers_ods (
	id							VARCHAR(10),
	name 						VARCHAR(50),
	latitude					VARCHAR(20),
	longitude					VARCHAR(20),
	distribution_center_geom 	VARCHAR(100)
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/distribution_centers.csv'
INTO TABLE thelook_ecommerce_ods.distribution_centers_ods
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(id, name, latitude, longitude, distribution_center_geom );

-- SELECT * FROM distribution_centers_ods;
-- desc distribution_centers_ods;
 
 
-- =========================================================
-- 6. events table 
-- =========================================================
DROP TABLE IF EXISTS events_ods;

CREATE TABLE IF NOT EXISTS events_ods (
	id					VARCHAR(15),
	user_id				VARCHAR(10),
	sequence_number		VARCHAR(5),
	session_id			VARCHAR(40),
	created_at			VARCHAR(60),
	ip_address 			VARCHAR(15),
	city				VARCHAR(50),
	state				VARCHAR(40),
	postal_code			VARCHAR(15),
	browser				VARCHAR(10),
	traffic_source		VARCHAR(10),
	uri					VARCHAR(100),
	event_type			VARCHAR(20)
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/events.csv'
INTO TABLE thelook_ecommerce_ods.events_ods
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(id, user_id, sequence_number, session_id, created_at, ip_address, city, state, 
 postal_code, browser, traffic_source, uri, event_type);

-- SELECT * FROM events_ods LIMIT 100;
 
 
 -- =========================================================
-- 7. inventory_items table 
-- =========================================================
DROP TABLE IF EXISTS inventory_items_ods;

CREATE TABLE IF NOT EXISTS inventory_items_ods (
	id								VARCHAR(10),
	product_id						VARCHAR(10),
	created_at						VARCHAR(50),
	sold_at							VARCHAR(50),
	cost							VARCHAR(20),
	product_category 				VARCHAR(35),
	product_name					VARCHAR(250),
	product_brand					VARCHAR(45),
	product_retail_price			VARCHAR(20),
	product_department				VARCHAR(10),
	product_sku						VARCHAR(40),
	product_distribution_center_id	VARCHAR(5)
)ENGINE = InnoDB
 DEFAULT CHARSET = utf8mb4
 COLLATE = utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/inventory_items.csv'
INTO TABLE thelook_ecommerce_ods.inventory_items_ods
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(id, product_id, created_at, sold_at, cost, product_category, product_name, product_brand, 
 product_retail_price, product_department, product_sku, product_distribution_center_id);

-- SELECT * FROM inventory_items_ods LIMIT 100;
 