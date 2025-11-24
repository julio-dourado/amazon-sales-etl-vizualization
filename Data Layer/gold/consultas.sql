-- ============================================================================
-- GOLD LAYER: CONSULTAS ANALÍTICAS
-- Queries para análise de performance de produtos Amazon
-- ============================================================================

-- ============================================================================
-- 1. VERIFICAÇÃO DO SCHEMA GOLD
-- ============================================================================
-- Verificar contagem de registros em cada tabela
SELECT 'dim_prdt' AS tabela, COUNT(*) AS linhas FROM gold.dim_prdt
UNION ALL
SELECT 'dim_tmp' AS tabela, COUNT(*) AS linhas FROM gold.dim_tmp
UNION ALL
SELECT 'dim_cat' AS tabela, COUNT(*) AS linhas FROM gold.dim_cat
UNION ALL
SELECT 'ft_vnd' AS tabela, COUNT(*) AS linhas FROM gold.ft_vnd
ORDER BY tabela;

-- ============================================================================
-- 2. DESEMPENHO POR CATEGORIA
-- ============================================================================
-- Objetivo: medir tamanho, qualidade e potencial promocional por categoria
SELECT
    p.categoria,
    SUM(f.unidades_vendidas) AS total_unidades,
    SUM(f.receita_estimada) AS receita_total,
    AVG(f.rating) AS rating_medio,
    AVG(f.quality_score) AS quality_score_medio,
    SUM(CASE WHEN p.is_promotable THEN 1 ELSE 0 END) AS produtos_promoviveis,
    ROUND(100.0 * SUM(CASE WHEN p.is_promotable THEN 1 ELSE 0 END) / 
          NULLIF(COUNT(DISTINCT p.prdt_key), 0), 2) AS pct_promovivel,
    SUM(CASE WHEN p.best_seller_badge THEN f.receita_estimada ELSE 0 END) AS receita_best_seller
FROM gold.ft_vnd f
JOIN gold.dim_prdt p ON f.prdt_key = p.prdt_key
GROUP BY p.categoria
ORDER BY receita_total DESC;

-- ============================================================================
-- 3. TOP 3 FAIXAS DE PREÇO DENTRO DE CADA CATEGORIA
-- ============================================================================
-- Objetivo: descobrir quais tickets mais faturam em cada categoria
WITH base AS (
    SELECT
        p.categoria,
        p.faixa_preco,
        SUM(f.receita_estimada) AS receita_total,
        SUM(f.unidades_vendidas) AS unidades_total
    FROM gold.ft_vnd f
    JOIN gold.dim_prdt p ON f.prdt_key = p.prdt_key
    GROUP BY p.categoria, p.faixa_preco
),
ranked AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (PARTITION BY categoria ORDER BY receita_total DESC) AS pos_receita,
        SUM(receita_total) OVER (PARTITION BY categoria) AS receita_categoria
    FROM base b
)
SELECT
    categoria,
    faixa_preco,
    receita_total,
    ROUND(100.0 * receita_total / NULLIF(receita_categoria, 0), 2) AS pct_receita_categoria,
    unidades_total,
    ROUND(receita_total / NULLIF(unidades_total, 0), 2) AS ticket_medio
FROM ranked
WHERE pos_receita <= 3
ORDER BY receita_categoria DESC, categoria, pos_receita;

-- ============================================================================
-- 4. FAIXAS DE PREÇO MAIS FORTES (GERAL)
-- ============================================================================
-- Objetivo: avaliar quais faixas concentram produtos, receita e satisfação
SELECT
    p.faixa_preco,
    COUNT(DISTINCT p.prdt_key) AS produtos,
    SUM(f.unidades_vendidas) AS unidades_total,
    SUM(f.receita_estimada) AS receita_total,
    ROUND(SUM(f.receita_estimada) / NULLIF(SUM(f.unidades_vendidas), 0), 2) AS ticket_medio,
    ROUND(AVG(f.rating), 2) AS rating_medio,
    ROUND(AVG(f.quality_score), 2) AS quality_score_medio
FROM gold.ft_vnd f
JOIN gold.dim_prdt p ON f.prdt_key = p.prdt_key
GROUP BY p.faixa_preco
ORDER BY receita_total DESC;

-- ============================================================================
-- 5. "HIDDEN GEMS": ALTA QUALIDADE, BAIXA RECEITA
-- ============================================================================
-- Objetivo: produtos com melhor qualidade nas faixas de menor receita
WITH limites AS (
    SELECT
        percentile_cont(0.75) WITHIN GROUP (ORDER BY f.quality_score) AS q75_quality,
        percentile_cont(0.25) WITHIN GROUP (ORDER BY f.receita_estimada) AS q25_receita
    FROM gold.ft_vnd f
    WHERE f.quality_score IS NOT NULL
      AND f.receita_estimada IS NOT NULL
)
SELECT
    p.asin,
    p.titulo,
    p.marca,
    p.categoria,
    f.quality_score,
    f.receita_estimada,
    f.unidades_vendidas,
    f.rating
FROM gold.ft_vnd f
JOIN gold.dim_prdt p ON f.prdt_key = p.prdt_key
CROSS JOIN limites l
WHERE f.quality_score >= l.q75_quality
  AND f.receita_estimada <= l.q25_receita
ORDER BY f.quality_score DESC, f.receita_estimada ASC
LIMIT 10;

-- ============================================================================
-- 6. PIPELINE DE PRODUTOS PROMOVÍVEIS POR MARCA
-- ============================================================================
-- Objetivo: ranquear marcas com volume de itens elegíveis para campanhas
SELECT
    p.marca,
    COUNT(DISTINCT p.prdt_key) AS total_produtos,
    SUM(CASE WHEN p.is_promotable THEN 1 ELSE 0 END) AS produtos_promoviveis,
    SUM(CASE WHEN p.is_promotable THEN COALESCE(f.receita_estimada, 0) ELSE 0 END) AS receita_promovivel,
    ROUND(AVG(f.rating), 2) AS rating_medio,
    SUM(COALESCE(f.unidades_vendidas, 0)) AS unidades_total
FROM gold.dim_prdt p
LEFT JOIN gold.ft_vnd f ON p.prdt_key = f.prdt_key
GROUP BY p.marca
HAVING COUNT(DISTINCT p.prdt_key) >= 5
ORDER BY receita_promovivel DESC
LIMIT 10;

-- ============================================================================
-- 7. DATAS CAMPEÃS DE RECEITA POR ANO
-- ============================================================================
-- Objetivo: destacar dias de maior faturamento em cada ano
WITH diario AS (
    SELECT
        t.data,
        EXTRACT(YEAR FROM t.data) AS ano,
        t.nome_dia_semana,
        SUM(f.receita_estimada) AS receita_total,
        SUM(f.unidades_vendidas) AS unidades_total,
        AVG(f.rating) AS rating_medio
    FROM gold.ft_vnd f
    JOIN gold.dim_tmp t ON f.tmp_key = t.tmp_key
    GROUP BY t.data, t.nome_dia_semana
),
ranked AS (
    SELECT
        d.*,
        ROW_NUMBER() OVER (PARTITION BY ano ORDER BY receita_total DESC) AS pos_receita,
        SUM(receita_total) OVER (PARTITION BY ano) AS receita_ano
    FROM diario d
)
SELECT
    ano,
    data,
    nome_dia_semana,
    receita_total,
    ROUND(100.0 * receita_total / NULLIF(receita_ano, 0), 2) AS pct_receita_ano,
    unidades_total,
    ROUND(rating_medio, 2) AS rating_medio
FROM ranked
WHERE pos_receita <= 10
ORDER BY ano, pos_receita;

-- ============================================================================
-- 8. ORIGEM DO PREÇO USADA NAS VENDAS
-- ============================================================================
-- Objetivo: comparar contribuição de preços originais vs imputados
WITH base AS (
    SELECT
        p.categoria,
        f.origem_preco,
        SUM(f.receita_estimada) AS receita_total,
        SUM(f.unidades_vendidas) AS unidades_total
    FROM gold.ft_vnd f
    JOIN gold.dim_prdt p ON f.prdt_key = p.prdt_key
    GROUP BY p.categoria, f.origem_preco
),
pivot AS (
    SELECT
        categoria,
        SUM(CASE WHEN origem_preco = 'original' THEN receita_total ELSE 0 END) AS receita_original,
        SUM(CASE WHEN origem_preco <> 'original' THEN receita_total ELSE 0 END) AS receita_imputada,
        SUM(CASE WHEN origem_preco = 'original' THEN unidades_total ELSE 0 END) AS unidades_originais,
        SUM(CASE WHEN origem_preco <> 'original' THEN unidades_total ELSE 0 END) AS unidades_imputadas
    FROM base
    GROUP BY categoria
),
resumo AS (
    SELECT
        categoria,
        receita_original + receita_imputada AS receita_total,
        receita_original,
        receita_imputada,
        unidades_originais,
        unidades_imputadas,
        ROUND(100.0 * receita_imputada / NULLIF(receita_original + receita_imputada, 0), 2) AS pct_receita_imputada
    FROM pivot
)
SELECT
    categoria,
    receita_total,
    receita_original,
    receita_imputada,
    pct_receita_imputada,
    unidades_originais,
    unidades_imputadas
FROM resumo
ORDER BY receita_total DESC
LIMIT 15;

-- ============================================================================
-- 9. IMPACTO DE DISPONIBILIDADE E BADGES
-- ============================================================================
-- Objetivo: comparar combinações de disponibilidade, badges e patrocínio
WITH base AS (
    SELECT
        CASE WHEN p.disponivel_compra THEN 'Disponível' ELSE 'Indisponível' END AS disponibilidade,
        CASE WHEN p.best_seller_badge THEN 'Com best seller' ELSE 'Sem best seller' END AS best_seller,
        CASE WHEN p.sponsored_badge THEN 'Patrocinado' ELSE 'Não patrocinado' END AS patrocinado,
        SUM(f.receita_estimada) AS receita_total,
        SUM(f.unidades_vendidas) AS unidades_total,
        COUNT(DISTINCT p.prdt_key) AS produtos
    FROM gold.ft_vnd f
    JOIN gold.dim_prdt p ON f.prdt_key = p.prdt_key
    GROUP BY 1, 2, 3
),
totais AS (
    SELECT SUM(receita_total) AS receita_geral FROM base
)
SELECT
    disponibilidade,
    best_seller,
    patrocinado,
    receita_total,
    ROUND(100.0 * receita_total / NULLIF(t.receita_geral, 0), 2) AS pct_receita,
    unidades_total,
    produtos
FROM base
CROSS JOIN totais t
ORDER BY receita_total DESC;

-- ============================================================================
-- 10. TOP 20 PRODUTOS POR RECEITA
-- ============================================================================
SELECT
    p.asin,
    p.titulo,
    p.marca,
    p.categoria,
    p.faixa_preco,
    SUM(f.receita_estimada) AS receita_total,
    SUM(f.unidades_vendidas) AS unidades_vendidas,
    ROUND(AVG(f.rating), 2) AS rating_medio,
    ROUND(AVG(f.quality_score), 2) AS quality_score,
    p.best_seller_badge,
    p.sponsored_badge
FROM gold.ft_vnd f
JOIN gold.dim_prdt p ON f.prdt_key = p.prdt_key
GROUP BY p.asin, p.titulo, p.marca, p.categoria, p.faixa_preco, 
         p.best_seller_badge, p.sponsored_badge
ORDER BY receita_total DESC
LIMIT 20;

-- ============================================================================
-- FIM DAS CONSULTAS
-- ============================================================================
