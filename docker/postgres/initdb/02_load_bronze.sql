SET client_encoding TO 'UTF8';

COPY silver.amazon_products_sales_curated
FROM '/data/bronze/amazon_products_sales_data_uncleaned.csv'
WITH (
    FORMAT csv,
    HEADER true,
    NULL '',
    QUOTE '"',
    ESCAPE '"'
);
