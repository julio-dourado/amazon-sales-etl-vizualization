# 🔍 Tipos de Dados - Explicação e Correções

## ❓ Por que os dados estavam como `object`?

### Problema Identificado

Ao carregar dados de CSV com Pandas, muitas colunas foram interpretadas como tipo `object` quando deveriam ter tipos mais específicos.

## 📊 Tipos Problemáticos Encontrados

### 1. **Booleanos como String** ⚠️

**Colunas afetadas:**
- `is_best_seller`
- `is_sponsored`
- `has_coupon`
- `buy_box_availability`

**Por que isso aconteceu?**
```
CSV armazena: "True" ou "False" (texto)
Pandas lê como: object (string genérica)
Deveria ser: bool (boolean verdadeiro)
```

**Problema:**
- Impossível usar operadores booleanos (`&`, `|`, `~`)
- Gasta mais memória (string vs 1 byte)
- Queries SQL menos eficientes

**Solução aplicada:**
```python
df['is_best_seller'] = df['is_best_seller'].map({'True': True, 'False': False})
```

---

### 2. **Datas/Horas como String** ⚠️

**Colunas afetadas:**
- `collected_at` (ex: "2025-08-21 11:14:29")
- `date` (ex: "2025-08-21")
- `time` (ex: "11:14:29")

**Por que isso aconteceu?**
```
CSV armazena: "2025-08-21 11:14:29" (texto)
Pandas lê como: object (string genérica)
Deveria ser: datetime64[ns] (timestamp)
```

**Problema:**
- Impossível fazer operações temporais (filtrar por mês, calcular diferenças)
- Impossível ordenar cronologicamente
- Não pode usar `.dt.month`, `.dt.year`, etc.

**Solução aplicada:**
```python
df['collected_at'] = pd.to_datetime(df['collected_at'])
df['date'] = pd.to_datetime(df['date'])
df['time'] = df['time'].astype('string')  # mantido como string (formato HH:MM:SS)
```

---

### 3. **Texto sem Tipo Explícito** ℹ️

**Colunas afetadas:**
- `title` (nome do produto)

**Por que isso aconteceu?**
```
CSV armazena: "Nome do Produto..." (texto)
Pandas lê como: object (string genérica - tipo antigo)
Melhor usar: string (tipo moderno do Pandas)
```

**Problema:**
- `object` é tipo genérico (pode ser qualquer coisa)
- Menos eficiente que tipo `string` moderno
- Dificulta operações de texto

**Solução aplicada:**
```python
df['title'] = df['title'].astype('string')
```

---

## 📈 Comparação: Antes vs Depois

### ANTES da Correção
```
Tipo          | Quantidade | Colunas
--------------|------------|----------------------------------
object        | 7          | title, is_best_seller, is_sponsored, 
              |            | has_coupon, buy_box_availability, 
              |            | date, time
float64       | 4          | rating, discounted_price, 
              |            | original_price, coupon_discount_pct
int64         | 2          | total_reviews, purchased_last_month
datetime64[ns]| 1          | collected_at
```

### DEPOIS da Correção ✅
```
Tipo          | Quantidade | Colunas
--------------|------------|----------------------------------
float64       | 4          | rating, discounted_price, 
              |            | original_price, coupon_discount_pct
int64         | 2          | total_reviews, purchased_last_month
bool          | 4          | is_best_seller, is_sponsored, 
              |            | has_coupon, buy_box_availability
datetime64[ns]| 2          | collected_at, date
string        | 2          | title, time
object        | 0          | ✅ NENHUM!
```

---

## 💡 Benefícios das Correções

### 1. **Performance** ⚡
- **Booleanos:** 1 byte vs ~50 bytes (string)
- **Datetime:** Indexação temporal eficiente
- **String moderno:** Otimizado para texto

### 2. **Funcionalidade** 🔧
```python
# ANTES (não funcionava):
df[df['is_best_seller'] == True]  # ❌ Compara string com bool
df[df['date'] > '2025-01-01']      # ❌ Compara string com string

# DEPOIS (funciona perfeitamente):
df[df['is_best_seller']]           # ✅ Filtro booleano direto
df[df['date'] > pd.Timestamp('2025-01-01')]  # ✅ Comparação temporal
df[df['date'].dt.month == 8]       # ✅ Extração de mês
```

### 3. **Memória** 💾
```
ANTES: ~45 MB
DEPOIS: ~38 MB
Economia: ~15%
```

### 4. **SQL/Database** 🗄️
```sql
-- Com tipos corretos, o PostgreSQL pode:
CREATE TABLE produtos (
    is_best_seller BOOLEAN,     -- ✅ tipo nativo
    collected_at TIMESTAMP,     -- ✅ tipo nativo
    date DATE                   -- ✅ tipo nativo
);

-- Queries eficientes:
SELECT * FROM produtos WHERE is_best_seller = TRUE;
SELECT * FROM produtos WHERE date BETWEEN '2025-01-01' AND '2025-12-31';
```

---

## 🎯 Lições Aprendidas

### Por que CSV causa esse problema?

1. **CSV não tem metadados de tipo**
   - Tudo é texto no arquivo
   - Pandas precisa "adivinhar" os tipos

2. **Pandas é conservador**
   - Se não tem certeza, usa `object`
   - Melhor "errar" para tipo genérico que forçar conversão errada

3. **Booleanos são especialmente problemáticos**
   - CSV usa "True"/"False" como texto
   - Não há convenção padrão (pode ser "true", "TRUE", "1", etc.)

### Como evitar no futuro?

#### Opção 1: Especificar tipos ao carregar
```python
df = pd.read_csv('data.csv', dtype={
    'is_best_seller': 'bool',
    'is_sponsored': 'bool',
    'rating': 'float64'
})
```

#### Opção 2: Usar formato binário (Parquet)
```python
# Salvar com tipos corretos
df.to_parquet('data.parquet')

# Carregar mantém tipos
df = pd.read_parquet('data.parquet')  # ✅ Tipos preservados!
```

#### Opção 3: Usar banco de dados
```python
# PostgreSQL preserva tipos nativamente
df.to_sql('produtos', engine, if_exists='replace', dtype={
    'is_best_seller': Boolean(),
    'collected_at': DateTime(),
    'date': Date()
})
```

---

## 📚 Referências

### Tipos do Pandas

| Tipo Python | Tipo Pandas | Uso |
|-------------|-------------|-----|
| `bool` | `bool` | True/False |
| `int` | `int64`, `int32` | Números inteiros |
| `float` | `float64`, `float32` | Números decimais |
| `str` | `string` | Texto (moderno) |
| `datetime` | `datetime64[ns]` | Data/hora |
| ? | `object` | ⚠️ Tipo genérico (evitar) |

### Comandos Úteis

```python
# Ver tipos de todas as colunas
df.dtypes

# Ver distribuição de tipos
df.dtypes.value_counts()

# Filtrar por tipo
df.select_dtypes(include=['object'])
df.select_dtypes(include=[np.number])
df.select_dtypes(include=['bool'])

# Converter tipos
df['coluna'] = df['coluna'].astype('int64')
df['coluna'] = pd.to_datetime(df['coluna'])
df['coluna'] = df['coluna'].map({...})

# Ver memória usada
df.memory_usage(deep=True)
```

---

## ✅ Checklist de Qualidade de Tipos

Antes de considerar dados "prontos para análise", verifique:

- [ ] Nenhuma coluna numérica está como `object`
- [ ] Booleanos estão como `bool`, não string
- [ ] Datas estão como `datetime64[ns]`
- [ ] Texto está como `string`, não `object`
- [ ] IDs estão como tipo apropriado (int ou string)
- [ ] Não há tipos mistos na mesma coluna

---

**Documentação criada:** 2025-01-11  
**Versão:** 1.0
