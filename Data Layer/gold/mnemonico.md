## Abreviações de Tabelas

| Abreviação | Significado | Tabela |
|------------|-------------|--------|
| `prdt` | **Pr**o**d**u**t**o | `dim_prdt` |
| `tmp` | **T**e**mp**o | `dim_tmp` |
| `cat` | **Cat**egoria | `dim_cat` |
| `vnd` | **V**e**nd**as | `ft_vnd` |

## Sufixos de Chaves

| Sufixo | Significado | Uso |
|--------|-------------|-----|
| `_key` | Primary Key (chave primária) | Usado nas tabelas dimensão e fato |
| `_srk` | **S**urrogate **R**eference **K**ey (chave estrangeira) | Usado apenas na fato para referenciar dimensões |

**Exemplo**:
- `prdt_key` → Primary key da tabela `dim_prdt`
- `prdt_srk` → Foreign key na tabela `ft_vnd` que referencia `dim_prdt(prdt_key)`

## Prefixos

| Prefixo | Significado |
|---------|-------------|
| `dim_` | **Dim**ensão (tabela dimensional) |
| `ft_` | **F**ac**t** (tabela fato) |
| `vw_` | **V**ie**w** (view/visão) |
| `idx_` | **Idx** (índice) |
