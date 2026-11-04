CREATE OR REPLACE VIEW transaction_summary AS
SELECT DISTINCT ON (transaction_id)
    transaction_id, store_id, store_name, store_country, store_city, store_type,
    purchase_timestamp, payment_method, currency,
    total_amount, total_quantity_sold, discount_applied, return_status
FROM exploded_products
ORDER BY transaction_id, line_id;