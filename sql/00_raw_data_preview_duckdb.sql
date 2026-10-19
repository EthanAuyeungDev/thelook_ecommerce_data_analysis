-- =========================================================
-- 1.users table 
-- =========================================================
DESCRIBE SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv';

SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv'
LIMIT 50;

SELECT
count(*) - count(first_name) AS first_name_null_count,
count(*) - count(last_name) AS last_name_null_count,
count(*) - count(email) AS email_null_count,
count(*) - count(age) AS age_null_count,
count(*) - count(gender) AS gender_null_count,
count(*) - count(state) AS state_null_count,
count(*) - count(street_address) AS street_address_null_count,
count(*) - count(postal_code) AS postal_code_null_count,
count(*) - count(city) AS city_null_count,
count(*) - count(country) AS country_null_count,
count(*) - count(latitude) AS latitude_null_count,
count(*) - count(longitude) AS longitude_null_count,
count(*) - count(traffic_source) AS traffic_source_null_count,
count(*) - count(created_at) AS lcreated_at_utc_null_count
FROM read_csv_auto('/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv')

SELECT 
count(*)
FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv'
WHERE lower(TRIM(city)) IN ('','null');

SELECT 
city, length(city) l1,
state, length(state) l2
FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv'
order by l1 desc, l2 desc


SELECT 
first_name,
last_name,
count(*) AS num
FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv'
GROUP BY first_name , last_name 
ORDER BY num DESC, first_name , last_name;

SELECT
    COUNT(*) AS cnt,
    COUNT(DISTINCT id) AS distinct_id
FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv';

SELECT *
FROM read_csv_auto('/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv',
					TYPES = {'created_at':'TIMESTAMPTZ'}
WHERE id IN ('1', '2', '3', '4', '5','6');


SELECT count(*)
FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv'


SELECT
    id,
    first_name,
    last_name,
    created_at
FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/users.csv'
WHERE id IN ('1', '100', '1000', '10000')
ORDER BY CAST(id AS INTEGER);

-- =========================================================
-- 2.orders table 
-- =========================================================
DESCRIBE SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/orders.csv';

WITH info AS (
	SELECT * 
	FROM read_csv_auto(
		'/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/orders.csv',
		TYPES = {
			'user_id':'INT',
			'status':'VARCHAR',
			'gender':'VARCHAR',
			'created_at':'TIMESTAMPTZ',
			'shipped_at':'TIMESTAMPTZ',
			'returned_at':'TIMESTAMPTZ',
			'delivered_at':'TIMESTAMPTZ',
			'num_of_item':'INT'
		}
	)
)
SELECT 
	'shipped_at < created_at',
	count(*)
FROM info
WHERE shipped_at < created_at
UNION ALL 
SELECT 
	'delivered_at < created_at',
	count(*)
FROM info
WHERE delivered_at < created_at
UNION ALL
SELECT 
	'delivered_at < shipped_at',
	count(*)
FROM info
WHERE delivered_at < created_at;


-- =========================================================
-- 3.products table 
-- =========================================================
DESCRIBE SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/products.csv';

SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/products.csv'
ORDER BY id 
LIMIT 1000;

SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/products.csv'
WHERE name = 'Kenneth Cole REACTION Men''s Passcase Wallet';

SELECT 
name,length(name) l1, brand, length(brand) l2 
FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/products.csv'
order by l2 DESC , l1 DESC ;


-- =========================================================
-- 4.orders_items table 
-- =========================================================
DESCRIBE SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/order_items.csv';
WITH info AS (
	SELECT * 
	FROM read_csv_auto(
	    '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/order_items.csv',
	    TYPES = {
	        'id'                 : 'INT',
	        'order_id'           : 'INT',
	        'user_id'            : 'INT',
	        'product_id'         : 'INT',
	        'inventory_item_id'  : 'INT',
	        'status'             : 'VARCHAR',
	        'created_at'         : 'TIMESTAMP WITH TIME ZONE',
	        'shipped_at'         : 'TIMESTAMP WITH TIME ZONE',
	        'delivered_at'       : 'TIMESTAMP WITH TIME ZONE',
	        'returned_at'        : 'TIMESTAMP WITH TIME ZONE',
	        'sale_price'         : 'DECIMAL(10,2)'
	    }
	)
)
SELECT 
*
--status,
--count(*)
FROM info
WHERE shipped_at < created_at


SELECT sale_price,
length(sale_price) as l1
FROM read_csv_auto('/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/order_items.csv',
					types = {'sale_price':'VARCHAR'})
order by l1 desc;


-- =========================================================
-- 5.distribution_centers table 
-- =========================================================
DESCRIBE SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/distribution_centers.csv';

SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/distribution_centers.csv'
LIMIT 100;

select length('Port Authority of New York/New Jersey NY/NJ')

-- =========================================================
-- 6.events table 
-- =========================================================
DESCRIBE SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/events.csv';

SELECT 
*
FROM read_csv_auto('/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/events.csv',
							TYPES = {'id':'INT','user_id':'INT','sequence_number':'INT',
									 'session_id':'VARCHAR','created_at':'TIMESTAMP',
									 'ip_address':'VARCHAR'})
LIMIT 1000 OFFSET 10000;

SELECT 
uri,length(uri) l1
FROM read_csv_auto('/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/events.csv',
							TYPES = {'id':'INT','user_id':'INT','sequence_number':'INT',
									 'session_id':'VARCHAR','created_at':'TIMESTAMP',
									 'ip_address':'VARCHAR'})
order by l1 desc

-- =========================================================
-- 7.inventory_items table 
-- =========================================================
DESCRIBE SELECT * FROM '/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/inventory_items.csv';
WITH inventory_info AS (							 
	SELECT * 
	FROM read_csv_auto(
	'/Users/ethanauyeung/DataAnalyst/thelook_ecommerce_analytics_codex/thelook_data/inventory_items.csv',
		types = {
			'id':									'INT',
			'product_id':							'INT',
			'created_at':							'TIMESTAMPTZ',
			'sold_at':								'TIMESTAMPTZ',
			'cost':									'DECIMAL(10,2)',
			'product_category':						'VARCHAR',
			'product_name':							'VARCHAR',
			'product_brand':						'VARCHAR',
			'product_retail_price':					'DECIMAL(10,2)',
			'product_department':					'VARCHAR',
			'product_sku':							'VARCHAR',
			'product_distribution_center_id':		'INT'
		}
	) 
)
SELECT  
*
FROM inventory_info
ORDER BY id
LIMIT 1000;

