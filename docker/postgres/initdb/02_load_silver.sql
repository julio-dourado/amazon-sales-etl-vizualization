SET client_encoding TO 'UTF8';

COPY silver.amazon_products_sales_curated
FROM '/data/silver/amazon_products_cleaned.csv'
WITH (
    FORMAT csv,
    HEADER true,
    NULL '',
    QUOTE '"',
    ESCAPE '"'
);
