SET client_encoding TO 'UTF8';

COPY silver.amazon_products_sales_curated (
    title,
    rating,
    number_of_reviews,
    bought_in_last_month,
    "current/discounted_price",
    price_on_variant,
    listed_price,
    is_best_seller,
    is_sponsored,
    is_couponed,
    buy_box_availability,
    delivery_details,
    sustainability_badges,
    image_url,
    product_url,
    collected_at
)
FROM '/data/silver/amazon_products_cleaned.csv'
WITH (
    FORMAT csv,
    HEADER true,
    NULL '',
    QUOTE '"',
    ESCAPE '"'
);
