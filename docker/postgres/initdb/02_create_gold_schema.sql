-- ============================================================================
-- GOLD LAYER: STAR SCHEMA
-- Business Objective: E-commerce Manager - Product Performance Analysis
-- ============================================================================

DROP SCHEMA IF EXISTS gold CASCADE;
CREATE SCHEMA gold;

-- ============================================================================
-- DIMENSION 1: PRODUTO
-- ============================================================================
CREATE TABLE gold.dim_prdt (
    prdt_key SERIAL PRIMARY KEY,
    asin VARCHAR(20) UNIQUE NOT NULL,
    titulo TEXT,
    marca VARCHAR(100),
    categoria VARCHAR(50),
    faixa_preco VARCHAR(30),
    
    -- Flags (Slowly Changing Dimension Type 1)
    best_seller_badge BOOLEAN,
    sponsored_badge BOOLEAN,
    is_promotable BOOLEAN,
    disponivel_compra BOOLEAN,
    
    -- Metadata
    data_atualizacao TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_prdt_asin ON gold.dim_prdt(asin);
CREATE INDEX idx_prdt_marca ON gold.dim_prdt(marca);
CREATE INDEX idx_prdt_categoria ON gold.dim_prdt(categoria);
CREATE INDEX idx_prdt_faixa_preco ON gold.dim_prdt(faixa_preco);

-- ============================================================================
-- DIMENSION 2: TEMPO
-- ============================================================================
CREATE TABLE gold.dim_tmp (
    tmp_key SERIAL PRIMARY KEY,
    data DATE NOT NULL UNIQUE,
    ano INTEGER,
    mes INTEGER,
    dia INTEGER,
    dia_semana INTEGER,  -- 0=Monday, 6=Sunday
    nome_dia_semana VARCHAR(10),
    trimestre INTEGER,
    semana_ano INTEGER,
    eh_fim_semana BOOLEAN,
    mes_ano VARCHAR(7),  -- '2025-08'
    ano_trimestre VARCHAR(7)  -- '2025-Q3'
);

CREATE INDEX idx_tmp_data ON gold.dim_tmp(data);
CREATE INDEX idx_tmp_mes_ano ON gold.dim_tmp(mes_ano);

-- ============================================================================
-- DIMENSION 3: CATEGORIA
-- ============================================================================
CREATE TABLE gold.dim_cat (
    cat_key SERIAL PRIMARY KEY,
    categoria VARCHAR(50) NOT NULL UNIQUE,
    tipo_produto VARCHAR(50),
    segmento VARCHAR(50)
);

CREATE INDEX idx_cat_categoria ON gold.dim_cat(categoria);
CREATE INDEX idx_cat_segmento ON gold.dim_cat(segmento);

-- ============================================================================
-- FACT TABLE: VENDAS
-- ============================================================================
CREATE TABLE gold.ft_vnd (
    vnd_key SERIAL PRIMARY KEY,
    
    -- Foreign Keys
    prdt_key INTEGER NOT NULL REFERENCES gold.dim_prdt(prdt_key),
    tmp_key INTEGER NOT NULL REFERENCES gold.dim_tmp(tmp_key),
    cat_key INTEGER NOT NULL REFERENCES gold.dim_cat(cat_key),
    
    -- Measures (Métricas Numéricas)
    unidades_vendidas INTEGER,
    receita_estimada NUMERIC(12,2),
    preco_final NUMERIC(10,2),
    rating NUMERIC(3,2),
    total_reviews INTEGER,
    quality_score NUMERIC(5,2),
    percentual_desconto NUMERIC(5,2),
    
    -- Metadata
    hora_coleta INTEGER,  -- 0-23
    data_coleta TIMESTAMP,
    origem_preco VARCHAR(30)  -- 'original', 'imputed_brand_cat', etc.
);

CREATE INDEX idx_ft_vnd_prdt ON gold.ft_vnd(prdt_key);
CREATE INDEX idx_ft_vnd_tmp ON gold.ft_vnd(tmp_key);
CREATE INDEX idx_ft_vnd_cat ON gold.ft_vnd(cat_key);
CREATE INDEX idx_ft_vnd_receita ON gold.ft_vnd(receita_estimada);

-- ============================================================================
-- Observação: crie views analíticas separadamente (ex.: notebook em data-lake/gold/Analytics.ipynb)
-- ============================================================================

-- ============================================================================
-- GRANT SELECT ON ALL TABLES IN SCHEMA gold TO powerbi_user;
-- GRANT SELECT ON ALL SEQUENCES IN SCHEMA gold TO powerbi_user;
