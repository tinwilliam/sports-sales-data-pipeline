-- Table intermédiaire : 1 ligne par produit vendu
CREATE TABLE IF NOT EXISTS exploded_products (
    line_id             BIGSERIAL PRIMARY KEY,
    transaction_id      TEXT          NOT NULL,
    store_id            TEXT          NOT NULL,
    store_name          TEXT,
    store_country       TEXT,
    store_city          TEXT,
    store_type          TEXT,
    purchase_timestamp  TIMESTAMP     NOT NULL,
    payment_method      TEXT,
    currency            TEXT,
    total_amount        NUMERIC(14,2),
    total_quantity_sold INTEGER,
    discount_applied    NUMERIC(14,2),
    promo_applied       BOOLEAN,
    promo_code          TEXT,
    return_status       TEXT,
    product_id          TEXT          NOT NULL,
    product_name        TEXT,
    products_category   TEXT,
    quantity            INTEGER,
    price               NUMERIC(14,2)
);

CREATE INDEX IF NOT EXISTS idx_ep_transaction ON exploded_products (transaction_id);
CREATE INDEX IF NOT EXISTS idx_ep_store       ON exploded_products (store_id);
CREATE INDEX IF NOT EXISTS idx_ep_timestamp   ON exploded_products (purchase_timestamp);

-- Table 1 : granularité = 1 magasin
CREATE TABLE IF NOT EXISTS store_sales_summary (
    store_id            TEXT,
    store_name          TEXT,
    store_country       TEXT,
    store_city          TEXT,
    store_type          TEXT,
    total_sales_amount  NUMERIC(16,2),
    total_quantity_sold INTEGER
);

-- Table 2 : granularité = jour / pays / devise
CREATE TABLE IF NOT EXISTS daily_sales_country_currency (
    purchase_date             DATE,
    store_country             TEXT,
    currency                  TEXT,
    daily_total_sales         NUMERIC(16,2),
    number_of_transactions    INTEGER,
    average_transaction_value NUMERIC(14,2),
    PRIMARY KEY (purchase_date, store_country, currency)
);

-- Table 3 : granularité = moyen de paiement
CREATE TABLE IF NOT EXISTS payment_method_analysis (
    payment_method                TEXT PRIMARY KEY,
    total_transactions            INTEGER,
    total_sales_amount            NUMERIC(16,2),
    average_discount              NUMERIC(14,2),
    return_rate                   NUMERIC(6,2),
    average_items_per_transaction NUMERIC(8,2)
);
