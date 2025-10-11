-- =====================================================
-- AMAZON PRODUCTS SALES - STAR SCHEMA (GOLD LAYER)
-- Data Warehouse - Modelo Dimensional
-- =====================================================

-- =====================================================
-- DIMENSÕES
-- =====================================================

-- Dimensão: Produto
CREATE TABLE dim_produto (
    produto_id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    is_best_seller BOOLEAN DEFAULT FALSE,
    is_sponsored BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_produto_title ON dim_produto(title);
CREATE INDEX idx_dim_produto_best_seller ON dim_produto(is_best_seller);

-- Dimensão: Preço
CREATE TABLE dim_preco (
    preco_id SERIAL PRIMARY KEY,
    discounted_price DECIMAL(10, 2) NOT NULL,
    original_price DECIMAL(10, 2),
    discount_percentage DECIMAL(5, 2),
    faixa_preco VARCHAR(50), -- 'Até $50', '$50-$200', '$200-$500', 'Acima de $500'
    has_discount BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_preco_faixa ON dim_preco(faixa_preco);
CREATE INDEX idx_dim_preco_discount ON dim_preco(has_discount);

-- Dimensão: Avaliação
CREATE TABLE dim_avaliacao (
    avaliacao_id SERIAL PRIMARY KEY,
    rating DECIMAL(2, 1),
    rating_categoria VARCHAR(20), -- 'Excelente', 'Bom', 'Regular', 'Ruim'
    total_reviews INTEGER DEFAULT 0,
    faixa_reviews VARCHAR(50), -- '0-100', '100-1000', '1000-10000', '>10000'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_avaliacao_rating ON dim_avaliacao(rating);
CREATE INDEX idx_dim_avaliacao_categoria ON dim_avaliacao(rating_categoria);

-- Dimensão: Promocional
CREATE TABLE dim_promocional (
    promocional_id SERIAL PRIMARY KEY,
    has_coupon BOOLEAN DEFAULT FALSE,
    coupon_discount_pct DECIMAL(5, 2) DEFAULT 0,
    buy_box_availability BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_promocional_coupon ON dim_promocional(has_coupon);

-- Dimensão: Tempo
CREATE TABLE dim_tempo (
    tempo_id SERIAL PRIMARY KEY,
    data_completa DATE NOT NULL UNIQUE,
    dia INTEGER NOT NULL,
    mes INTEGER NOT NULL,
    ano INTEGER NOT NULL,
    dia_semana INTEGER NOT NULL,
    nome_dia_semana VARCHAR(20),
    nome_mes VARCHAR(20),
    trimestre INTEGER NOT NULL,
    semestre INTEGER NOT NULL,
    is_final_semana BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_tempo_data ON dim_tempo(data_completa);
CREATE INDEX idx_dim_tempo_ano_mes ON dim_tempo(ano, mes);

-- =====================================================
-- FATO
-- =====================================================

-- Tabela Fato: Vendas de Produtos
CREATE TABLE fato_produto_venda (
    fato_id SERIAL PRIMARY KEY,
    produto_id INTEGER NOT NULL REFERENCES dim_produto(produto_id),
    preco_id INTEGER NOT NULL REFERENCES dim_preco(preco_id),
    avaliacao_id INTEGER NOT NULL REFERENCES dim_avaliacao(avaliacao_id),
    promocional_id INTEGER NOT NULL REFERENCES dim_promocional(promocional_id),
    tempo_id INTEGER NOT NULL REFERENCES dim_tempo(tempo_id),
    
    -- Métricas
    purchased_last_month INTEGER DEFAULT 0,
    receita_estimada DECIMAL(15, 2), -- purchased_last_month * discounted_price
    receita_potencial DECIMAL(15, 2), -- purchased_last_month * original_price
    economia_total DECIMAL(15, 2), -- receita_potencial - receita_estimada
    
    -- Metadados
    collected_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT chk_purchased_positive CHECK (purchased_last_month >= 0),
    CONSTRAINT chk_receita_positive CHECK (receita_estimada >= 0)
);

-- Índices para otimização de consultas
CREATE INDEX idx_fato_produto ON fato_produto_venda(produto_id);
CREATE INDEX idx_fato_preco ON fato_produto_venda(preco_id);
CREATE INDEX idx_fato_avaliacao ON fato_produto_venda(avaliacao_id);
CREATE INDEX idx_fato_promocional ON fato_produto_venda(promocional_id);
CREATE INDEX idx_fato_tempo ON fato_produto_venda(tempo_id);
CREATE INDEX idx_fato_collected_at ON fato_produto_venda(collected_at);

-- Índices compostos para consultas comuns
CREATE INDEX idx_fato_produto_tempo ON fato_produto_venda(produto_id, tempo_id);
CREATE INDEX idx_fato_tempo_produto ON fato_produto_venda(tempo_id, produto_id);

-- =====================================================
-- VIEWS ANALÍTICAS
-- =====================================================

-- View: Análise de Vendas por Faixa de Preço
CREATE OR REPLACE VIEW vw_vendas_por_faixa_preco AS
SELECT 
    dp.faixa_preco,
    COUNT(DISTINCT f.produto_id) as total_produtos,
    SUM(f.purchased_last_month) as total_vendas,
    SUM(f.receita_estimada) as receita_total,
    AVG(f.receita_estimada) as receita_media,
    AVG(da.rating) as rating_medio
FROM fato_produto_venda f
JOIN dim_preco dp ON f.preco_id = dp.preco_id
JOIN dim_avaliacao da ON f.avaliacao_id = da.avaliacao_id
GROUP BY dp.faixa_preco
ORDER BY receita_total DESC;

-- View: Top Produtos por Receita
CREATE OR REPLACE VIEW vw_top_produtos_receita AS
SELECT 
    dp.title,
    dp.is_best_seller,
    SUM(f.purchased_last_month) as total_vendas,
    SUM(f.receita_estimada) as receita_total,
    AVG(da.rating) as rating_medio,
    AVG(dpr.discount_percentage) as desconto_medio
FROM fato_produto_venda f
JOIN dim_produto dp ON f.produto_id = dp.produto_id
JOIN dim_preco dpr ON f.preco_id = dpr.preco_id
JOIN dim_avaliacao da ON f.avaliacao_id = da.avaliacao_id
GROUP BY dp.produto_id, dp.title, dp.is_best_seller
ORDER BY receita_total DESC
LIMIT 100;

-- View: Efetividade de Promoções
CREATE OR REPLACE VIEW vw_efetividade_promocoes AS
SELECT 
    dpm.has_coupon,
    dpm.buy_box_availability,
    COUNT(DISTINCT f.produto_id) as total_produtos,
    SUM(f.purchased_last_month) as total_vendas,
    AVG(f.purchased_last_month) as vendas_media,
    SUM(f.receita_estimada) as receita_total,
    AVG(da.rating) as rating_medio
FROM fato_produto_venda f
JOIN dim_promocional dpm ON f.promocional_id = dpm.promocional_id
JOIN dim_avaliacao da ON f.avaliacao_id = da.avaliacao_id
GROUP BY dpm.has_coupon, dpm.buy_box_availability
ORDER BY receita_total DESC;

-- View: Tendências Temporais
CREATE OR REPLACE VIEW vw_tendencias_temporais AS
SELECT 
    dt.ano,
    dt.mes,
    dt.nome_mes,
    COUNT(DISTINCT f.produto_id) as total_produtos,
    SUM(f.purchased_last_month) as total_vendas,
    SUM(f.receita_estimada) as receita_total,
    AVG(da.rating) as rating_medio
FROM fato_produto_venda f
JOIN dim_tempo dt ON f.tempo_id = dt.tempo_id
JOIN dim_avaliacao da ON f.avaliacao_id = da.avaliacao_id
GROUP BY dt.ano, dt.mes, dt.nome_mes
ORDER BY dt.ano, dt.mes;

-- =====================================================
-- FUNÇÕES AUXILIARES
-- =====================================================

-- Função: Classificar faixa de preço
CREATE OR REPLACE FUNCTION classificar_faixa_preco(preco DECIMAL)
RETURNS VARCHAR(50) AS $$
BEGIN
    RETURN CASE
        WHEN preco <= 50 THEN 'Até $50'
        WHEN preco <= 200 THEN '$50-$200'
        WHEN preco <= 500 THEN '$200-$500'
        ELSE 'Acima de $500'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Função: Classificar rating
CREATE OR REPLACE FUNCTION classificar_rating(rating DECIMAL)
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE
        WHEN rating >= 4.5 THEN 'Excelente'
        WHEN rating >= 3.5 THEN 'Bom'
        WHEN rating >= 2.5 THEN 'Regular'
        ELSE 'Ruim'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Função: Classificar faixa de reviews
CREATE OR REPLACE FUNCTION classificar_faixa_reviews(reviews INTEGER)
RETURNS VARCHAR(50) AS $$
BEGIN
    RETURN CASE
        WHEN reviews = 0 THEN 'Sem Reviews'
        WHEN reviews <= 100 THEN '1-100'
        WHEN reviews <= 1000 THEN '100-1000'
        WHEN reviews <= 10000 THEN '1000-10000'
        ELSE 'Acima de 10000'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger: Atualizar updated_at em dim_produto
CREATE OR REPLACE FUNCTION atualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_dim_produto_updated_at
BEFORE UPDATE ON dim_produto
FOR EACH ROW
EXECUTE FUNCTION atualizar_updated_at();

-- =====================================================
-- COMENTÁRIOS
-- =====================================================

COMMENT ON TABLE dim_produto IS 'Dimensão de produtos - contém informações sobre os produtos vendidos';
COMMENT ON TABLE dim_preco IS 'Dimensão de preços - contém informações sobre precificação e descontos';
COMMENT ON TABLE dim_avaliacao IS 'Dimensão de avaliações - contém informações sobre ratings e reviews';
COMMENT ON TABLE dim_promocional IS 'Dimensão promocional - contém informações sobre cupons e ofertas';
COMMENT ON TABLE dim_tempo IS 'Dimensão temporal - contém hierarquia de tempo para análises';
COMMENT ON TABLE fato_produto_venda IS 'Tabela fato principal - métricas de vendas e relacionamentos dimensionais';

COMMENT ON VIEW vw_vendas_por_faixa_preco IS 'Análise agregada de vendas segmentada por faixa de preço';
COMMENT ON VIEW vw_top_produtos_receita IS 'Top 100 produtos ordenados por receita total';
COMMENT ON VIEW vw_efetividade_promocoes IS 'Análise de efetividade de estratégias promocionais';
COMMENT ON VIEW vw_tendencias_temporais IS 'Análise de tendências ao longo do tempo';
