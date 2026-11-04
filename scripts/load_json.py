import json
import os
import sys
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_values

BASE_DIR = Path(__file__).resolve().parent.parent
JSON_PATH = Path(os.getenv("JSON_PATH", BASE_DIR / "data" / "raw" / "pos_sales_data_30k.json"))

INSERT_SQL = """
INSERT INTO exploded_products (
    transaction_id, store_id, store_name, store_country, store_city, store_type,
    purchase_timestamp, payment_method, currency, total_amount, total_quantity_sold,
    discount_applied, promo_applied, promo_code, return_status,
    product_id, product_name, products_category, quantity, price
) VALUES %s
"""


def get_connection():
    # Local : localhost:5434 (port exposé). Dans Airflow : DB_HOST=postgres_dw, DB_PORT=5432
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5434"),
        dbname=os.environ["DW_DB"],
        user=os.environ["DW_USER"],
        password=os.environ["DW_PASSWORD"],
    )


def explode(transactions):
    """Une ligne par produit. Retourne (rows, stats)."""
    rows, seen = [], set()
    stats = {"transactions_source": len(transactions), "duplicate_ids": 0,
             "no_products": 0, "qty_mismatch": 0, "amount_mismatch": 0,
             "transactions_kept": 0}

    for t in transactions:
        tid = t["transaction_id"]
        if tid in seen:
            stats["duplicate_ids"] += 1
            continue
        seen.add(tid)

        products = t.get("products") or []
        if not products:
            stats["no_products"] += 1
            continue
        stats["transactions_kept"] += 1

        # promo_code = ["yes"/"no", code ou null]
        promo = t.get("promo_code") or [None, None]
        promo_applied = str(promo[0]).lower() == "yes"
        promo_code = promo[1] if len(promo) > 1 else None

        # contrôles de cohérence (avertissements, pas d'arrêt)
        calc_qty = sum(p["quantity"] for p in products)
        calc_amount = sum(p["quantity"] * p["price"] for p in products)
        total_qty = t.get("total_quantity_sold")
        if total_qty is None:
            total_qty = calc_qty
        elif total_qty != calc_qty:
            stats["qty_mismatch"] += 1
        if t.get("total_amount") is not None and abs(calc_amount - t["total_amount"]) > 0.01:
            stats["amount_mismatch"] += 1

        for p in products:
            rows.append((
                tid, t["store_id"], t.get("store_name"), t.get("store_country"),
                t.get("store_city"), t.get("store_type"), t["purchase_timestamp"],
                t.get("payment_method"), t.get("currency"), t.get("total_amount"),
                total_qty, t.get("discount_applied", 0), promo_applied, promo_code,
                t.get("return_status"),
                p["product_id"], p.get("product_name"), p.get("products_category"),
                p["quantity"], p["price"],
            ))
    return rows, stats


def load_json_to_postgres():
    print(f"Lecture de {JSON_PATH}")
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        transactions = json.load(f)

    rows, stats = explode(transactions)
    for k, v in stats.items():
        print(f"  {k:<22}: {v}")
    print(f"  lignes explosées      : {len(rows)}")

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE exploded_products RESTART IDENTITY")  # full refresh
            execute_values(cur, INSERT_SQL, rows, page_size=5000)

            # Contrôles post-chargement
            cur.execute("SELECT COUNT(*), COUNT(DISTINCT transaction_id) FROM exploded_products")
            db_rows, db_tx = cur.fetchone()
            if db_rows != len(rows) or db_tx != stats["transactions_kept"]:
                raise ValueError(
                    f"Volumétrie incohérente : base={db_rows}/{db_tx}, "
                    f"attendu={len(rows)}/{stats['transactions_kept']}")
        conn.commit()
        print(f"OK : {db_rows} lignes pour {db_tx} transactions chargées.")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    try:
        load_json_to_postgres()
    except Exception as e:
        print(f"ERREUR : {e}", file=sys.stderr)
        sys.exit(1)