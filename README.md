# amazon-sales-etl-vizualization
An ETL pipeline and Medallion Architecture project for analyzing Amazon sales data.

## 🐘 Postgres Database (Bronze & Silver Layers)

O repositório inclui uma configuração Docker Compose que sobe automaticamente uma instância Postgres e carrega ambas as camadas **bronze** (dados brutos) e **silver** (dados limpos). A importação ocorre automaticamente na primeira execução.

### 📋 Pré-requisitos

- Docker
- Docker Compose

### 🚀 Como subir o banco de dados

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
- `bronze.amazon_products_sales_raw` - Dados brutos com ID
- `silver.amazon_products_sales_curated` - Dados limpos com ID

#### 4. Valide a carga (opcional)

**Verificar camada bronze:**
```bash
docker compose exec postgres psql -U medallion -d amazon_sales -c "SELECT COUNT(*) FROM bronze.amazon_products_sales_raw;"
```

**Verificar camada silver:**
```bash
docker compose exec postgres psql -U medallion -d amazon_sales -c "SELECT COUNT(*) FROM silver.amazon_products_sales_curated;"
```

**Contagem esperada:** 42,676 linhas em cada tabela.

#### 5. Comandos úteis

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
```

**Acessar o psql interativo:**
```bash
docker compose exec postgres psql -U medallion -d amazon_sales
```
