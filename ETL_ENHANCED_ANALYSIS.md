# 🔍 Análise do ETL Enhanced para Implementação Silver → Gold

**Data**: 7 de Novembro, 2025  
**Objetivo de Negócio**: Gerente de E-commerce - Análise de Performance de Produtos  
**Próxima Etapa**: Criar Star Schema (Gold Layer) para Power BI

---

## 📊 1. STATUS ATUAL DO ETL ENHANCED

### ✅ O que já está implementado e FUNCIONAL

#### 1.1 Extração de ASIN (ID do Produto)
```python
df['asin'] = df['product_url'].apply(extract_asin)
```
- **Status**: ✅ Implementado corretamente
- **Cobertura esperada**: ~95%+ dos produtos
- **Uso no Gold**: Será a chave primária de `dim_produto`

#### 1.2 Deduplicação por ASIN
```python
df = df.drop_duplicates(subset=['asin'], keep='first')
```
- **Status**: ✅ Implementado
- **Impacto**: Remove ~8,000 snapshots duplicados
- **Resultado**: Cada produto aparece uma única vez

#### 1.3 Extração de Marca (Brand)
```python
df['brand'] = df['title'].apply(extract_brand)
```
- **Status**: ✅ Implementado com stopwords
- **Cobertura esperada**: ~200+ marcas únicas
- **Uso no Gold**: Dimensão crítica para análise

#### 1.4 Inferência de Categoria
```python
df['category'] = df['title'].apply(infer_category)
```
- **Status**: ✅ Implementado com 11 categorias
- **Categorias**: Laptop, Audio, Camera, Mobile, Storage, Wearable, Accessory, TV/Display, Gaming, Tablet, Other
- **Uso no Gold**: Dimensão principal para segmentação

#### 1.5 Engenharia de Desconto
```python
df['discount_pct'] = ...
df['discount_bucket'] = pd.cut(df['discount_pct'], bins=[...])
df['has_discount'] = df['discount_pct'] > 0
```
- **Status**: ✅ Implementado
- **Buckets**: 'No Discount', '0-10%', '10-20%', '20-30%', '30-50%', '50%+'
- **Uso no Gold**: `dim_desconto` ou atributo em `dim_preco`

#### 1.6 Parse de Unidades Vendidas (TARGET)
```python
df['units_sold'] = df['bought_in_last_month'].apply(parse_units_sold)
```
- **Status**: ✅ Implementado com parsing robusto
- **Casos tratados**: "6K+", "1.5k", "Less than 100", "New to market"
- **Uso no Gold**: **MEASURE principal** em `fato_vendas`

#### 1.7 Features Temporais
```python
df['date'], df['hour'], df['day_of_week'], df['day_name']
```
- **Status**: ✅ Implementado
- **Uso no Gold**: `dim_tempo`

#### 1.8 Imputação Inteligente de Preços
```python
# Waterfall: Brand+Category → Brand → Category → Global
df['final_price'] = imputed via tiered medians
df['price_imputation_tier'] = tracking field
```
- **Status**: ✅ Implementado
- **Impacto**: Salva ~11,749 produtos (27.5% dos dados!)
- **Auditável**: Campo `price_imputation_tier` rastreia origem

---

## ⚠️ 2. AJUSTES NECESSÁRIOS PARA O OBJETIVO "OPÇÃO A"

### 🎯 Lembrete do Objetivo
> **"Identificar produtos com melhor desempenho de vendas para decisões de estoque, promoções e destaque na plataforma"**

### 2.1 REMOVER Features de Machine Learning (Não precisamos!)

**O que está no código mas NÃO vamos usar no Power BI:**

```python
# ❌ REMOVER do output final (ou ignorar no Gold)
df['log1p_reviews'] = np.log1p(df['number_of_reviews'])
df['log1p_price'] = np.log1p(df['final_price'])
df['log1p_units_sold'] = np.log1p(df['units_sold'])
```

**Justificativa**: 
- Log transforms são para estabilizar variância em modelos de ML
- Power BI trabalha com valores naturais
- Aumenta confusão na interpretação

**Ação**: Manter no código (caso futuro projeto de ML), mas **NÃO incluir no Star Schema**

---

### 2.2 ADICIONAR Feature: Faixa de Preço (Price Tier)

**Problema**: Temos `discount_bucket`, mas falta `price_tier` para análise de segmento de mercado

**Solução**: Adicionar ao ETL enhanced

```python
# Adicionar após linha 406 (depois do discount_bucket)
def create_price_tier(price):
    """Categoriza produtos por faixa de preço"""
    if pd.isna(price):
        return 'Unknown'
    elif price < 20:
        return 'Budget (< $20)'
    elif price < 50:
        return 'Economy ($20-50)'
    elif price < 100:
        return 'Mid-Range ($50-100)'
    elif price < 200:
        return 'Premium ($100-200)'
    elif price < 500:
        return 'High-End ($200-500)'
    else:
        return 'Luxury ($500+)'

df['price_tier'] = df['final_price'].apply(create_price_tier)
```

**Uso no Power BI**:
- Slicer para filtrar por faixa de preço
- Análise: "Qual faixa de preço vende mais em cada categoria?"

---

### 2.3 ADICIONAR Feature: Score de Qualidade (Quality Score)

**Objetivo**: Criar métrica composta para identificar produtos "estrela"

```python
# Adicionar após linha 420 (depois dos log transforms)
def calculate_quality_score(row):
    """
    Combina rating + social proof para score 0-100
    Útil para quadrante analysis no Power BI
    """
    if pd.isna(row['rating']) or pd.isna(row['total_reviews']):
        return None
    
    # Normalizar rating (0-5 → 0-50 pontos)
    rating_score = (row['rating'] / 5.0) * 50
    
    # Normalizar reviews (log scale, 0-50 pontos)
    # Assumindo: 0 reviews = 0 pts, 10K+ reviews = 50 pts
    review_score = min(50, (np.log1p(row['total_reviews']) / np.log1p(10000)) * 50)
    
    return rating_score + review_score

df['quality_score'] = df.apply(calculate_quality_score, axis=1)
```

**Uso no Power BI**:
- Scatter plot: Quality Score vs Units Sold
- Identificar "Hidden Gems" (alto score, baixas vendas)

---

### 2.4 ADICIONAR Feature: Receita Estimada

**Problema**: Temos `units_sold` e `final_price`, mas não calculamos receita

```python
# Adicionar após o quality_score
df['estimated_revenue'] = df['units_sold'] * df['final_price']
```

**Uso no Gold**: MEASURE secundária em `fato_vendas`

**Uso no Power BI**:
- KPI: "Receita Total Estimada"
- Ranking: "Top 10 Produtos por Receita"

---

### 2.5 ADICIONAR Flag: Produto "Promovível"

**Lógica de Negócio**: Produtos que o gerente deve considerar promover

```python
# Adicionar após estimated_revenue
def is_promotable(row):
    """
    Produto promovível se:
    - Rating >= 4.0 (boa qualidade)
    - Reviews >= 100 (social proof)
    - Units sold >= 200 (demanda comprovada)
    - Buy box disponível
    """
    if pd.isna(row['rating']) or pd.isna(row['total_reviews']):
        return False
    
    return (
        row['rating'] >= 4.0 and
        row['total_reviews'] >= 100 and
        row['units_sold'] >= 200 and
        row['buy_box_availability'] == True
    )

df['is_promotable'] = df.apply(is_promotable, axis=1)
```

**Uso no Power BI**:
- Filtro: "Mostrar apenas produtos promovíveis"
- Dashboard: "Catálogo de Produtos Prontos para Destaque"

---

### 2.6 RENOMEAR Colunas para Clareza no Power BI

**Problema**: Alguns nomes de colunas são técnicos demais

```python
# Adicionar ao final do script, antes do save
df = df.rename(columns={
    'total_reviews': 'review_count',
    'is_best_seller': 'best_seller_badge',
    'is_sponsored': 'sponsored_badge',
    'buy_box_availability': 'available_for_purchase',
    'has_discount': 'is_discounted',
    'has_coupon': 'has_active_coupon',
    'units_sold': 'units_sold_last_month',
    'estimated_revenue': 'revenue_last_month'
})
```

---

## 📋 3. COLUNAS FINAIS DO SILVER ENHANCED (Para Gold)

### Colunas a MANTER no Star Schema:

```
✅ IDENTIFICADORES
- asin (PK)

✅ DIMENSÕES
- title
- brand
- category
- price_tier (NOVO)

✅ MÉTRICAS DE QUALIDADE
- rating
- review_count
- quality_score (NOVO)

✅ PREÇOS
- final_price
- original_price
- discount_pct
- discount_bucket

✅ FLAGS / BADGES
- best_seller_badge
- sponsored_badge
- available_for_purchase
- is_discounted
- has_active_coupon
- is_promotable (NOVO)

✅ MÉTRICAS DE VENDAS (MEASURES!)
- units_sold_last_month
- revenue_last_month (NOVO)

✅ TEMPO
- date
- hour
- day_of_week
- day_name
- collected_at

✅ AUDITORIA
- price_imputation_tier
- bought_in_last_month_raw
```

### Colunas a IGNORAR no Star Schema (mantém no Silver, mas não usa no Gold):

```
❌ NÃO USAR NO GOLD
- log1p_reviews (só para ML)
- log1p_price (só para ML)
- log1p_units_sold (só para ML)
- discounted_price (duplicado, usamos final_price)
- price_on_variant (duplicado)
- time (usamos hour)
- is_couponed_raw (duplicado)
- price_source (auditoria técnica)
```

---

## 🗂️ 4. STAR SCHEMA PROPOSTO (Gold Layer)

### 4.1 Fato: Vendas de Produtos

```sql
CREATE TABLE gold.fato_vendas (
    venda_key SERIAL PRIMARY KEY,
    
    -- Foreign Keys
    produto_key INTEGER NOT NULL REFERENCES gold.dim_produto(produto_key),
    tempo_key INTEGER NOT NULL REFERENCES gold.dim_tempo(tempo_key),
    preco_key INTEGER NOT NULL REFERENCES gold.dim_preco(preco_key),
    
    -- Measures (Métricas)
    unidades_vendidas INTEGER,
    receita_estimada NUMERIC(12,2),
    rating NUMERIC(3,2),
    total_reviews INTEGER,
    quality_score NUMERIC(5,2),
    
    -- Metadata
    data_coleta TIMESTAMP,
    origem_preco VARCHAR(30)  -- para auditoria
);

CREATE INDEX idx_fato_produto ON gold.fato_vendas(produto_key);
CREATE INDEX idx_fato_tempo ON gold.fato_vendas(tempo_key);
CREATE INDEX idx_fato_preco ON gold.fato_vendas(preco_key);
```

### 4.2 Dimensão: Produto

```sql
CREATE TABLE gold.dim_produto (
    produto_key SERIAL PRIMARY KEY,
    asin VARCHAR(10) UNIQUE NOT NULL,
    titulo TEXT,
    marca VARCHAR(100),
    categoria VARCHAR(50),
    
    -- Flags
    is_best_seller BOOLEAN,
    is_sponsored BOOLEAN,
    is_promotable BOOLEAN,
    disponivel_compra BOOLEAN,
    
    -- SCD Type 1 (sempre atualiza)
    url_imagem TEXT,
    data_atualizacao TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_produto_asin ON gold.dim_produto(asin);
CREATE INDEX idx_produto_marca ON gold.dim_produto(marca);
CREATE INDEX idx_produto_categoria ON gold.dim_produto(categoria);
```

### 4.3 Dimensão: Tempo

```sql
CREATE TABLE gold.dim_tempo (
    tempo_key SERIAL PRIMARY KEY,
    data DATE NOT NULL UNIQUE,
    
    -- Componentes temporais
    ano INTEGER,
    mes INTEGER,
    dia INTEGER,
    dia_semana INTEGER,  -- 0=Monday, 6=Sunday
    nome_dia_semana VARCHAR(10),
    
    -- Agrupamentos
    trimestre INTEGER,
    semana_ano INTEGER,
    eh_fim_semana BOOLEAN,
    
    -- Para filtros no Power BI
    mes_ano VARCHAR(7),  -- '2025-08'
    ano_trimestre VARCHAR(7)  -- '2025-Q3'
);

CREATE INDEX idx_tempo_data ON gold.dim_tempo(data);
```

### 4.4 Dimensão: Preço & Desconto

```sql
CREATE TABLE gold.dim_preco (
    preco_key SERIAL PRIMARY KEY,
    
    -- Faixa de preço
    faixa_preco VARCHAR(30),  -- 'Budget (< $20)', etc.
    preco_min NUMERIC(10,2),
    preco_max NUMERIC(10,2),
    
    -- Desconto
    faixa_desconto VARCHAR(20),  -- '20-30%', etc.
    desconto_min NUMERIC(5,2),
    desconto_max NUMERIC(5,2),
    
    -- Flags
    tem_desconto BOOLEAN,
    tem_cupom BOOLEAN,
    
    -- Combinação única
    UNIQUE(faixa_preco, faixa_desconto, tem_cupom)
);
```

### 4.5 Opcional: Dimensão Degenerada de Horário

```sql
CREATE TABLE gold.dim_hora (
    hora_key SERIAL PRIMARY KEY,
    hora INTEGER UNIQUE NOT NULL,  -- 0-23
    
    -- Agrupamentos
    periodo_dia VARCHAR(15),  -- 'Madrugada', 'Manhã', 'Tarde', 'Noite'
    horario_comercial BOOLEAN  -- 9h-18h
);
```

---

## 🔧 5. PIPELINE COMPLETO: BRONZE → SILVER → GOLD

### Fluxo de Dados

```
┌─────────────────────────────────────────────────────────────┐
│ BRONZE (Raw)                                                │
│ - 42,675 rows                                               │
│ - 16 columns (all TEXT)                                     │
│ - amazon_products_sales_data_uncleaned.csv                  │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ etl_enhanced.py (Python script)
                 │ - ASIN extraction
                 │ - Deduplication
                 │ - Feature engineering
                 │ - Smart imputation
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ SILVER (Cleaned & Enhanced)                                 │
│ - ~34,000 rows (após dedup)                                 │
│ - 32+ columns (typed)                                       │
│ - amazon_products_cleaned_enhanced.csv                      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ ETL Silver → Gold (SQL + Python)
                 │ - Populate dimensions
                 │ - Create fact table
                 │ - Establish FK relationships
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ GOLD (Star Schema)                                          │
│ - 4 dimension tables                                        │
│ - 1 fact table (~34,000 rows)                               │
│ - Optimized for BI queries                                  │
│                                                              │
│ Tables:                                                      │
│  - gold.dim_produto                                         │
│  - gold.dim_tempo                                           │
│  - gold.dim_preco                                           │
│  - gold.fato_vendas                                         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ Power BI Connection
                 │ - DirectQuery ou Import
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ POWER BI Dashboards                                         │
│ - Executive Overview                                        │
│ - Discount Impact Analysis                                  │
│ - Brand Performance                                         │
│ - Product Quality Matrix                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ 6. CHECKLIST DE IMPLEMENTAÇÃO

### Fase 1: Ajustar ETL Enhanced (1-2 horas)

- [ ] Adicionar `price_tier` calculation
- [ ] Adicionar `quality_score` calculation
- [ ] Adicionar `estimated_revenue` calculation
- [ ] Adicionar `is_promotable` flag
- [ ] Renomear colunas para clareza
- [ ] Atualizar `columns_to_keep` list
- [ ] Testar script completo
- [ ] Validar output CSV

### Fase 2: Criar DDL do Gold Layer (1 hora)

- [ ] Criar arquivo `03_create_gold_schema.sql`
- [ ] Implementar `dim_produto`
- [ ] Implementar `dim_tempo`
- [ ] Implementar `dim_preco`
- [ ] Implementar `fato_vendas`
- [ ] Criar índices
- [ ] Documentar relacionamentos

### Fase 3: Criar ETL Silver → Gold (2-3 horas)

- [ ] Script Python: `ETL_silver_to_gold.py`
- [ ] Popular `dim_tempo` (via range de datas)
- [ ] Popular `dim_preco` (via combinações únicas)
- [ ] Popular `dim_produto` (via ASIN únicos)
- [ ] Popular `fato_vendas` (join com PKs das dims)
- [ ] Validar integridade referencial
- [ ] Testar queries de exemplo

### Fase 4: Conectar ao Power BI (2 horas)

- [ ] Conectar ao Postgres (Gold schema)
- [ ] Importar tabelas
- [ ] Validar relacionamentos automáticos
- [ ] Criar medidas DAX básicas
- [ ] Testar slicers

### Fase 5: Dashboards (4 horas)

- [ ] Dashboard 1: Executive Overview
- [ ] Dashboard 2: Discount Impact
- [ ] Dashboard 3: Brand Performance
- [ ] Dashboard 4: Product Quality Matrix

---

## 🚨 7. PROBLEMAS POTENCIAIS E SOLUÇÕES

### 7.1 Problema: Muitos ASINs sem `units_sold`

**Sintoma**: Campo `bought_in_last_month` vazio ou não parseável

**Solução no ETL**:
```python
# Já implementado no parse_units_sold()
# Retorna NaN para casos inválidos
# No Gold, tratar NaN como 0 ou excluir do fato
```

**Decisão de Negócio**: Para o objetivo "análise de performance", **excluir produtos sem vendas** da fato_vendas (mas manter em dim_produto para catálogo completo)

### 7.2 Problema: Price Tier pode mudar com o tempo

**Sintoma**: Um produto pode mudar de "Premium" para "Mid-Range" se o preço cair

**Solução**: 
- `dim_preco` é **snapshot** do preço no momento da coleta
- Se houver múltiplas coletas (futuro), cada snapshot gera uma nova FK
- Atualmente (coleta única em Aug 2025), não é problema

### 7.3 Problema: Categorias "Other" muito grande

**Sintoma**: 30%+ dos produtos caem em "Other"

**Solução Iterativa**:
1. Rodar ETL e verificar quantidade em "Other"
2. Se > 20%, adicionar mais regras no `infer_category()`
3. Analisar títulos manualmente: `df[df['category']=='Other']['title'].sample(50)`
4. Expandir category_rules

### 7.4 Problema: Brands com typos

**Sintoma**: "samsung" vs "samsun" vs "samung"

**Solução no Gold**:
```python
# Adicionar normalização de marcas conhecidas
BRAND_ALIASES = {
    'samsun': 'samsung',
    'samung': 'samsung',
    'appl': 'apple',
    # etc
}

df['brand'] = df['brand'].map(lambda x: BRAND_ALIASES.get(x, x))
```

---

## 📊 8. QUERIES DE VALIDAÇÃO PÓS-GOLD

### Validar Integridade

```sql
-- 1. Órfãos na fato_vendas?
SELECT COUNT(*) 
FROM gold.fato_vendas f
LEFT JOIN gold.dim_produto p ON f.produto_key = p.produto_key
WHERE p.produto_key IS NULL;
-- Esperado: 0

-- 2. Produtos sem vendas?
SELECT COUNT(*)
FROM gold.dim_produto p
LEFT JOIN gold.fato_vendas f ON p.produto_key = f.produto_key
WHERE f.venda_key IS NULL;
-- OK ter alguns (produtos sem dados de vendas)

-- 3. Distribuição por categoria
SELECT 
    p.categoria,
    COUNT(*) as produtos,
    SUM(f.unidades_vendidas) as total_vendas,
    AVG(f.rating) as rating_medio
FROM gold.fato_vendas f
JOIN gold.dim_produto p ON f.produto_key = p.produto_key
GROUP BY p.categoria
ORDER BY total_vendas DESC;
```

### Queries de Negócio (Exemplos para Power BI)

```sql
-- Top 10 produtos por receita
SELECT 
    p.titulo,
    p.marca,
    p.categoria,
    f.unidades_vendidas,
    f.receita_estimada,
    f.rating
FROM gold.fato_vendas f
JOIN gold.dim_produto p ON f.produto_key = p.produto_key
ORDER BY f.receita_estimada DESC
LIMIT 10;

-- Efetividade de desconto por categoria
SELECT 
    p.categoria,
    pr.faixa_desconto,
    AVG(f.unidades_vendidas) as vendas_medias,
    COUNT(*) as qtd_produtos
FROM gold.fato_vendas f
JOIN gold.dim_produto p ON f.produto_key = p.produto_key
JOIN gold.dim_preco pr ON f.preco_key = pr.preco_key
GROUP BY p.categoria, pr.faixa_desconto
ORDER BY p.categoria, vendas_medias DESC;

-- Produtos "promovíveis" por marca
SELECT 
    p.marca,
    COUNT(*) as produtos_prontos
FROM gold.dim_produto p
WHERE p.is_promotable = TRUE
GROUP BY p.marca
ORDER BY produtos_prontos DESC;
```

---

## 🎯 9. DECISÃO FINAL: ESTÁ PRONTO PARA GOLD?

### ✅ SIM, se você fizer os ajustes da Seção 2

**O que está PERFEITO**:
- ASIN extraction e deduplication
- Brand e category extraction
- Smart price imputation
- Target parsing (units_sold)
- Discount engineering
- Temporal features

**O que precisa ADICIONAR**:
- `price_tier` (crítico para segmentação)
- `quality_score` (útil para quadrante analysis)
- `estimated_revenue` (métrica de negócio)
- `is_promotable` (flag de ação)
- Renomear colunas (UX no Power BI)

**Tempo estimado para ajustes**: 1-2 horas

**Após ajustes**: O Silver estará 100% pronto para alimentar o Gold Schema proposto

---

## 📁 10. ARQUIVOS A CRIAR

```
data-lake/
├── transformers/
│   ├── etl_enhanced.py (ATUALIZAR com seção 2)
│   ├── etl_silver_to_gold.py (CRIAR)
│   └── ETL_SILVER_TO_GOLD_SUMMARY.md (CRIAR)
│
├── gold/
│   ├── ddl/
│   │   └── star_schema.sql (CRIAR)
│   └── data/
│       └── (tabelas exportadas para backup, opcional)
│
└── documentation/
    └── STAR_SCHEMA_DOCUMENTATION.md (CRIAR)
```

---

## 🎓 11. JUSTIFICATIVA PARA O PROFESSOR

### Por que este design?

1. **Business-Driven**: Cada feature foi criada pensando nas perguntas do gerente de e-commerce
2. **Dimensional Modeling**: Star Schema é padrão-ouro para BI (Kimball methodology)
3. **Escalável**: Se adicionar mais snapshots no futuro, basta popular fato_vendas com novas FKs
4. **Auditável**: Campos como `price_imputation_tier` permitem rastrear decisões
5. **Pragmático**: Não implementamos ML desnecessário, foco em visualização e insights

---

## ✅ CONCLUSÃO

**Status**: ETL Enhanced está **95% pronto** para Gold Layer

**Próximos passos**:
1. Aplicar ajustes da Seção 2 (1-2h)
2. Rodar `etl_enhanced.py` e validar output
3. Criar SQL DDL do Gold Schema
4. Implementar `etl_silver_to_gold.py`
5. Conectar Power BI e criar dashboards

**Prazo estimado total**: 8-10 horas de trabalho

**Resultado esperado**: Sistema de BI completo respondendo às perguntas de negócio do Gerente de E-commerce

---

**Documento preparado por**: Leonardo Lago  
**Revisão recomendada**: Julio Dourado, Gustavo Rodrigues  
**Versão**: 1.0

