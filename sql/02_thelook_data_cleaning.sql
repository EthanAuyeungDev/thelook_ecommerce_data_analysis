-- TheLook Ecommerce Analytics - DWD data cleaning DWD 
-- Purpose : Clean and type-cast the 7 ODS source tables into analysis-ready DWD tables.

USE thelook_ecommerce_dwd;

-- ===============================================================================
-- 1. users_ods data cleaning -> users_dwd table 
-- ===============================================================================
DROP TABLE IF EXISTS users_dwd;

CREATE TABLE IF NOT EXISTS users_dwd AS (
	SELECT 
	CAST(trim(id) AS UNSIGNED) AS id, 
	CASE 	
		WHEN lower(trim(first_name)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(first_name)
	END AS first_name,
	CASE 
		WHEN lower(trim(last_name)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
	ELSE trim(last_name)
	END AS last_name,
	CASE 
		WHEN lower(trim(email)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(email)
	END AS email,
	CASE 
		WHEN trim(age) = '' THEN NULL
		ELSE cast(trim(age) AS UNSIGNED)
	END AS age,
	CASE 
		WHEN trim(gender) = 'M' THEN 'Male'
		WHEN trim(gender) = 'F' THEN 'Female'
		WHEN lower(trim(gender)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(gender)
	END AS gender,
	CASE 
		WHEN lower(trim(state)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(state)
	END AS state,
	CASE 
		WHEN lower(trim(street_address)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
	ELSE trim(street_address)
	END AS street_address,
	CASE 
		WHEN lower(trim(postal_code)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(postal_code)
	END AS postal_code,
	CASE 
		WHEN lower(trim(city)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(city)
	END AS city,
	CASE 
		WHEN lower(trim(country)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(country)
	END AS country,
	CAST(NULLIF(NULLIF(trim(latitude), ''), 'null') AS DECIMAL(10, 7)) AS latitude,
	CAST(NULLIF(NULLIF(trim(longitude), ''), 'null') AS DECIMAL(10, 7)) AS longitude,
	CASE 
		WHEN lower(trim(traffic_source)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(traffic_source)
	END AS traffic_source,
	STR_TO_DATE(LEFT(TRIM(created_at), 19), '%Y-%m-%d %H:%i:%s') AS created_at_utc
	FROM thelook_ecommerce_ods.users_ods
);

-- QA check : DESC users_dwd;

-- change the user_dwd table definition and add primary key, index
ALTER TABLE users_dwd 
	ADD PRIMARY KEY (id),
	MODIFY id 				INT UNSIGNED COMMENT 'User ID',
	MODIFY first_name  		VARCHAR(30) COMMENT 'First Name',
	MODIFY last_name		VARCHAR(30) COMMENT 'Last Name',
	MODIFY email			VARCHAR(60) COMMENT 'Email',
	MODIFY age				INT UNSIGNED COMMENT 'Age',
	MODIFY gender			VARCHAR(10) COMMENT 'Gender: Male/Female',
	MODIFY state			VARCHAR(150) COMMENT 'state',
	MODIFY street_address	VARCHAR(150) COMMENT 'Street address',
	MODIFY postal_code		VARCHAR(20) COMMENT 'Postal code',
	MODIFY city				VARCHAR(100) COMMENT 'City',
	MODIFY country			VARCHAR(50) COMMENT 'Country',
	MODIFY latitude			DECIMAL(10,7) COMMENT 'Latitude',
	MODIFY longitude		DECIMAL(10,7) COMMENT 'Longitude',
	MODIFY traffic_source	VARCHAR(15) COMMENT 'Traffic source',
	MODIFY created_at_utc	DATETIME COMMENT 'Created at(UTC)';

-- create index for email 
CREATE INDEX idx_users_dwd_email ON users_dwd (email);

-- QA check : SELECT * FROM users_dwd LIMIT 100;

-- ===============================================================================
-- 2. orders_ods table cleaning -> orders_dwd
-- ===============================================================================

DROP TABLE IF EXISTS orders_dwd;
CREATE TABLE IF NOT EXISTS orders_dwd AS (
	SELECT
	CAST(trim(order_id) AS UNSIGNED) AS order_id,
	CAST(trim(user_id) AS UNSIGNED) AS user_id,
	trim(status) AS status,
	CASE
		WHEN trim(gender) = 'F' THEN 'Female'
		WHEN trim(gender) = 'M' THEN 'Male'
		WHEN trim(gender) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(gender)
	END AS gender,
	CASE
		WHEN trim(created_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(created_at),19),'%Y-%m-%d %H:%i:%s')
	END AS created_at_utc,
	CASE
		WHEN trim(returned_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(returned_at),19),'%Y-%m-%d %H:%i:%s')
	END AS returned_at_utc,
	CASE
		WHEN trim(shipped_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(shipped_at),19),'%Y-%m-%d %H:%i:%s')
	END AS shipped_at_utc,
	CASE
		WHEN trim(delivered_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(delivered_at),19),'%Y-%m-%d %H:%i:%s')
	END AS delivered_at_utc,
	CAST(trim(num_of_item) AS UNSIGNED) AS num_of_item
	
	FROM thelook_ecommerce_ods.orders_ods
);

-- QA check : SELECT * FROM thelook_ecommerce_dwd.orders_dwd LIMIT 100;
-- QA check : DESC thelook_ecommerce_dwd.orders_dwd;

ALTER TABLE thelook_ecommerce_dwd.orders_dwd
	MODIFY order_id 	INT UNSIGNED NOT NULL COMMENT 'Order unique identifier',
	ADD PRIMARY KEY(order_id),
	MODIFY user_id  	INT UNSIGNED NOT NULL COMMENT 'User ID, references users_dwd.id',
	-- add foreign key on user_id 
-- 	ADD CONSTRAINT fk_orders_dwd_user_id 
-- 		FOREIGN KEY (user_id) REFERENCES thelook_ecommerce_dwd.users_dwd(id)
-- 		ON DELETE RESTRICT 
-- 		ON UPDATE CASCADE,
	MODIFY status 				VARCHAR(15) COMMENT 'Order status',
	MODIFY gender 				VARCHAR(10) COMMENT 'Gender: Male / Female',
	MODIFY created_at_utc 		DATETIME COMMENT 'The utc time when order was created',
	MODIFY returned_at_utc	 	DATETIME COMMENT 'The utc time when order was returned',
	MODIFY shipped_at_utc 		DATETIME COMMENT 'The utc time when order was shipped',
	MODIFY delivered_at_utc 	DATETIME COMMENT 'The utc time when order was delivered',
	MODIFY num_of_item			INT UNSIGNED COMMENT 'The number of items in each order';

-- ===============================================================================
-- 3. distribution_centers_ods table cleaning -> distribution_centers_dwd
-- ===============================================================================

DROP TABLE IF EXISTS distribution_centers_dwd;

CREATE TABLE IF NOT EXISTS distribution_centers_dwd AS (
	SELECT
	CAST(trim(id) AS UNSIGNED) AS id,
	CASE
		WHEN lower(trim(name)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(name)
	END AS name,
	CASE 
		WHEN lower(trim(latitude)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE CAST(trim(latitude) AS DECIMAL(10,7))
	END AS latitude,
	CASE 
		WHEN lower(trim(longitude)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE CAST(trim(longitude) AS DECIMAL(10,7))
	END AS longitude
	
	FROM thelook_ecommerce_ods.distribution_centers_ods
);

-- QA check : DESC thelook_ecommerce_dwd.distribution_centers_dwd;

ALTER TABLE thelook_ecommerce_dwd.distribution_centers_dwd
	MODIFY id 			INT UNSIGNED NOT NULL COMMENT 'Distribution center identifier',
	ADD PRIMARY KEY (id),
	MODIFY name			VARCHAR(50) COMMENT 'Distribution centers name',
	MODIFY latitude		DECIMAL(10,7) COMMENT 'Distribution centers latitude',
	MODIFY longitude	DECIMAL(10,7) COMMENT 'Distribution centers longitude';


-- ===============================================================================
-- 4. products_ods table cleaning -> products_dwd
-- ===============================================================================
DROP TABLE IF EXISTS thelook_ecommerce_dwd.products_dwd;
CREATE TABLE IF NOT EXISTS thelook_ecommerce_dwd.products_dwd AS (
	SELECT 
	CAST(TRIM(id) AS UNSIGNED) AS id,
	CASE 
		WHEN trim(cost) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE CAST(trim(cost) AS DECIMAL(10,2))
	END AS cost,
	CASE 
		WHEN trim(category) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(category)
	END AS category,
	CASE 
		WHEN trim(name) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(name)
	END AS name,
	CASE 
		WHEN trim(brand) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(brand)
	END AS brand,
	CASE 
		WHEN trim(retail_price) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE CAST(trim(retail_price) AS decimal(10,2))
	END AS retail_price,
	CASE 
		WHEN trim(department) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(department) 
	END AS department,
	CASE 
		WHEN trim(sku) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(sku) 
	END AS sku,	
	CASE 
		WHEN trim(distribution_center_id) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE cast(trim(distribution_center_id) AS UNSIGNED)
	END AS distribution_center_id

	FROM thelook_ecommerce_ods.products_ods
);

-- QA check : SELECT * FROM thelook_ecommerce_dwd.products_dwd LIMIT 100;
-- QA check : DESC thelook_ecommerce_dwd.products_dwd;
ALTER TABLE thelook_ecommerce_dwd.products_dwd 
	MODIFY id 						INT UNSIGNED NOT NULL COMMENT 'Product unique identifier',
	ADD PRIMARY KEY (id),
	MODIFY cost 					DECIMAL(10,2) COMMENT 'Product''s cost',
	MODIFY category					VARCHAR(45) COMMENT 'Product category',
	MODIFY name 					VARCHAR(300) COMMENT 'Product name',
	MODIFY brand 					VARCHAR(60) COMMENT 'Product brand',
	MODIFY retail_price 			DECIMAL(10,2) COMMENT 'Retail price',
	MODIFY department 				VARCHAR(10) COMMENT 'Department',
	MODIFY sku 						VARCHAR(50) COMMENT 'Stock keeping unit (hash)',
	MODIFY distribution_center_id 	INT UNSIGNED COMMENT 'Distribution center id';
	-- add fk for distribution_center_id
-- 	ADD CONSTRAINT fk_products_dwd_distribution_center_id
-- 	FOREIGN KEY (distribution_center_id) REFERENCES thelook_ecommerce_dwd.distribution_centers_dwd(id)
-- 		ON DELETE RESTRICT 
-- 		ON UPDATE CASCADE

-- ===============================================================================
-- 5. inventory_items_ods table cleaning -> inventory_items_dwd
-- ===============================================================================

DROP TABLE IF EXISTS inventory_items_dwd;

CREATE TABLE IF NOT EXISTS inventory_items_dwd AS (
	SELECT 
	CAST(trim(id) AS UNSIGNED ) AS id,
	CAST(trim(product_id) AS UNSIGNED ) AS product_id,
	CASE
		WHEN trim(created_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(created_at),19),'%Y-%m-%d %H:%i:%s')
	END AS created_at_utc,	
	CASE
		WHEN trim(sold_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(sold_at),19),'%Y-%m-%d %H:%i:%s')
	END AS sold_at_utc,	
	CAST(trim(cost) AS DECIMAL(10,2)) AS cost,
	CASE
		WHEN lower(trim(product_category)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(product_category)
	END AS product_category,	
	CASE
		WHEN lower(trim(product_name)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(product_name)
	END AS product_name,
	CASE 
		WHEN lower(trim(product_brand)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(product_brand)
	END AS product_brand,
	CAST(trim(product_retail_price) AS DECIMAL(10,2)) AS product_retail_price,
	CASE 
		WHEN lower(trim(product_department)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(product_department)
	END AS product_department,
	CASE
		WHEN lower(trim(product_sku)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(product_sku)
	END AS product_sku,
	CAST(trim(product_distribution_center_id) AS UNSIGNED) AS product_distribution_center_id
	FROM thelook_ecommerce_ods.inventory_items_ods
);

-- QA check : DESC thelook_ecommerce_dwd.inventory_items_dwd;
-- QA check : SELECT * FROM thelook_ecommerce_dwd.inventory_items_dwd LIMIT 100;
ALTER TABLE thelook_ecommerce_dwd.inventory_items_dwd
	MODIFY id								INT UNSIGNED NOT NULL COMMENT 'Inventory items unique identifier',
	ADD PRIMARY KEY (id),
	MODIFY product_id						INT UNSIGNED NOT NULL COMMENT 'Related product id, foreign key',
-- 	ADD CONSTRAINT fk_inventory_items_dwd_product_id
-- 	FOREIGN KEY (product_id) REFERENCES thelook_ecommerce_dwd.products_dwd(id)
-- 		ON DELETE RESTRICT
-- 		ON UPDATE CASCADE,
	MODIFY created_at_utc					DATETIME NOT NULL COMMENT 'The time when the item entered the warehouse',
	MODIFY sold_at_utc						DATETIME COMMENT 'The time when the product was sold out',
	MODIFY cost								DECIMAL(10,2) NOT NULL COMMENT 'Product cost',
	MODIFY product_category					VARCHAR(35) COMMENT 'Product category',
	MODIFY product_name						VARCHAR(250) COMMENT 'Product name',
	MODIFY product_brand					VARCHAR(45) COMMENT 'Product brand',
	MODIFY product_retail_price				DECIMAL(10,2) NOT NULL COMMENT 'Product retail price',
	MODIFY product_department				VARCHAR(10) COMMENT 'Product department',
	MODIFY product_sku						VARCHAR(40) NOT NULL COMMENT 'Product stock keeping unit',
	MODIFY product_distribution_center_id	INT UNSIGNED NOT NULL COMMENT 'Product distribution center id, foreign key';
-- 	ADD CONSTRAINT fk_inventory_items_dwd_product_distribution_center_id
-- 	FOREIGN KEY (product_distribution_center_id) REFERENCES thelook_ecommerce_dwd.distribution_centers_dwd(id)
-- 		ON DELETE RESTRICT
-- 		ON UPDATE CASCADE;


-- ===============================================================================
-- 6. order_items_ods table cleaning -> order_items_dwd
-- ===============================================================================
	
DROP TABLE IF EXISTS order_items_dwd;
CREATE TABLE IF NOT EXISTS order_items_dwd AS (
	SELECT 
	CAST(trim(id) AS UNSIGNED ) AS id,
	CAST(trim(order_id) AS UNSIGNED) AS order_id,
	CAST(trim(user_id) AS UNSIGNED) AS user_id,
	CAST(trim(product_id) AS UNSIGNED) AS product_id,
	CAST(trim(inventory_item_id) AS UNSIGNED) AS inventory_item_id,
	CASE 
		WHEN lower(trim(status)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(status)
	END AS status,
	CASE 
		WHEN trim(created_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(created_at),19),'%Y-%m-%d %H:%i:%s')
	END AS created_at_utc,
	CASE 
		WHEN trim(shipped_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(shipped_at),19),'%Y-%m-%d %H:%i:%s')
	END AS shipped_at_utc,		
	CASE 
		WHEN trim(delivered_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(delivered_at),19),'%Y-%m-%d %H:%i:%s')
	END AS delivered_at_utc,				
	CASE 
		WHEN trim(returned_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(returned_at),19),'%Y-%m-%d %H:%i:%s')
	END AS returned_at_utc,
	CAST(trim(sale_price) AS DECIMAL(10,2)) AS sale_price
	
	FROM thelook_ecommerce_ods.order_items_ods
	);

-- QA check : SELECT * FROM thelook_ecommerce_dwd.order_items_dwd LIMIT 100;

ALTER TABLE thelook_ecommerce_dwd.order_items_dwd
	MODIFY id 					INT UNSIGNED NOT NULL COMMENT 'Order items unique Identifier',
	ADD PRIMARY KEY (id),
	MODIFY order_id 			INT UNSIGNED NOT NULL COMMENT 'Related order id',
	MODIFY user_id 				INT UNSIGNED NOT NULL COMMENT 'Related user id',
	MODIFY product_id 			INT UNSIGNED NOT NULL COMMENT 'Related product id',
	MODIFY inventory_item_id 	INT UNSIGNED NOT NULL COMMENT 'Related inventory item id',	
-- 	ADD CONSTRAINT fk_order_items_dwd_order_id
-- 		FOREIGN KEY (order_id) REFERENCES thelook_ecommerce_dwd.orders_dwd(order_id)
-- 		ON DELETE RESTRICT
-- 		ON UPDATE CASCADE,
-- 	ADD CONSTRAINT fk_order_items_dwd_user_id
-- 		FOREIGN KEY (user_id) REFERENCES thelook_ecommerce_dwd.users_dwd(id)
-- 		ON DELETE RESTRICT
-- 		ON UPDATE CASCADE,
-- 	ADD CONSTRAINT fk_order_items_dwd_product_id
-- 		FOREIGN KEY (product_id) REFERENCES thelook_ecommerce_dwd.products_dwd(id)
-- 		ON DELETE RESTRICT 
-- 		ON UPDATE CASCADE,
-- 	ADD CONSTRAINT fk_order_items_dwd_inventory_item_id
-- 		FOREIGN KEY (inventory_item_id) REFERENCES thelook_ecommerce_dwd.inventory_items_dwd(id)
-- 		ON DELETE RESTRICT
-- 		ON UPDATE CASCADE,
	MODIFY status 				VARCHAR(20) COMMENT 'Each items status',
	MODIFY created_at_utc		DATETIME NOT NULL COMMENT 'The time when order item was created',
	MODIFY shipped_at_utc		DATETIME COMMENT 'The time when order item was shipped',
	MODIFY delivered_at_utc		DATETIME COMMENT 'The time when order item was delivered',	
	MODIFY returned_at_utc		DATETIME COMMENT 'The time when order item returned',
	MODIFY sale_price			DECIMAL(10,2) NOT NULL COMMENT 'The sale price of item';

-- QA check : DESC thelook_ecommerce_dwd.order_items_dwd;

-- ===============================================================================
-- 7.events_ods table cleaning -> events_dwd
-- ===============================================================================

DROP TABLE IF EXISTS events_dwd;
CREATE TABLE IF NOT EXISTS events_dwd AS (
	SELECT 
	CAST(trim(id) AS UNSIGNED) AS id,
	CASE
		WHEN trim(user_id) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE CAST(trim(user_id) AS UNSIGNED) 
	END AS user_id,
	CAST(trim(sequence_number) AS UNSIGNED) AS sequence_number,
	CASE
		WHEN trim(session_id) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(session_id)
	END AS session_id,
	CASE
		WHEN trim(created_at) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE STR_TO_DATE(LEFT(trim(created_at),19),'%Y-%m-%d %H:%i:%s')
	END AS created_at_utc,	
	CASE 
		WHEN trim(ip_address) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL 
		ELSE trim(ip_address)
	END AS ip_address,
	CASE 
		WHEN lower(trim(city)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(city)
	END AS city,
	CASE 
		WHEN lower(trim(state)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(state)
	END AS state,
	CASE 
		WHEN trim(postal_code) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(postal_code)
	END AS postal_code,
	CASE 
		WHEN lower(trim(browser)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(browser)
	END AS browser,	
	CASE 
		WHEN lower(trim(traffic_source)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(traffic_source)
	END AS traffic_source,
	CASE 
		WHEN lower(trim(uri)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(uri)
	END AS uri,
	CASE 
		WHEN lower(trim(event_type)) IN ('','null', 'none', 'n/a', 'na', 'nan',  '-') THEN NULL
		ELSE trim(event_type)
	END AS event_type
	
	FROM thelook_ecommerce_ods.events_ods
);

-- QA check : DESC thelook_ecommerce_dwd.events_dwd;

ALTER TABLE thelook_ecommerce_dwd.events_dwd
	MODIFY id 				INT UNSIGNED NOT NULL COMMENT 'Event unique identifier',
	ADD PRIMARY KEY (id),
	MODIFY user_id			INT UNSIGNED COMMENT 'Related user id (null is allowed)',
	MODIFY sequence_number	INT UNSIGNED NOT NULL COMMENT 'Sequence number in single session',
	MODIFY session_id		VARCHAR(45) NOT NULL COMMENT 'Session identifier',
	MODIFY created_at_utc 	DATETIME NOT NULL COMMENT 'When the event occurred',
	MODIFY ip_address		VARCHAR(15) COMMENT 'The ip address',
	MODIFY city				VARCHAR(50) COMMENT 'City derived from ip address',
	MODIFY state			VARCHAR(50) COMMENT 'State derived from ip address',
	MODIFY postal_code		VARCHAR(15) COMMENT 'Postal code derived from ip address',
	MODIFY browser			VARCHAR(10) COMMENT 'Browser that customer use',
	MODIFY traffic_source	VARCHAR(10) COMMENT 'Traffic source that customer came from',
	MODIFY uri				VARCHAR(100) COMMENT 'Uri that customer visited',
	MODIFY event_type		VARCHAR(20) COMMENT 'Event type';


