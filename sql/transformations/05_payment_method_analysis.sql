-- ==================================================
--  5. TABLE PAYMENT_METHOD_ANALYSIS
-- Granularite : moyen de paiement
-- ==================================================

TRUNCATE payment_method_analysis;

INSERT INTO payment_method_analysis
SELECT payment_method,
       COUNT(*),
       SUM(total_amount),
       ROUND(AVG(discount_applied), 2),
       ROUND(100.0 * COUNT(*) FILTER (WHERE return_status = 'Returned') / COUNT(*), 2),
       ROUND(AVG(total_quantity_sold), 2)
FROM transaction_summary
GROUP BY payment_method;
