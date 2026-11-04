-- ==================================================
-- 4. VUE DAILY_SALES_COUNTRY_CURRENCY
-- Granularite : jour + pays + devise
-- ==================================================

TRUNCATE daily_sales_country_currency;

INSERT INTO daily_sales_country_currency
SELECT purchase_timestamp::DATE, store_country, currency,
       SUM(total_amount),
       COUNT(*),
       ROUND(AVG(total_amount), 2)
FROM transaction_summary
GROUP BY purchase_timestamp::DATE, store_country, currency;