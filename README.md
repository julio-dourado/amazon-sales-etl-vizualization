# Amazon Sales ETL

ETL pipeline with Medallion Architecture for Amazon data analysis.

## Authors

- Julio Cesar Almeida Dourado ([julio-dourado](https://github.com/julio-dourado))
- Leonardo Lago Moreno ([julio-dourado](https://github.com/lelamo2002))
- Gustavo Henrique Rodrigues de Sousa ([GustavoHenriqueRS](https://github.com/GustavoHenriqueRS))

## Dataset

[Amazon Products Sales Dataset (42k items) - 2025](https://www.kaggle.com/datasets/ikramshah512/amazon-products-sales-dataset-42k-items-2025/data)

## Dashboard

![Landing Page](Data%20Visualization/img/1.png)
![Market Pulse](Data%20Visualization/img/2.png)
![Pricing Strategy](Data%20Visualization/img/3.png)
![Opportunity Radar](Data%20Visualization/img/4.png)

## Requirements

- Docker and Docker Compose
- Python 3.8+

## How to run

### Start the database

```bash
docker compose up -d
```

### Install dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Run notebooks in order

1. `Data Layer/Transformer/etl_raw_to_silver.ipynb` - Loads data into silver.product table
2. `Data Layer/Transformer/etl_silver_to_gold.ipynb` - Creates star schema in gold layer
3. `Data Layer/silver/analytics.ipynb` - Silver data analysis

## Database

Connection: `postgresql://postgres:postgres@localhost:5432/amazon_sales`

Schemas:
- `silver.product` - 15,938 processed products
- `gold.*` - Dimensional and fact tables (dim_prdt, dim_tmp, dim_cat, ft_vnd)

## Useful commands

View data in database:
```bash
docker compose exec postgres psql -U postgres -d amazon_sales -c "SELECT COUNT(*) FROM silver.product;"
```

Reset everything:
```bash
docker compose down -v
docker compose up -d
```

Access psql:
```bash
docker compose exec postgres psql -U postgres -d amazon_sales
```
