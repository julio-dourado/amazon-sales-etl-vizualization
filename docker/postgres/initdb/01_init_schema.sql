-- Criação dos schemas para arquitetura Medallion
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- Comentários nos schemas
COMMENT ON SCHEMA bronze IS 'Camada Bronze - Dados brutos sem transformação';
COMMENT ON SCHEMA silver IS 'Camada Silver - Dados limpos e validados';
COMMENT ON SCHEMA gold IS 'Camada Gold - Dados agregados e otimizados para análise';

