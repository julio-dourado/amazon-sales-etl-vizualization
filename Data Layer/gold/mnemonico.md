# Dicionario de Mnemonicos - Gold Layer

Este documento define todas as abreviacoes e convencoes de nomenclatura utilizadas no Star Schema da camada Gold.

---

## 1. Abreviacoes de Tabelas

| Abreviacao | Significado | Tabela Completa |
|------------|-------------|-----------------|
| `prdt` | **Pr**o**d**u**t**o | `dim_prdt` |
| `tmp` | **T**e**mp**o | `dim_tmp` |
| `cat` | **Cat**egoria | `dim_cat` |
| `vnd` | **V**e**nd**as | `ft_vnd` |

---

## 2. Prefixos de Tabelas

| Prefixo | Significado | Exemplo |
|---------|-------------|---------|
| `dim_` | **Dim**ensao (tabela dimensional) | `dim_prdt`, `dim_tmp`, `dim_cat` |
| `ft_` | **F**ac**t** (tabela fato) | `ft_vnd` |
| `vw_` | **V**ie**w** (visao) | `vw_resumo_categoria` |
| `idx_` | **Idx** (indice) | `idx_prdt_asin` |

---

## 3. Sufixos de Chaves

| Sufixo | Significado | Uso |
|--------|-------------|-----|
| `_key` | **Key** - Chave primaria surrogate | Usado nas dimensoes e fato como PK |
| `_srk` | **S**urrogate **R**eference **K**ey | Usado na fato como FK para dimensoes |

**Exemplos:**
- `prdt_key` - Chave primaria da tabela `dim_prdt`
- `prdt_srk` - Chave estrangeira na `ft_vnd` que referencia `dim_prdt(prdt_key)`

---

## 4. Abreviacoes de Colunas

| Abreviacao | Significado | Coluna Completa |
|------------|-------------|-----------------|
| `preco` | Preco | `faixa_preco`, `preco_final`, `origem_preco` |
| `eh` | E (verbo ser) | `eh_fim_semana` |
| `pct` | Percentual | `percentual_desconto` |
| `qtd` | Quantidade | - |
| `dt` | Data | - |
| `hr` | Hora | - |
| `nr` | Numero | - |
| `vlr` | Valor | - |

---

## 5. Estrutura das Tabelas

### 5.1 Dimensao Produto (`dim_prdt`)

| Coluna | Tipo | Descricao |
|--------|------|-----------|
| `prdt_key` | SERIAL | Chave primaria surrogate |
| `asin` | VARCHAR(20) | Amazon Standard Identification Number |
| `titulo` | TEXT | Nome completo do produto |
| `marca` | VARCHAR(100) | Marca do fabricante |
| `categoria` | VARCHAR(50) | Categoria do produto |
| `faixa_preco` | VARCHAR(30) | Faixa de preco (Budget, Economy, Premium, etc.) |
| `best_seller_badge` | BOOLEAN | Possui selo de mais vendido |
| `sponsored_badge` | BOOLEAN | Produto patrocinado |
| `is_promotable` | BOOLEAN | Elegivel para promocao |
| `disponivel_compra` | BOOLEAN | Disponivel no buy box |
| `data_atualizacao` | TIMESTAMP | Data da ultima atualizacao |

### 5.2 Dimensao Tempo (`dim_tmp`)

| Coluna | Tipo | Descricao |
|--------|------|-----------|
| `tmp_key` | SERIAL | Chave primaria surrogate |
| `data` | DATE | Data (YYYY-MM-DD) |
| `ano` | INTEGER | Ano (ex: 2025) |
| `mes` | INTEGER | Mes (1-12) |
| `dia` | INTEGER | Dia do mes (1-31) |
| `dia_semana` | INTEGER | Dia da semana (0=Segunda, 6=Domingo) |
| `nome_dia_semana` | VARCHAR(10) | Nome do dia (Monday, Tuesday, etc.) |
| `trimestre` | INTEGER | Trimestre (1-4) |
| `semana_ano` | INTEGER | Semana do ano (1-52) |
| `eh_fim_semana` | BOOLEAN | Indica se e sabado ou domingo |
| `mes_ano` | VARCHAR(7) | Mes/Ano no formato YYYY-MM |
| `ano_trimestre` | VARCHAR(7) | Ano/Trimestre no formato YYYY-QN |

### 5.3 Dimensao Categoria (`dim_cat`)

| Coluna | Tipo | Descricao |
|--------|------|-----------|
| `cat_key` | SERIAL | Chave primaria surrogate |
| `categoria` | VARCHAR(50) | Nome da categoria |
| `tipo_produto` | VARCHAR(50) | Tipo de produto |
| `segmento` | VARCHAR(50) | Segmento de mercado |

### 5.4 Fato Vendas (`ft_vnd`)

| Coluna | Tipo | Descricao |
|--------|------|-----------|
| `vnd_key` | SERIAL | Chave primaria surrogate |
| `prdt_srk` | INTEGER | FK para dim_prdt(prdt_key) |
| `tmp_srk` | INTEGER | FK para dim_tmp(tmp_key) |
| `cat_srk` | INTEGER | FK para dim_cat(cat_key) |
| `unidades_vendidas` | INTEGER | Quantidade vendida no ultimo mes |
| `receita_estimada` | NUMERIC(12,2) | Receita = preco x unidades |
| `preco_final` | NUMERIC(10,2) | Preco de venda |
| `rating` | NUMERIC(3,2) | Avaliacao media (0-5) |
| `total_reviews` | INTEGER | Total de avaliacoes |
| `quality_score` | NUMERIC(5,2) | Score de qualidade (0-100) |
| `percentual_desconto` | NUMERIC(5,2) | Percentual de desconto aplicado |
| `hora_coleta` | INTEGER | Hora da coleta (0-23) |
| `data_coleta` | TIMESTAMP | Data e hora da coleta |
| `origem_preco` | VARCHAR(30) | Origem do preco (original, imputado, etc.) |

---

## 6. Views Analiticas

| View | Descricao |
|------|-----------|
| `vw_resumo_categoria` | Agregacao de metricas por categoria/segmento |
| `vw_top_produtos` | Top 100 produtos por receita |
| `vw_performance_temporal` | Performance agregada por periodo |

---

## 7. Convencoes Gerais

1. **Nomes em portugues** (sem acentos) para colunas de negocio
2. **Nomes em ingles** para termos tecnicos (key, badge, score, rating)
3. **Snake_case** para todos os identificadores
4. **Chaves surrogate** sempre com sufixo `_key` ou `_srk`
5. **Booleanos** prefixados com `eh_` ou `is_` ou `has_`
6. **Datas** prefixadas com `data_` ou sufixadas com `_data`
7. **Valores monetarios** como NUMERIC com precisao adequada

---

## 8. Diagrama do Star Schema

```
                    +---------------+
                    |   dim_tmp     |
                    +---------------+
                    | tmp_key (PK)  |
                    | data          |
                    | ano, mes, dia |
                    | ...           |
                    +-------+-------+
                            |
                            | tmp_srk
                            v
+---------------+    +---------------+    +---------------+
|   dim_prdt    |    |    ft_vnd     |    |   dim_cat     |
+---------------+    +---------------+    +---------------+
| prdt_key (PK) |<---| prdt_srk (FK) |    | cat_key (PK)  |
| asin          |    | tmp_srk (FK)  |--->| categoria     |
| titulo        |    | cat_srk (FK)  |    | segmento      |
| marca         |    |---------------|    +---------------+
| categoria     |    | unidades_vnd  |
| faixa_preco   |    | receita_est   |
| ...           |    | preco_final   |
+---------------+    | rating        |
                     | quality_score |
                     | ...           |
                     +---------------+
```

---

*Documento gerado para o projeto Amazon Sales ETL & Visualization*
