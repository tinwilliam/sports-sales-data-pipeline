-- ============ A. store_sales_summary ============

-- name: store_1 | Top 5 des magasins par chiffre d'affaires (devises locales)
SELECT store_id, store_name, store_country, store_city, total_sales_amount
FROM store_sales_summary
ORDER BY total_sales_amount DESC
LIMIT 5;

-- name: store_2 | Ville avec le chiffre d'affaires cumule le plus eleve
SELECT store_city, store_country, SUM(total_sales_amount) AS total_sales
FROM store_sales_summary
GROUP BY store_city, store_country
ORDER BY total_sales DESC
LIMIT 1;

-- name: store_3 | Nombre de magasins par pays
SELECT store_country,
       COUNT(*)                 AS nb_magasins_combinaisons,
       COUNT(DISTINCT store_id) AS nb_store_id_distincts
FROM store_sales_summary
GROUP BY store_country
ORDER BY nb_magasins_combinaisons DESC, store_country;

-- name: store_4 | Quantite totale de produits vendus par pays
SELECT store_country, SUM(total_quantity_sold) AS total_quantity
FROM store_sales_summary
GROUP BY store_country
ORDER BY total_quantity DESC;

-- ============ B. daily_sales_country_currency ============

-- name: daily_1 | Chiffre d'affaires total en CAD
SELECT currency, SUM(daily_total_sales) AS total_sales
FROM daily_sales_country_currency
WHERE currency = 'CAD'
GROUP BY currency;

-- name: daily_2 | Nombre de jours a plus de 6000 EUR de ventes en France
SELECT COUNT(*) AS nb_jours
FROM daily_sales_country_currency
WHERE store_country = 'France'
  AND currency = 'EUR'
  AND daily_total_sales > 6000;

-- name: daily_3 | Total des ventes par devise
SELECT currency, SUM(daily_total_sales) AS total_sales
FROM daily_sales_country_currency
GROUP BY currency
ORDER BY total_sales DESC;

-- name: daily_4 | Valeur moyenne d'une transaction par pays
SELECT store_country,
       ROUND(SUM(daily_total_sales) / NULLIF(SUM(number_of_transactions), 0), 2) AS average_transaction_value
FROM daily_sales_country_currency
GROUP BY store_country
ORDER BY average_transaction_value DESC;

-- ============ C. payment_method_analysis ============

-- name: payment_1 | Methode de paiement generant le plus de ventes
SELECT payment_method, total_sales_amount
FROM payment_method_analysis
ORDER BY total_sales_amount DESC
LIMIT 1;

-- name: payment_2 | Methodes avec un taux de retour superieur a 10 %
SELECT payment_method, return_rate
FROM payment_method_analysis
WHERE return_rate > 10
ORDER BY return_rate DESC;

-- name: payment_3 | Methode associee au plus grand nombre d'articles en moyenne
SELECT payment_method, average_items_per_transaction
FROM payment_method_analysis
ORDER BY average_items_per_transaction DESC
LIMIT 1;

-- name: payment_4 | Classement des methodes par volume de transactions
SELECT RANK() OVER (ORDER BY total_transactions DESC) AS rang,
       payment_method, total_transactions
FROM payment_method_analysis
ORDER BY rang;