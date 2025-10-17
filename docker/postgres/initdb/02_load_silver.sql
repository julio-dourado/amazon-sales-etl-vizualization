SET client_encoding TO 'UTF8';

COPY silver.amazon_products_sales_curated (
    title,
    rating,
    total_reviews,
    purchased_last_month,
    discounted_price,
    original_price,
    is_best_seller,
    is_sponsored,
    has_coupon,
    buy_box_availability,
    date,
    time,
    coupon_discount_pct
)
FROM '/data/silver/amazon_products_cleaned.csv'
WITH (
    FORMAT csv,
    HEADER true,
    NULL '',
    QUOTE '"',
    ESCAPE '"'
);
