#!/usr/bin/env python3
"""
Script para popular o banco de dados PostgreSQL com dados do CSV Silver
Utiliza o DDL fornecido para criar a tabela PRODUCT e carregar os dados
"""

import os
import sys
import psycopg2
import pandas as pd
from pathlib import Path

DB_CONFIG = {
    'host': os.getenv('POSTGRES_HOST', 'localhost'),
    'port': os.getenv('POSTGRES_PORT', '5432'),
    'database': os.getenv('POSTGRES_DB', 'amazon_sales'),
    'user': os.getenv('POSTGRES_USER', 'medallion'),
    'password': os.getenv('POSTGRES_PASSWORD', 'medallion')
}

BASE_DIR = Path(__file__).parent
CSV_PATH = BASE_DIR / 'data-lake' / 'silver' / 'data' / 'amazon_products_cleaned.csv'

DDL_CREATE_TABLE = """
DROP TABLE IF EXISTS silver.product CASCADE;

CREATE TABLE silver.product (
    id BIGINT PRIMARY KEY,
    rating DECIMAL(3,2),
    purchased_last_month INTEGER,
    discounted_price DECIMAL(10,2),
    is_best_seller BOOLEAN,
    total_reviews INTEGER,
    is_sponsored BOOLEAN,
    has_coupon BOOLEAN,
    buy_box_availability BOOLEAN,
    title TEXT,
    original_price DECIMAL(10,2),
    date DATE,
    time TIME,
    coupon_discount_pct DECIMAL(5,2)
);
"""


def connect_db():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        print(f"✅ Conectado ao banco de dados: {DB_CONFIG['database']}")
        return conn
    except Exception as e:
        print(f"❌ Erro ao conectar ao banco de dados: {e}")
        sys.exit(1)


def create_schema(conn):
    """Cria o schema silver se não existir"""
    try:
        with conn.cursor() as cursor:
            cursor.execute("CREATE SCHEMA IF NOT EXISTS silver;")
            conn.commit()
            print("✅ Schema 'silver' criado/verificado")
    except Exception as e:
        print(f"❌ Erro ao criar schema: {e}")
        conn.rollback()
        raise


def create_table(conn):
    """Cria a tabela PRODUCT usando o DDL fornecido"""
    try:
        with conn.cursor() as cursor:
            cursor.execute(DDL_CREATE_TABLE)
            conn.commit()
            print("✅ Tabela 'silver.product' criada com sucesso")
    except Exception as e:
        print(f"❌ Erro ao criar tabela: {e}")
        conn.rollback()
        raise


def convert_boolean(value):
    """Converte valores para boolean"""
    if pd.isna(value):
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ('true', '1', 'yes', 't')
    return bool(value)


def load_csv_data():
    """Carrega e processa os dados do CSV"""
    try:
        print(f"📂 Carregando dados de: {CSV_PATH}")
        
        if not CSV_PATH.exists():
            raise FileNotFoundError(f"Arquivo CSV não encontrado: {CSV_PATH}")
        
        # Ler CSV
        df = pd.read_csv(CSV_PATH)
        print(f"✅ CSV carregado: {len(df)} linhas")
        
        # Adicionar ID sequencial se não existir
        if 'id' not in df.columns:
            df['id'] = range(1, len(df) + 1)
        
        df_processed = pd.DataFrame({
            'id': df['id'],
            'rating': pd.to_numeric(df['rating'], errors='coerce'),
            'total_reviews': pd.to_numeric(df['total_reviews'], errors='coerce').astype('Int64'),
            'purchased_last_month': pd.to_numeric(df['purchased_last_month'], errors='coerce').astype('Int64'),
            'discounted_price': pd.to_numeric(df['discounted_price'], errors='coerce'),
            'original_price': pd.to_numeric(df['original_price'], errors='coerce'),
            'is_best_seller': df['is_best_seller'].apply(convert_boolean),
            'is_sponsored': df['is_sponsored'].apply(convert_boolean),
            'has_coupon': df['has_coupon'].apply(convert_boolean),
            'buy_box_availability': df['buy_box_availability'].apply(
                lambda x: None if pd.isna(x) else (True if str(x).lower() in ['available', 'true', '1'] else False)
            ),
            'title': df['title'].astype(str),
            'date': pd.to_datetime(df['date'], errors='coerce').dt.date,
            'time': pd.to_datetime(df['time'], format='%H:%M:%S', errors='coerce').dt.time,
            'coupon_discount_pct': pd.to_numeric(df['coupon_discount_pct'], errors='coerce')
        })
        
        # Remover linhas completamente vazias
        df_processed = df_processed.dropna(how='all')
        
        print(f"✅ Dados processados: {len(df_processed)} linhas válidas")
        return df_processed
        
    except Exception as e:
        print(f"❌ Erro ao carregar CSV: {e}")
        raise


def insert_data(conn, df):
    """Insere dados no banco usando batch insert"""
    try:
        with conn.cursor() as cursor:
            print(f"📥 Inserindo {len(df)} registros...")
            
            # Preparar query de insert
            insert_query = """
                INSERT INTO silver.product (
                    id, rating, total_reviews, purchased_last_month,
                    discounted_price, original_price, is_best_seller,
                    is_sponsored, has_coupon, buy_box_availability,
                    title, date, time, coupon_discount_pct
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
            """
            
            # Converter DataFrame para lista de tuplas
            records = []
            for _, row in df.iterrows():
                record = (
                    int(row['id']) if pd.notna(row['id']) else None,
                    float(row['rating']) if pd.notna(row['rating']) else None,
                    int(row['total_reviews']) if pd.notna(row['total_reviews']) else None,
                    int(row['purchased_last_month']) if pd.notna(row['purchased_last_month']) else None,
                    float(row['discounted_price']) if pd.notna(row['discounted_price']) else None,
                    float(row['original_price']) if pd.notna(row['original_price']) else None,
                    row['is_best_seller'],
                    row['is_sponsored'],
                    row['has_coupon'],
                    row['buy_box_availability'],
                    str(row['title']) if pd.notna(row['title']) else None,
                    row['date'] if pd.notna(row['date']) else None,
                    row['time'] if pd.notna(row['time']) else None,
                    float(row['coupon_discount_pct']) if pd.notna(row['coupon_discount_pct']) else None
                )
                records.append(record)
            
            # Executar batch insert
            cursor.executemany(insert_query, records)
            conn.commit()
            
            print(f"✅ {cursor.rowcount} registros inseridos com sucesso!")
            
    except Exception as e:
        print(f"❌ Erro ao inserir dados: {e}")
        conn.rollback()
        raise


def verify_data(conn):
    """Verifica os dados inseridos"""
    try:
        with conn.cursor() as cursor:
            # Contagem total
            cursor.execute("SELECT COUNT(*) FROM silver.product")
            total = cursor.fetchone()[0]
            print(f"\n📊 Estatísticas da tabela silver.product:")
            print(f"   Total de registros: {total}")
            
            # Estatísticas
            cursor.execute("""
                SELECT 
                    ROUND(AVG(rating), 2) as avg_rating,
                    ROUND(AVG(discounted_price), 2) as avg_price,
                    COUNT(*) FILTER (WHERE is_best_seller = TRUE) as best_sellers,
                    COUNT(*) FILTER (WHERE is_sponsored = TRUE) as sponsored,
                    COUNT(*) FILTER (WHERE has_coupon = TRUE) as with_coupon
                FROM silver.product
            """)
            stats = cursor.fetchone()
            print(f"   Rating médio: {stats[0]}")
            print(f"   Preço médio: R$ {stats[1]}")
            print(f"   Best Sellers: {stats[2]}")
            print(f"   Patrocinados: {stats[3]}")
            print(f"   Com cupom: {stats[4]}")
            
            # Exemplo de produtos
            print(f"\n📋 Exemplo de produtos (top 3):")
            cursor.execute("""
                SELECT id, title, rating, discounted_price, is_best_seller
                FROM silver.product
                ORDER BY rating DESC, total_reviews DESC
                LIMIT 3
            """)
            
            for row in cursor.fetchall():
                best_seller = "⭐" if row[4] else ""
                print(f"   {best_seller} ID {row[0]}: {row[1][:50]}... | Rating: {row[2]} | R$ {row[3]}")
                
    except Exception as e:
        print(f"❌ Erro ao verificar dados: {e}")


def main():
    """Função principal"""
    print("=" * 80)
    print("🚀 Script de População do Banco de Dados - Amazon Sales")
    print("=" * 80)
    
    try:
        # 1. Conectar ao banco
        conn = connect_db()
        
        # 2. Criar schema
        create_schema(conn)
        
        # 3. Criar tabela
        create_table(conn)
        
        # 4. Carregar dados do CSV
        df = load_csv_data()
        
        # 5. Inserir dados
        insert_data(conn, df)
        
        # 6. Verificar dados
        verify_data(conn)
        
        # 7. Fechar conexão
        conn.close()
        print("\n✅ Processo concluído com sucesso!")
        print("=" * 80)
        
    except Exception as e:
        print(f"\n❌ Erro no processo: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
