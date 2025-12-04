# Amazon Sales ETL

Pipeline ETL com Arquitetura Medallion para análise de dados da Amazon.

## Requisitos

- Docker e Docker Compose
- Python 3.8+

## Como rodar

### Subir o banco

```bash
docker compose up -d
```

### Instalar dependências

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Rodar os notebooks na ordem

1. `Data Layer/Transformer/etl_raw_to_silver.ipynb` - Carrega dados na tabela silver.product
2. `Data Layer/Transformer/etl_silver_to_gold.ipynb` - Cria o star schema na camada gold
3. `Data Layer/silver/analytics.ipynb` - Análises dos dados silver

## Banco de dados

Conexão: `postgresql://postgres:postgres@localhost:5432/amazon_sales`

Schemas:
- `silver.product` - 15.938 produtos processados
- `gold.*` - Tabelas dimensionais e fato (dim_prdt, dim_tmp, dim_cat, ft_vnd)

## Comandos úteis

Ver dados no banco:
```bash
docker compose exec postgres psql -U postgres -d amazon_sales -c "SELECT COUNT(*) FROM silver.product;"
```

Resetar tudo:
```bash
docker compose down -v
docker compose up -d
```

Acessar psql:
```bash
docker compose exec postgres psql -U postgres -d amazon_sales
```
