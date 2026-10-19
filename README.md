# TheLook E-commerce Analytics

### End-to-End Analytics Portfolio — SQL · Python · MySQL

> This project is an independent implementation inspired by the structure of [the reference TheLook analytics README](https://github.com/parthbadiger24-creator/thelook-ecommerce-analytics/tree/main). All descriptions below reflect the files and scope in this repository.

## Project Overview

TheLook is a fictional e-commerce clothing business. This repository prepares its public dataset in a layered MySQL warehouse and uses SQL and notebooks to analyze sales, customers, products, channels, geography, and fulfillment. The `events` and `inventory_items` sources are retained in source ingestion and DWD cleaning, but excluded from the analytical model and downstream analysis.

**Data source:** [Google Cloud Marketplace — TheLook eCommerce dataset](https://console.cloud.google.com/marketplace/product/bigquery-public-data/thelook-ecommerce?hl=en&project=causal-flame-283208), published as a BigQuery public dataset.

**ER Diagram:**
![alt text](source_table_relationships.drawio.png)
| Area | What this project contains |
| --- | --- |
| Data preparation | ODS source tables and typed/cleaned DWD tables |
| Data warehouse | MySQL dimensions and order-item and order fact tables |
| Summary layers | DWS sales, customer, product, and channel summaries; ADS sales, RFM, retention, and product outputs |
| SQL analytics | Analysis of revenue, lifecycle, products, RFM, retention, fulfillment, channels, geography, and order grain |


## Data Pipeline

```text
Source CSVs → ODS raw tables → DWD cleaned tables → DW dimensions and facts
            → DWS subject summaries → ADS reporting tables → SQL analysis / notebooks
```

`events` and `inventory_items` remain part of raw table creation/loading and DWD cleaning. Neither source has a fact table, DWS/ADS output, or downstream business analysis in the current project scope.

### Reproduction Workflow

1. Place the source CSV files in `thelook_data/` (the events CSV is retained for ingestion and cleaning).
2. Review `notebooks/01_data_profiling.ipynb` and the profiling report in `docs/`.
3. Configure local file paths and MySQL connection settings for your environment.
4. Run `sql/01_schema_creation.sql` to create source databases/tables and load CSV files.
5. Run `sql/02_thelook_data_cleaning.sql` to build cleaned DWD tables.
6. Run `sql/03_create_dim_facts.sql` to build dimensions and the order-item and order facts.
7. Run `sql/04_create_dws.sql`, then `sql/05_create_ads.sql` to build summary and application layers.
8. Run the available SQL analysis scripts in `sql/` by subject area.
9. Run the notebooks as appropriate for profiling, EDA, and visual analysis.

**Environment-specific settings:** update the local `LOAD DATA LOCAL INFILE` paths in the SQL scripts and configure MySQL locally. Do not commit credentials.

## Repository Structure

```text
.
├── sql/                            # Ingestion, cleaning, modeling, summaries, analyses
├── thelook_data/                   # Local source CSV files
├── facts_dimension.md              # Fact and dimension grains and relationships
├── thelook_ecommerce_dictionary.md # Source and derived table dictionary
└── README.md
```

## SQL Guide

| File | Purpose |
| --- | --- |
| `00_raw_data_preview_duckdb.sql` | Inspect source CSV schemas and sample records with DuckDB |
| `01_schema_creation.sql` | Create ODS/DWD databases and ODS source tables; load CSVs, including events |
| `02_thelook_data_cleaning.sql` | Clean and type-cast source tables into DWD, including events |
| `03_create_dim_facts.sql` | Build analytical dimensions and the order-item and order facts |
| `04_create_dws.sql` | Build daily/monthly sales, customer, product, and channel summaries |
| `05_create_ads.sql` | Build sales, RFM, retention, and product reporting tables |
| `06_revenue_analysis.sql` | Revenue, order value, growth, and sales mix |
| `07_customer_lifecycle_analysis.sql` | Customer acquisition, lifecycle, repeat purchase, and value |
| `08_product_analysis.sql` | Product, category, brand, price, and performance analysis |
| `09_rfm_analysis.sql` | RFM scoring and customer segment interpretation |
| `10_retention_cohort_analysis.sql` | Cohort retention and repeat-purchase analysis |
| `11_fulfillment_delivery_analysis.sql` | Order-item and order-level shipping, delivery, and return timing |
| `12_channel_analysis.sql` | Customer acquisition-source performance |
| `13_geo_analysis.sql` | Country, state, city, and geographic sales/return analysis |
| `14_order_fact_analysis.sql` | Order-grain status, revenue, fulfillment, and item-grain comparison |

## Data Model

The analytical DW has two fact tables at distinct grains. The primary star centers on `fct_order_items`; `fct_orders` supports order-grain reporting and validation.

```text
                         ┌──────────────────────┐
                         │    dim_customers     │
                         │──────────────────────│
                         │ customer_key (PK)    │
                         │ customer_id          │
                         │ age_group / gender   │
                         │ country / city       │
                         │ traffic_source       │
                         └──────────┬───────────┘
                                    │ 1 : many
                                    │
┌──────────────────────┐      ┌────▼─────────────────┐      ┌──────────────────────┐
│     dim_products     │      │    fct_order_items   │      │       dim_date       │
│──────────────────────│      │──────────────────────│      │──────────────────────│
│ product_key (PK)     │◄─────│ product_key (FK)     │─────►│ date_key (PK)        │
│ product_id           │ 1:m  │ customer_key (FK)    │ m:1  │ year / quarter       │
│ name / brand         │      │ order_date_key (FK)  │      │ month / day          │
│ category / department│      │ order_status_key (FK)│      └──────────────────────┘
│ cost / retail_price  │      │ order_id             │
└──────────────────────┘      │ sale_price           │      ┌──────────────────────┐
                              │ gross_profit         │─────►│   dim_order_status   │
                              │ ship_days            │ m:1  │──────────────────────│
                              │ delivery_days        │      │ order_status_key (PK)│
                              │ is_returned          │      │ order_status         │
                              └──────────────────────┘      └──────────────────────┘

                         ┌──────────────────────┐
                         │    dim_customers     │
                         └──────────┬───────────┘
                                    │ 1 : many
                                    │
                         ┌──────────▼───────────┐      ┌──────────────────────┐
                         │      fct_orders      │─────►│       dim_date       │
                         │──────────────────────│ m:1  │──────────────────────│
                         │ order_key (PK)       │      │ date_key (PK)        │
                         │ order_id             │      │ year / quarter       │
                         │ customer_key (FK)    │      │ month / day          │
                         │ order_date_key (FK)  │      └──────────────────────┘
                         │ order_status_key (FK)│
                         │ order_gross_amount   │      ┌──────────────────────┐
                         │ order_net_amount     │─────►│   dim_order_status   │
                         └──────────────────────┘ m:1  │──────────────────────│
                                                       │ order_status_key (PK)│
                                                       │ order_status         │
                                                       └──────────────────────┘
```

| Fact | Grain | Main use |
| --- | --- | --- |
| `fct_order_items` | One row per order item | Sales, product performance, returns, and fulfillment |
| `fct_orders` | One row per order | Order counts, order status, order value, fulfillment |

See [facts_dimension.md](facts_dimension.md) for dimension detail and [the data dictionary](thelook_ecommerce_dictionary.md) for source fields and derived tables.

## Metric Definitions and Caveats

- **Gross sales / GMV:** define the treatment of cancelled and returned items for each reported metric; analysis scripts may use different grains.
- **Net sales:** non-cancelled and non-returned item sales where the relevant query applies both exclusions.
- **Order metrics:** count each `order_id` once. **Item metrics:** count each order-item row once. Always state the denominator for return and cancellation rates.
- **Timestamp quality:** source data can contain inverted shipment and creation timestamps. Review quality flags and interpret duration metrics with care.
- **Events and inventory scope:** both sources are loaded and cleaned for source completeness, but are not included in DW facts, DWS/ADS analytics, or business analysis.
- **Customer acquisition source:** the customer dimension's source describes recorded customer acquisition; it is not session-level event attribution.

## Technologies

| Area | Technology |
| --- | --- |
| Source | Google BigQuery public TheLook dataset / local CSV exports |
| Warehouse | MySQL 8.0+ |
| Raw-data preview | DuckDB |

## Documentation

- [Data dictionary](thelook_ecommerce_dictionary.md)
- [Fact and dimension model](facts_dimension.md)

## Author and License

Author: https://github.com/EthanAuyeungDev

This project is open source and available under the MIT License.
