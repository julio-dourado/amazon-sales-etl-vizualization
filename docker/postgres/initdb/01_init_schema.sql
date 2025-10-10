CREATE SCHEMA IF NOT EXISTS silver;

CREATE TABLE IF NOT EXISTS silver.amazon_products_sales_curated (
    title TEXT,
    rating TEXT,
    number_of_reviews TEXT,
    bought_in_last_month TEXT,
    "current/discounted_price" TEXT,
    price_on_variant TEXT,
    listed_price TEXT,
    is_best_seller TEXT,
    is_sponsored TEXT,
    is_couponed TEXT,
    buy_box_availability TEXT,
    delivery_details TEXT,
    sustainability_badges TEXT,
    image_url TEXT,
    product_url TEXT,
    collected_at TEXT
);
