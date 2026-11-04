import os
import re
import sys
from datetime import datetime
from decimal import Decimal
from pathlib import Path

import psycopg2

BASE_DIR = Path(__file__).resolve().parent.parent
SQL_PATH = Path(os.getenv("ANALYTICS_SQL", BASE_DIR / "sql" / "analytics" / "07_analytics_queries.sql"))
REPORT_PATH = Path(os.getenv("REPORT_PATH", BASE_DIR / "reports" / "reports.txt"))

SECTIONS = {
    "store": "1. STORE SALES ANALYSIS (store_sales_summary)",
    "daily": "2. DAILY SALES ANALYSIS (daily_sales_country_currency)",
    "payment": "3. PAYMENT ANALYSIS (payment_method_analysis)",
}

NOTES = [
    "Les montants sont bruts, avant remise (total_amount = somme prix x quantite).",
    "Les devises ne sont pas converties : ne comparez pas des montants de devises differentes.",
    "store_id n'identifie pas un magasin physique : un magasin = (store_id, nom, pays, ville, type).",
]


def get_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5434"),
        dbname=os.environ["DW_DB"],
        user=os.environ["DW_USER"],
        password=os.environ["DW_PASSWORD"],
    )


def parse_queries(path):
    """Retourne [(cle, titre, sql)] a partir des marqueurs '-- name: cle | titre'."""
    queries, current = [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"--\s*name:\s*(\w+)\s*\|\s*(.+)", line)
        if m:
            current = [m.group(1), m.group(2).strip(), []]
            queries.append(current)
        elif current is not None:
            current[2].append(line)
    return [(k, t, "\n".join(s).strip()) for k, t, s in queries]


def fmt(value):
    if value is None:
        return "-"
    if isinstance(value, (Decimal, float)):
        return f"{value:,.2f}"
    return str(value)


def format_table(columns, rows):
    data = [[fmt(v) for v in r] for r in rows]
    widths = [max(len(c), *(len(r[i]) for r in data)) if data else len(c)
              for i, c in enumerate(columns)]
    line = " | ".join(c.ljust(w) for c, w in zip(columns, widths))
    out = [line, "-+-".join("-" * w for w in widths)]
    out += [" | ".join(v.ljust(w) for v, w in zip(r, widths)) for r in data]
    return "\n".join(out)


def generate_report():
    queries = parse_queries(SQL_PATH)
    if len(queries) != 12:
        raise ValueError(f"12 requetes attendues, {len(queries)} trouvees dans {SQL_PATH}")

    bar = "=" * 70
    lines = [bar, "SPORTS SALES DATA PIPELINE - ANALYTICS REPORT",
             f"Genere le {datetime.now():%Y-%m-%d %H:%M:%S}", bar, "", "NOTES"]
    lines += [f"  - {n}" for n in NOTES]

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            current_section = None
            for key, title, sql in queries:
                prefix = key.split("_")[0]
                if prefix != current_section:
                    current_section = prefix
                    lines += ["", bar, SECTIONS[prefix], bar]
                cur.execute(sql)
                columns = [d[0] for d in cur.description]
                rows = cur.fetchall()
                lines += ["", f"[{key}] {title}", format_table(columns, rows)]
    finally:
        conn.close()

    lines += ["", bar, "END OF REPORT", bar, ""]
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Rapport ecrit : {REPORT_PATH} ({len(queries)} requetes)")


if __name__ == "__main__":
    try:
        generate_report()
    except Exception as e:
        print(f"ERREUR : {e}", file=sys.stderr)
        sys.exit(1)