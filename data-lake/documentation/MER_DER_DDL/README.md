# Amazon Products Sales - Modelagem Star Schema

## 📊 Visão Geral

Este documento apresenta a modelagem dimensional (Star Schema) para o Data Warehouse de vendas de produtos da Amazon, implementando a camada **Gold** da arquitetura Medallion.

## 🏗️ Arquitetura do Star Schema

### Estrutura

```
                    ┌─────────────────┐
                    │   dim_tempo     │
                    ├─────────────────┤
                    │ tempo_id (PK)   │
                    │ data_completa   │
                    │ dia, mes, ano   │
                    │ dia_semana      │
                    │ trimestre       │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────┴────────┐  ┌────────┴────────┐  ┌───────┴────────┐
│  dim_produto   │  │ FATO_PRODUTO_   │  │  dim_preco     │
├────────────────┤  │     VENDA       │  ├────────────────┤
│ produto_id(PK) │◄─┤─────────────────┤─►│ preco_id (PK)  │
│ title          │  │ fato_id (PK)    │  │ discounted_    │
│ is_best_seller │  │ produto_id (FK) │  │   price        │
│ is_sponsored   │  │ preco_id (FK)   │  │ original_price │
└────────────────┘  │ avaliacao_id(FK)│  │ discount_%     │
                    │ promocional_id  │  │ faixa_preco    │
                    │ tempo_id (FK)   │  └────────────────┘
                    │                 │
                    │ MÉTRICAS:       │
                    │ - purchased_    │
                    │   last_month    │
                    │ - receita_      │
                    │   estimada      │
                    │ - receita_      │
                    │   potencial     │
                    │ - economia_     │
                    │   total         │
                    └─────┬─────┬─────┘
                          │     │
              ┌───────────┘     └───────────┐
              │                             │
      ┌───────┴─────────┐         ┌─────────┴────────┐
      │ dim_avaliacao   │         │ dim_promocional  │
      ├─────────────────┤         ├──────────────────┤
      │ avaliacao_id(PK)│         │ promocional_id   │
      │ rating          │         │   (PK)           │
      │ rating_categoria│         │ has_coupon       │
      │ total_reviews   │         │ coupon_discount_ │
      │ faixa_reviews   │         │   pct            │
      └─────────────────┘         │ buy_box_         │
                                  │   availability   │
                                  └──────────────────┘
```

## 📋 Dimensões

### 1. dim_produto
**Granularidade:** Um registro por produto único

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| produto_id | SERIAL (PK) | Identificador único do produto |
| title | VARCHAR(500) | Nome completo do produto |
| is_best_seller | BOOLEAN | Indica se é best-seller |
| is_sponsored | BOOLEAN | Indica se é patrocinado |
| created_at | TIMESTAMP | Data de criação |
| updated_at | TIMESTAMP | Data de atualização |

**Índices:**
- `idx_dim_produto_title`: Busca por nome
- `idx_dim_produto_best_seller`: Filtro de best-sellers

---

### 2. dim_preco
**Granularidade:** Um registro por combinação única de preços

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| preco_id | SERIAL (PK) | Identificador único |
| discounted_price | DECIMAL(10,2) | Preço com desconto |
| original_price | DECIMAL(10,2) | Preço original |
| discount_percentage | DECIMAL(5,2) | Percentual de desconto |
| faixa_preco | VARCHAR(50) | Classificação: 'Até $50', '$50-$200', etc. |
| has_discount | BOOLEAN | Indica se tem desconto |

**Faixas de Preço:**
- Até $50
- $50-$200
- $200-$500
- Acima de $500

---

### 3. dim_avaliacao
**Granularidade:** Um registro por combinação única de rating e reviews

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| avaliacao_id | SERIAL (PK) | Identificador único |
| rating | DECIMAL(2,1) | Nota média (0.0 - 5.0) |
| rating_categoria | VARCHAR(20) | Classificação qualitativa |
| total_reviews | INTEGER | Número total de avaliações |
| faixa_reviews | VARCHAR(50) | Classificação por quantidade |

**Categorias de Rating:**
- Excelente: ≥ 4.5
- Bom: 3.5 - 4.4
- Regular: 2.5 - 3.4
- Ruim: < 2.5

**Faixas de Reviews:**
- Sem Reviews
- 1-100
- 100-1000
- 1000-10000
- Acima de 10000

---

### 4. dim_promocional
**Granularidade:** Um registro por combinação única de atributos promocionais

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| promocional_id | SERIAL (PK) | Identificador único |
| has_coupon | BOOLEAN | Possui cupom de desconto |
| coupon_discount_pct | DECIMAL(5,2) | Percentual do cupom |
| buy_box_availability | BOOLEAN | Disponível no carrinho |

---

### 5. dim_tempo
**Granularidade:** Um registro por dia

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| tempo_id | SERIAL (PK) | Identificador único |
| data_completa | DATE | Data completa (YYYY-MM-DD) |
| dia | INTEGER | Dia do mês (1-31) |
| mes | INTEGER | Mês (1-12) |
| ano | INTEGER | Ano (YYYY) |
| dia_semana | INTEGER | Dia da semana (1-7) |
| nome_dia_semana | VARCHAR(20) | Nome do dia |
| nome_mes | VARCHAR(20) | Nome do mês |
| trimestre | INTEGER | Trimestre (1-4) |
| semestre | INTEGER | Semestre (1-2) |
| is_final_semana | BOOLEAN | É fim de semana |

**Hierarquia Temporal:**
```
Ano → Semestre → Trimestre → Mês → Semana → Dia
```

---

## 🎯 Tabela Fato

### fato_produto_venda
**Granularidade:** Um registro por produto por dia de coleta

#### Chaves Estrangeiras
| Coluna | Referência | Descrição |
|--------|------------|-----------|
| produto_id | dim_produto | Relacionamento com produto |
| preco_id | dim_preco | Relacionamento com preço |
| avaliacao_id | dim_avaliacao | Relacionamento com avaliação |
| promocional_id | dim_promocional | Relacionamento com promoção |
| tempo_id | dim_tempo | Relacionamento com data |

#### Métricas (Fatos)
| Coluna | Tipo | Descrição | Fórmula |
|--------|------|-----------|---------|
| purchased_last_month | INTEGER | Quantidade vendida no mês | - |
| receita_estimada | DECIMAL(15,2) | Receita com preço com desconto | purchased × discounted_price |
| receita_potencial | DECIMAL(15,2) | Receita sem desconto | purchased × original_price |
| economia_total | DECIMAL(15,2) | Economia gerada por descontos | receita_potencial - receita_estimada |

#### Metadados
| Coluna | Tipo | Descrição |
|--------|------|-----------|
| collected_at | TIMESTAMP | Data/hora da coleta |
| created_at | TIMESTAMP | Data de inserção no DW |

---

## 📊 Views Analíticas

### 1. vw_vendas_por_faixa_preco
Análise agregada de vendas por faixa de preço

**Métricas:**
- Total de produtos
- Total de vendas
- Receita total e média
- Rating médio

### 2. vw_top_produtos_receita
Top 100 produtos com maior receita

**Métricas:**
- Total de vendas
- Receita total
- Rating médio
- Desconto médio aplicado

### 3. vw_efetividade_promocoes
Análise de impacto das estratégias promocionais

**Segmentação:**
- Com/sem cupom
- Com/sem disponibilidade no carrinho

**Métricas:**
- Total de produtos
- Média de vendas
- Receita gerada
- Rating médio

### 4. vw_tendencias_temporais
Evolução de métricas ao longo do tempo

**Granularidade:** Mensal

**Métricas:**
- Total de produtos ativos
- Total de vendas
- Receita acumulada
- Rating médio do período

---

## 🔧 Funções Auxiliares

### classificar_faixa_preco(preco)
Classifica produtos em faixas de preço
```sql
SELECT classificar_faixa_preco(99.99); -- Retorna: '$50-$200'
```

### classificar_rating(rating)
Classifica avaliações qualitativamente
```sql
SELECT classificar_rating(4.7); -- Retorna: 'Excelente'
```

### classificar_faixa_reviews(reviews)
Classifica produtos por quantidade de reviews
```sql
SELECT classificar_faixa_reviews(5432); -- Retorna: '1000-10000'
```

---

## 📈 Queries de Exemplo

### 1. Produtos mais vendidos por faixa de preço
```sql
SELECT 
    dp.faixa_preco,
    dprod.title,
    SUM(f.purchased_last_month) as total_vendas,
    SUM(f.receita_estimada) as receita
FROM fato_produto_venda f
JOIN dim_preco dp ON f.preco_id = dp.preco_id
JOIN dim_produto dprod ON f.produto_id = dprod.produto_id
GROUP BY dp.faixa_preco, dprod.title
ORDER BY dp.faixa_preco, total_vendas DESC;
```

### 2. Efetividade de cupons
```sql
SELECT 
    dpm.has_coupon,
    COUNT(*) as total_produtos,
    AVG(f.purchased_last_month) as media_vendas,
    AVG(da.rating) as rating_medio
FROM fato_produto_venda f
JOIN dim_promocional dpm ON f.promocional_id = dpm.promocional_id
JOIN dim_avaliacao da ON f.avaliacao_id = da.avaliacao_id
GROUP BY dpm.has_coupon;
```

### 3. Tendência de vendas por mês
```sql
SELECT 
    dt.ano,
    dt.mes,
    dt.nome_mes,
    SUM(f.purchased_last_month) as total_vendas,
    SUM(f.receita_estimada) as receita_total
FROM fato_produto_venda f
JOIN dim_tempo dt ON f.tempo_id = dt.tempo_id
GROUP BY dt.ano, dt.mes, dt.nome_mes
ORDER BY dt.ano, dt.mes;
```

---

## 🎯 Casos de Uso

### 1. Análise de Precificação
- Comparar vendas entre diferentes faixas de preço
- Avaliar impacto de descontos na receita
- Identificar sweet spot de precificação

### 2. Estratégia Promocional
- Medir efetividade de cupons
- Avaliar produtos com melhor ROI promocional
- Otimizar investimento em promoções

### 3. Gestão de Catálogo
- Identificar produtos de baixo desempenho
- Avaliar correlação entre rating e vendas
- Priorizar produtos best-sellers

### 4. Forecasting
- Projetar vendas futuras baseado em tendências
- Identificar sazonalidades
- Planejar estoque

---

## 📦 Processo ETL (Silver → Gold)

### Pipeline de Transformação

```python
# 1. Carregar dados Silver
df_silver = pd.read_csv('silver/data/amazon_products_cleaned.csv')

# 2. Criar dimensões
dim_produto = df_silver[['title', 'is_best_seller', 'is_sponsored']].drop_duplicates()
dim_preco = criar_dim_preco(df_silver)
dim_avaliacao = criar_dim_avaliacao(df_silver)
dim_promocional = criar_dim_promocional(df_silver)
dim_tempo = criar_dim_tempo(df_silver)

# 3. Criar tabela fato
fato = criar_fato_vendas(df_silver, dimensoes)

# 4. Carregar no Data Warehouse
carregar_dimensoes(conn, dimensoes)
carregar_fato(conn, fato)
```

---

## 🔒 Constraints e Validações

### Constraints de Integridade
- **Primary Keys:** Todas as dimensões e fato têm PK
- **Foreign Keys:** Fato referencia todas as dimensões
- **NOT NULL:** Campos obrigatórios definidos
- **CHECK:** Validações de negócio (valores positivos)

### Constraints de Negócio
- `purchased_last_month >= 0`: Vendas não negativas
- `receita_estimada >= 0`: Receita não negativa
- `rating BETWEEN 0 AND 5`: Rating válido
- `discount_percentage BETWEEN 0 AND 100`: Desconto válido

---

## 📊 Cardinalidade

```
dim_produto (1) ──────── (N) fato_produto_venda
dim_preco (1) ──────────── (N) fato_produto_venda
dim_avaliacao (1) ──────── (N) fato_produto_venda
dim_promocional (1) ────── (N) fato_produto_venda
dim_tempo (1) ──────────── (N) fato_produto_venda
```

**Estimativas:**
- dim_produto: ~30.000 registros
- dim_preco: ~5.000 combinações únicas
- dim_avaliacao: ~2.000 combinações
- dim_promocional: ~8 combinações
- dim_tempo: 365 registros/ano
- fato_produto_venda: ~30.000+ registros

---

## 🚀 Performance

### Índices Criados
- Índices em todas as PKs (automático)
- Índices em todas as FKs da tabela fato
- Índices compostos para queries comuns
- Índices em colunas de filtro frequente

### Otimizações Recomendadas
- **Particionamento:** Particionar fato por tempo_id (mensal/anual)
- **Materialized Views:** Criar MVs para agregações pesadas
- **Statistics:** Atualizar estatísticas regularmente
- **Vacuum:** Manutenção periódica

---

## 📝 Documentação Complementar

- **DDL Completo:** `star_schema.sql`
- **Dados Silver:** `../silver/data/amazon_products_cleaned.csv`
- **Notebook ETL:** `../notebooks/data-ingestion-and-medallion-architecture.ipynb`
- **Análises:** `../silver/Analytics.ipynb`

---

## 🔄 Versionamento

- **Versão:** 1.0
- **Data:** 2025-01-11
- **Autor:** Equipe de Dados
- **Status:** Produção

---

## 📞 Suporte

Para dúvidas ou sugestões sobre a modelagem:
- Abrir issue no repositório
- Contatar equipe de dados
