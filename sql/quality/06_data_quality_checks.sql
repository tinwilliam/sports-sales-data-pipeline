DO $$
DECLARE
    n_rows     INTEGER;
    n_tx       INTEGER;
    n_summary  INTEGER;
    n_invalid  INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT transaction_id)
      INTO n_rows, n_tx FROM exploded_products;

    IF n_tx = 0 THEN
        RAISE EXCEPTION 'QUALITY: exploded_products est vide';
    END IF;

    SELECT COUNT(*) INTO n_invalid
    FROM exploded_products
    WHERE transaction_id IS NULL OR product_id IS NULL
       OR payment_method IS NULL OR currency IS NULL
       OR quantity <= 0 OR price < 0;

    IF n_invalid > 0 THEN
        RAISE EXCEPTION 'QUALITY: % lignes invalides', n_invalid;
    END IF;

    SELECT COUNT(*) INTO n_summary FROM transaction_summary;

    IF n_summary <> n_tx THEN
        RAISE EXCEPTION 'QUALITY: la vue contient % lignes pour % transactions', n_summary, n_tx;
    END IF;

    RAISE NOTICE 'QUALITY OK : % lignes, % transactions', n_rows, n_tx;
END $$;