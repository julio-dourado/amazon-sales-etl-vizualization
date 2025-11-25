-- ============================================================================
-- SILVER LAYER: TABELA PRODUCT
-- Camada Silver - Dados limpos e validados da Amazon
-- ============================================================================

-- Criação do schema silver (caso não exista)
CREATE SCHEMA IF NOT EXISTS silver;

-- Comentário no schema
COMMENT ON SCHEMA silver IS 'Camada Silver - Dados limpos e validados';

-- ============================================================================
-- TABELA: PRODUCT
-- ============================================================================
DROP TABLE IF EXISTS silver.product CASCADE;

CREATE TABLE silver.product (
    id BIGINT PRIMARY KEY,
    asin VARCHAR(20),
    title TEXT,
    brand VARCHAR(100),
    category VARCHAR(50),
    rating DECIMAL(3,2),
    total_reviews INTEGER,
    purchased_last_month INTEGER,
    discounted_price DECIMAL(10,2),
    original_price DECIMAL(10,2),
    discount_percentage DECIMAL(5,2),
    is_best_seller BOOLEAN,
    is_sponsored BOOLEAN,
    has_coupon BOOLEAN,
    buy_box_availability BOOLEAN,
    quality_score DECIMAL(5,2),
    price_range VARCHAR(30),
    date DATE,
    time TIME,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- ÍNDICES PARA PERFORMANCE
-- ============================================================================
CREATE INDEX idx_product_asin ON silver.product(asin);
CREATE INDEX idx_product_brand ON silver.product(brand);
CREATE INDEX idx_product_category ON silver.product(category);
CREATE INDEX idx_product_rating ON silver.product(rating);
CREATE INDEX idx_product_date ON silver.product(date);
CREATE INDEX idx_product_price_range ON silver.product(price_range);
CREATE INDEX idx_product_best_seller ON silver.product(is_best_seller) WHERE is_best_seller = TRUE;
CREATE INDEX idx_product_sponsored ON silver.product(is_sponsored) WHERE is_sponsored = TRUE;

-- ============================================================================
-- COMENTÁRIOS NAS COLUNAS
-- ============================================================================
COMMENT ON TABLE silver.product IS 'Produtos da Amazon com dados limpos e enriquecidos';
COMMENT ON COLUMN silver.product.id IS 'ID único do produto (gerado)';
COMMENT ON COLUMN silver.product.asin IS 'Amazon Standard Identification Number';
COMMENT ON COLUMN silver.product.title IS 'Título completo do produto';
COMMENT ON COLUMN silver.product.brand IS 'Marca do produto';
COMMENT ON COLUMN silver.product.category IS 'Categoria do produto';
COMMENT ON COLUMN silver.product.rating IS 'Avaliação média (0-5)';
COMMENT ON COLUMN silver.product.total_reviews IS 'Total de avaliações';
COMMENT ON COLUMN silver.product.purchased_last_month IS 'Quantidade comprada no último mês';
COMMENT ON COLUMN silver.product.discounted_price IS 'Preço com desconto';
COMMENT ON COLUMN silver.product.original_price IS 'Preço original';
COMMENT ON COLUMN silver.product.discount_percentage IS 'Percentual de desconto';
COMMENT ON COLUMN silver.product.is_best_seller IS 'Possui badge de best seller';
COMMENT ON COLUMN silver.product.is_sponsored IS 'Produto patrocinado';
COMMENT ON COLUMN silver.product.has_coupon IS 'Possui cupom de desconto';
COMMENT ON COLUMN silver.product.buy_box_availability IS 'Disponível para compra';
COMMENT ON COLUMN silver.product.quality_score IS 'Score de qualidade calculado (rating * log(reviews))';
COMMENT ON COLUMN silver.product.price_range IS 'Faixa de preço do produto';
COMMENT ON COLUMN silver.product.date IS 'Data da coleta';
COMMENT ON COLUMN silver.product.time IS 'Hora da coleta';

-- ============================================================================
-- VIEWS AUXILIARES (OPCIONAL)
-- ============================================================================

-- View: Produtos best sellers
CREATE OR REPLACE VIEW silver.vw_best_sellers AS
SELECT 
    id,
    asin,
    title,
    brand,
    category,
    rating,
    total_reviews,
    discounted_price,
    quality_score
FROM silver.product
WHERE is_best_seller = TRUE
ORDER BY quality_score DESC;

-- View: Produtos com maior desconto
CREATE OR REPLACE VIEW silver.vw_top_discounts AS
SELECT 
    id,
    asin,
    title,
    brand,
    category,
    original_price,
    discounted_price,
    discount_percentage
FROM silver.product
WHERE discount_percentage > 0
ORDER BY discount_percentage DESC;

-- View: Resumo por categoria
CREATE OR REPLACE VIEW silver.vw_category_summary AS
SELECT 
    category,
    COUNT(*) as total_products,
    ROUND(AVG(rating), 2) as avg_rating,
    ROUND(AVG(discounted_price), 2) as avg_price,
    SUM(CASE WHEN is_best_seller THEN 1 ELSE 0 END) as best_sellers_count,
    SUM(CASE WHEN has_coupon THEN 1 ELSE 0 END) as with_coupon_count
FROM silver.product
GROUP BY category
ORDER BY total_products DESC;

-- ============================================================================
-- FIM DO DDL
-- ============================================================================
