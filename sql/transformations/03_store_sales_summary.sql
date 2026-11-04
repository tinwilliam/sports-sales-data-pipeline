
-- ==================================================
-- 2. VUE STORE_SALES_SUMMARY
-- Granularite : un magasin
-- ==================================================
TRUNCATE store_sales_summary;

INSERT INTO store_sales_summary
SELECT store_id, store_name, store_country, store_city, store_type,
       SUM(total_amount), SUM(total_quantity_sold)
FROM transaction_summary
GROUP BY store_id, store_name, store_country, store_city, store_type;
