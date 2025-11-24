-- ============================================================================
-- GOLD LAYER: STAR SCHEMA - DDL
-- Business Objective: E-commerce Manager - Product Performance Analysis
-- ============================================================================

DROP SCHEMA IF EXISTS gold CASCADE;
CREATE SCHEMA gold;

COMMENT ON SCHEMA gold IS 'Camada Gold - Dados agregados e otimizados para análise';

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

COMMENT ON TABLE gold.dim_prdt IS 'Dimensão Produto - Informações sobre os produtos';
COMMENT ON COLUMN gold.dim_prdt.prdt_key IS 'Chave primária surrogate';
COMMENT ON COLUMN gold.dim_prdt.asin IS 'Amazon Standard Identification Number';
COMMENT ON COLUMN gold.dim_prdt.is_promotable IS 'Produto elegível para promoções';

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
CREATE INDEX idx_tmp_trimestre ON gold.dim_tmp(ano_trimestre);

COMMENT ON TABLE gold.dim_tmp IS 'Dimensão Tempo - Hierarquia temporal para análises';
COMMENT ON COLUMN gold.dim_tmp.tmp_key IS 'Chave primária surrogate';
COMMENT ON COLUMN gold.dim_tmp.eh_fim_semana IS 'Indica se é sábado ou domingo';

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

COMMENT ON TABLE gold.dim_cat IS 'Dimensão Categoria - Classificação dos produtos';
COMMENT ON COLUMN gold.dim_cat.cat_key IS 'Chave primária surrogate';

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
CREATE INDEX idx_ft_vnd_data_coleta ON gold.ft_vnd(data_coleta);

COMMENT ON TABLE gold.ft_vnd IS 'Fato Vendas - Métricas de performance de vendas';
COMMENT ON COLUMN gold.ft_vnd.vnd_key IS 'Chave primária surrogate';
COMMENT ON COLUMN gold.ft_vnd.unidades_vendidas IS 'Quantidade vendida no último mês';
COMMENT ON COLUMN gold.ft_vnd.receita_estimada IS 'Receita estimada (preço × unidades)';
COMMENT ON COLUMN gold.ft_vnd.quality_score IS 'Score de qualidade (rating × log(reviews))';

-- ============================================================================
-- VIEWS ANALÍTICAS
-- ============================================================================

-- View: Resumo por categoria
CREATE OR REPLACE VIEW gold.vw_resumo_categoria AS
SELECT
    c.categoria,
    c.segmento,
    COUNT(DISTINCT f.prdt_key) AS total_produtos,
    SUM(f.unidades_vendidas) AS total_unidades,
    SUM(f.receita_estimada) AS receita_total,
    AVG(f.rating) AS rating_medio,
    AVG(f.quality_score) AS quality_score_medio
FROM gold.ft_vnd f
JOIN gold.dim_cat c ON f.cat_key = c.cat_key
GROUP BY c.categoria, c.segmento
ORDER BY receita_total DESC;

-- View: Top produtos por receita
CREATE OR REPLACE VIEW gold.vw_top_produtos AS
SELECT
    p.asin,
    p.titulo,
    p.marca,
    p.categoria,
    SUM(f.receita_estimada) AS receita_total,
    SUM(f.unidades_vendidas) AS unidades_total,
    AVG(f.rating) AS rating_medio
FROM gold.ft_vnd f
JOIN gold.dim_prdt p ON f.prdt_key = p.prdt_key
GROUP BY p.asin, p.titulo, p.marca, p.categoria
ORDER BY receita_total DESC
LIMIT 100;

-- View: Performance temporal
CREATE OR REPLACE VIEW gold.vw_performance_temporal AS
SELECT
    t.ano,
    t.mes,
    t.mes_ano,
    t.trimestre,
    COUNT(DISTINCT f.prdt_key) AS produtos_vendidos,
    SUM(f.unidades_vendidas) AS total_unidades,
    SUM(f.receita_estimada) AS receita_total,
    AVG(f.rating) AS rating_medio
FROM gold.ft_vnd f
JOIN gold.dim_tmp t ON f.tmp_key = t.tmp_key
GROUP BY t.ano, t.mes, t.mes_ano, t.trimestre
ORDER BY t.ano, t.mes;

-- ============================================================================
-- GRANTS (opcional - para usuários BI)
-- ============================================================================
-- GRANT SELECT ON ALL TABLES IN SCHEMA gold TO powerbi_user;
-- GRANT SELECT ON ALL SEQUENCES IN SCHEMA gold TO powerbi_user;
-- GRANT USAGE ON SCHEMA gold TO powerbi_user;

-- ============================================================================
-- FIM DO DDL GOLD
-- ============================================================================
