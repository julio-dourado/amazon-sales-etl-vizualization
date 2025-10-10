# amazon-sales-etl-vizualization
An ETL pipeline and Medallion Architecture project for analyzing Amazon sales data.

## 🐘 Postgres silver layer

The repository ships with a Docker Compose definition that spins up a Postgres instance and loads the curated "silver" dataset automatically. The import runs once, on the first start, using the CSV located in `data-lake/silver/data/amazon_products_cleaned.csv` (the file is mounted read-only into the container).

### 1. Configure environment variables (optional)

```
cp .env.example .env
# adjust POSTGRES_* values if needed
```

If you skip this step the defaults from `.env.example` are applied automatically.

### 2. Start the database

```
docker compose up -d
```

- Access: `postgres://medallion:medallion@localhost:5432/amazon_sales` (or whatever you configured).
- The curated table lives at `silver.amazon_products_sales_curated`.

### 3. Validate the load (optional)

```
docker compose exec postgres psql -U ${POSTGRES_USER:-medallion} -d ${POSTGRES_DB:-amazon_sales} -c "SELECT COUNT(*) FROM silver.amazon_products_sales_curated;"
```

The expected count is 42,676 rows.
