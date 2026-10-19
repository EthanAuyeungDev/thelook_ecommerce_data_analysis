# TheLook Ecommerce Data Dictionary

This dictionary documents the seven source tables and the retained analytical warehouse tables. The project follows an ODS -> DWD -> DW (dimensions/facts) -> DWS -> ADS design. Source field descriptions use the original business meaning of each field.

**Source dataset:** [Google Cloud Marketplace — TheLook eCommerce dataset](https://console.cloud.google.com/marketplace/product/bigquery-public-data/thelook-ecommerce?hl=en&project=causal-flame-283208).

**Scope note:** `events` and `inventory_items` are retained in ODS table creation/loading and DWD cleaning for source completeness. They are excluded from the analytical DW model and all DWS, ADS, and downstream business analysis. The analytical fact tables are `fct_order_items` and `fct_orders`.

## 1. users

Grain: one row per registered user.

| Column | Recommended Type | Key | Description | Example |
| --- | --- | --- | --- | --- |
| id | INT | PK | Unique user identifier. | 77660 |
| first_name | VARCHAR(30) |  | User first name. | Angel |
| last_name | VARCHAR(30) |  | User last name. | Hart |
| email | VARCHAR(100) |  | User email address. | angelhart@example.net |
| age | INT |  | User age. | 57 |
| gender | VARCHAR(10) |  | User gender in the raw file: M or F. DWD maps this to Male/Female. | M |
| state | VARCHAR(150) |  | State, province, or region. | Acre |
| street_address | VARCHAR(150) |  | Street address. | 400 Stephanie Locks |
| postal_code | VARCHAR(20) |  | Postal or ZIP code. | 69980-000 |
| city | VARCHAR(100) |  | City name. Raw data may contain string values such as null. | null |
| country | VARCHAR(50) |  | Country name. | Brasil |
| latitude | DECIMAL(10,7) |  | User latitude. | -8.0653461 |
| longitude | DECIMAL(10,7) |  | User longitude. | -72.8709487 |
| traffic_source | VARCHAR(20) |  | Acquisition source assigned to the user. | Search |
| created_at | TIMESTAMP |  | User registration timestamp in the raw file. | 2025-03-16 15:43:00+00:00 |
| user_geom | VARCHAR(100) |  | Geographic point string from the source file. | POINT(-72.87094866 -8.065346116) |

Common analysis use cases: acquisition trends, customer demographics, geographic analysis, channel quality, LTV, RFM segmentation, cohort assignment.

## 2. orders

Grain: one row per order.

| Column | Recommended Type | Key | Description | Example |
| --- | --- | --- | --- | --- |
| order_id | INT | PK | Unique order identifier. | 32 |
| user_id | INT | FK | User who placed the order. References users.id. | 23 |
| status | VARCHAR(20) |  | Order-level status. Expected values include Cancelled, Processing, Shipped, Complete, Returned. | Cancelled |
| gender | VARCHAR(10) |  | Customer gender copied to the order record at order time. | F |
| created_at | TIMESTAMP |  | Order creation timestamp. | 2025-06-27 03:09:50+00:00 |
| returned_at | TIMESTAMP |  | Return timestamp, populated for returned orders. | NULL |
| shipped_at | TIMESTAMP |  | Shipment timestamp, populated for shipped/completed/returned orders. | NULL |
| delivered_at | TIMESTAMP |  | Delivery timestamp, populated for completed/returned orders. | NULL |
| num_of_item | INT |  | Number of items in the order. | 2 |

Common analysis use cases: order status mix, cancellation rate, fulfillment status validation, order volume trend, AOV.

## 3. products

Grain: one row per product/SKU.

| Column | Recommended Type | Key | Description | Example |
| --- | --- | --- | --- | --- |
| id | INT | PK | Unique product identifier. | 13842 |
| cost | DECIMAL(10,2) |  | Product cost. | 2.52 |
| category | VARCHAR(45) |  | Product category. | Accessories |
| name | VARCHAR(300) |  | Product display name. | Low Profile Dyed Cotton Twill Cap - Navy W39S55D |
| brand | VARCHAR(80) |  | Brand name. | MG |
| retail_price | DECIMAL(10,2) |  | Listed retail price. | 6.25 |
| department | VARCHAR(10) |  | Department, usually Men or Women. | Women |
| sku | VARCHAR(50) |  | Stock keeping unit hash. | EBD58B8A3F1D72F4206201DA62FB1204 |
| distribution_center_id | INT | FK | Distribution center responsible for the product. References distribution_centers.id. | 1 |

Common analysis use cases: product performance, category contribution, pricing tiers, margin analysis, brand ranking, distribution center performance.

## 4. order_items

Grain: one row per purchased order item.

| Column | Recommended Type | Key | Description | Example |
| --- | --- | --- | --- | --- |
| id | INT | PK | Unique order item identifier. | 33556 |
| order_id | INT | FK | Parent order identifier. References orders.order_id. | 23152 |
| user_id | INT | FK | User who purchased the item. References users.id. | 18574 |
| product_id | INT | FK | Product purchased. References products.id. | 14235 |
| inventory_item_id | INT | FK | Inventory item used to fulfill the order item. References inventory_items.id. | 90801 |
| status | VARCHAR(20) |  | Item-level status. | Complete |
| created_at | TIMESTAMP |  | Order item creation timestamp. | 2025-06-07 06:26:08+00:00 |
| shipped_at | TIMESTAMP |  | Item shipment timestamp. | 2025-06-07 12:45:58+00:00 |
| delivered_at | TIMESTAMP |  | Item delivery timestamp. | 2025-06-12 02:38:58+00:00 |
| returned_at | TIMESTAMP |  | Item return timestamp. | NULL |
| sale_price | DECIMAL(10,2) |  | Actual item sale price paid by the customer. | 0.02 |

Common analysis use cases: revenue, gross profit, margin, return rate, product ranking, cohort activity, RFM, LTV, delivery performance.

## 5. distribution_centers

Grain: one row per distribution center.

| Column | Recommended Type | Key | Description | Example |
| --- | --- | --- | --- | --- |
| id | INT | PK | Unique distribution center identifier. | 8 |
| name | VARCHAR(50) |  | Distribution center name and location. | Mobile AL |
| latitude | DECIMAL(10,7) |  | Distribution center latitude. | 30.6944 |
| longitude | DECIMAL(10,7) |  | Distribution center longitude. | -88.0431 |
| distribution_center_geom | VARCHAR(100) |  | Geographic point string from the source file. | POINT(-88.0431 30.6944) |

Common analysis use cases: fulfillment performance, inventory distribution, delivery speed, regional supply chain comparison.

## 6. events

Grain: one row per website event.

| Column | Recommended Type | Key | Description | Example |
| --- | --- | --- | --- | --- |
| id | INT | PK | Unique event identifier. | 1341527 |
| user_id | INT | FK nullable | User who triggered the event. NULL indicates anonymous or unauthenticated traffic. | NULL |
| sequence_number | INT |  | Event sequence number within a session. | 3 |
| session_id | VARCHAR(45) |  | Session identifier shared by events in the same visit. | 5cb0db7a-8a95-4733-9bad-e29a4f960c11 |
| created_at | TIMESTAMP |  | Event timestamp. | 2020-12-26 14:14:00+00:00 |
| ip_address | VARCHAR(45) |  | IP address. | 9.147.67.37 |
| city | VARCHAR(50) |  | City derived from IP/location data. | Sao Paulo |
| state | VARCHAR(50) |  | State or region derived from IP/location data. | Sao Paulo |
| postal_code | VARCHAR(20) |  | Postal code derived from IP/location data. | 02675-031 |
| browser | VARCHAR(20) |  | Browser used in the session. | Chrome |
| traffic_source | VARCHAR(20) |  | Session traffic source. | Organic |
| uri | VARCHAR(150) |  | Page path or resource path. | /cancel |
| event_type | VARCHAR(20) |  | Event type, such as home, department, product, cart, purchase, cancel. | cancel |

Project handling: retain the source table in ODS and its cleaned DWD table. No downstream event fact, event-specific analytical dimension, DWS/ADS summary, or event-based analysis is built in this project scope.

## 7. inventory_items

Grain: one row per physical inventory item.

| Column | Recommended Type | Key | Description | Example |
| --- | --- | --- | --- | --- |
| id | INT | PK | Unique inventory item identifier. | 75175 |
| product_id | INT | FK | Product represented by the inventory item. References products.id. | 13844 |
| created_at | TIMESTAMP |  | Timestamp when the item entered inventory. | 2025-12-04 05:05:33+00:00 |
| sold_at | TIMESTAMP |  | Timestamp when the item was sold. NULL means unsold. | 2025-12-31 10:19:33+00:00 |
| cost | DECIMAL(10,2) |  | Cost of the physical item. | 2.77 |
| product_category | VARCHAR(45) |  | Product category snapshot. | Accessories |
| product_name | VARCHAR(300) |  | Product name snapshot. | (ONE) 1 Satin Headband |
| product_brand | VARCHAR(80) |  | Product brand snapshot. | Funny Girl Designs |
| product_retail_price | DECIMAL(10,2) |  | Product retail price snapshot. | 6.99 |
| product_department | VARCHAR(10) |  | Product department snapshot. | Women |
| product_sku | VARCHAR(50) |  | Product SKU snapshot. | 2A3E953A5E3D81E67945BCE5519F84C8 |
| product_distribution_center_id | INT | FK | Distribution center storing the item. | 7 |

Project handling: retain the source table in ODS and its cleaned DWD table. No inventory fact, DWS/ADS summary, or downstream inventory analysis is built in this project scope.

## Derived Warehouse Tables

The following are analytical tables built by the SQL scripts currently present in this repository. `dim_traffic_sources` uses customer acquisition source values; it is not populated from events.

| Table | Layer | Grain | Description |
| --- | --- | --- | --- |
| `dim_customers` | DW | One row per customer | Customer demographics, acquisition source, registration date, and first-order attributes. |
| `dim_products` | DW | One row per product | Product catalog, price, cost, margin attributes, and distribution center. |
| `dim_date` | DW | One row per calendar date | Calendar attributes for time-series analysis. |
| `dim_distribution_centers` | DW | One row per distribution center | Distribution center name and geographic attributes. |
| `dim_order_status` | DW | One row per status value | Standardized order status groups and flags. |
| `dim_traffic_sources` | DW | One row per customer acquisition source | Source labels and groupings derived from customer data. |
| `fct_order_items` | DW | One row per order item | Sales, gross profit, status, return/cancel flags, and fulfillment measures. |
| `fct_orders` | DW | One row per order | Order-level amounts, item count, status, and fulfillment measures. |
| `dws_daily_sales` | DWS | Date + category + department | Daily order, item, sales, margin, return, and cancellation summary. |
| `dws_monthly_sales` | DWS | One row per month | Monthly sales, order, customer, profit, and margin summary. |
| `dws_user_order_summary` | DWS | One row per customer | Customer order, revenue, profit, recency, return, and cancellation measures. |
| `dws_product_sales` | DWS | One row per product | Product sales, margin, return, and cancellation summary. |
| `dws_channel_performance` | DWS | Acquisition source + order date | Customer-source order and revenue performance. |
| `ads_sales_dashboard` | ADS | One row per month | Revenue, order, AOV, and month-over-month metrics. |
| `ads_rfm_segments` | ADS | One row per purchasing customer | RFM scores and customer segment labels. |
| `ads_retention_matrix` | ADS | Cohort month + month offset | Customer retention matrix. |
| `ads_product_dashboard` | ADS | One row per product | Product performance dashboard measures. |

