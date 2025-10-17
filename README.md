# amazon-sales-etl-vizualization
An ETL pipeline and Medallion Architecture project for analyzing Amazon sales data.

## 🐘 Postgres Database Setup

O repositório usa um script Python para popular o banco de dados com a tabela `silver.product`.

### 📋 Pré-requisitos

- Docker
- Docker Compose
- Python 3.8+

### 🚀 Como configurar e popular o banco

#### 1. Suba o banco de dados

```bash
docker compose up -d
```

Isso cria um container Postgres com os schemas `bronze`, `silver` e `gold`.

#### 2. Instale as dependências Python

```bash
# Criar ambiente virtual (opcional mas recomendado)
python3 -m venv .venv
source .venv/bin/activate  # No Windows: .venv\Scripts\activate

# Instalar dependências
pip install -r requirements.txt
```

#### 3. Execute o script de população

```bash
python populate_database.py
```

O script irá:
- ✅ Conectar ao banco de dados
- ✅ Criar a tabela `silver.product` com o DDL
- ✅ Carregar e processar o CSV da camada silver
- ✅ Inserir ~30.926 registros
- ✅ Exibir estatísticas e exemplos

#### 4. Estrutura da tabela `silver.product`

```sql
CREATE TABLE silver.product (
    id BIGINT PRIMARY KEY,
    rating DECIMAL(3,2),
    purchased_last_month INTEGER,
    discounted_price DECIMAL(10,2),
    is_best_seller BOOLEAN,
    total_reviews INTEGER,
    is_sponsored BOOLEAN,
    has_coupon BOOLEAN,
    buy_box_availability BOOLEAN,
    title TEXT,
    original_price DECIMAL(10,2),
    date DATE,
    time TIME,
    coupon_discount_pct DECIMAL(5,2)
);
```

### 🔗 Acesso ao Banco

**String de conexão:**
```
postgres://medallion:medallion@localhost:5432/amazon_sales
```

**Schemas disponíveis:**
- `bronze` - Camada de dados brutos
- `silver` - Camada de dados limpos (tabela `product`)
- `gold` - Camada de dados agregados (futuro)

### � Opção 2: Popular via Docker Compose (Automático SQL)

Este método carrega automaticamente as tabelas `bronze` e `silver` originais via SQL.

#### 1. Configure as variáveis de ambiente (opcional)

```bash
cp .env.example .env
```

Se você pular este passo, os valores padrão do `.env.example` serão aplicados automaticamente.

#### 2. Suba o banco de dados

```bash
docker compose up -d
```

Isso irá:
- Criar um container Postgres
- Criar os schemas `bronze` e `silver`
- Criar as tabelas com IDs auto-incrementados
- Carregar os dados do CSV para ambas as camadas

#### 3. Acesse o banco de dados

**String de conexão:**
```
postgres://medallion:medallion@localhost:5432/amazon_sales
```

**Tabelas disponíveis:**
- `bronze.amazon_products_sales_raw` - Dados brutos com ID (~42.675 linhas)
- `silver.amazon_products_sales_curated` - Dados limpos com ID (~30.926 linhas)
- `silver.product` - Tabela otimizada (se usar script Python)

#### 4. Valide a carga (opcional)

**Verificar camada bronze:**
```bash
docker compose exec postgres psql -U medallion -d amazon_sales -c "SELECT COUNT(*) FROM bronze.amazon_products_sales_raw;"
```

**Verificar camada silver:**
```bash
docker compose exec postgres psql -U medallion -d amazon_sales -c "SELECT COUNT(*) FROM silver.amazon_products_sales_curated;"
```

**Verificar tabela product:**
```bash
docker compose exec postgres psql -U medallion -d amazon_sales -c "SELECT COUNT(*) FROM silver.product;"
```

### 🔧 Comandos Úteis

**Verificar dados carregados:**
```bash
docker compose exec postgres psql -U medallion -d amazon_sales -c "SELECT COUNT(*) FROM silver.product;"
```

**Parar o banco:**
```bash
docker compose down
```

**Parar e remover volumes (limpar dados):**
```bash
docker compose down -v
```

**Recriar o banco do zero:**
```bash
docker compose down -v
docker compose up -d
python populate_database.py
```

**Acessar o psql interativo:**
```bash
docker compose exec postgres psql -U medallion -d amazon_sales
```

**Executar queries de teste:**
```bash
# Top 5 produtos mais bem avaliados
docker compose exec postgres psql -U medallion -d amazon_sales -c "
SELECT title, rating, total_reviews, discounted_price 
FROM silver.product 
WHERE rating IS NOT NULL 
ORDER BY rating DESC, total_reviews DESC 
LIMIT 5;"
```

### 📊 Variáveis de Ambiente

Você pode customizar a conexão do banco através de variáveis de ambiente:

```bash
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_DB=amazon_sales
export POSTGRES_USER=medallion
export POSTGRES_PASSWORD=medallion
```
