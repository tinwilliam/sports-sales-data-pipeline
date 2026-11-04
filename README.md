Arborescence finale


sports-sales-data-pipeline/
├── dags/sports_sales_pipeline.py
├── data/raw/pos_sales_data_30k.json
├── sql/
│   ├── ddl/01_create_tables.sql
│   ├── transformations/   02_transaction_summary.sql, 03_..., 04_..., 05_...
│   ├── quality/06_data_quality_checks.sql
│   └── analytics/07_analytics_queries.sql
├── scripts/load_json.py, generate_report.py, run_pipeline.sh
├── reports/
├── logs/
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md


# Sports Sales Data Pipeline

Pipeline ETL qui transforme 30 000 tickets de caisse JSON (réseau de magasins de sport, 2023-2025) en tables analytiques PostgreSQL, orchestré par Airflow et déployé avec Docker Compose.

**Philosophie** : Python pour ingérer, SQL pour transformer et agréger, Airflow pour orchestrer, Docker pour déployer, Git pour versionner.

## Architecture

```mermaid
flowchart LR
    A[pos_sales_data_30k.json] -->|Python / psycopg2| B[exploded_products]
    B -->|vue SQL| C[transaction_summary]
    C --> D[store_sales_summary]
    C --> E[daily_sales_country_currency]
    C --> F[payment_method_analysis]
    D & E & F --> G[generate_report.py]
    G --> H[reports/reports.txt]
```

Le DAG Airflow `sports_sales_pipeline` enchaîne :
`create_tables` → `load_json` → `create_transaction_summary` → `check_data_quality` → 3 tables KPI en parallèle → `generate_report`.

## Technologies

| Outil | Rôle |
|---|---|
| Python 3 + psycopg2 | Lecture du JSON, explosion de `products[]`, chargement |
| PostgreSQL 16 | Stockage et transformations SQL |
| Apache Airflow 2.10 (LocalExecutor) | Orchestration quotidienne |
| Docker Compose | Environnement complet |
| pgAdmin | Interface de consultation |

## Structure du dépôt

```text
dags/            DAG Airflow
data/raw/        JSON source
sql/ddl/         création des tables
sql/transformations/  vue transaction_summary + 3 tables KPI
sql/quality/     contrôles de qualité
sql/analytics/   12 requêtes du lab
scripts/         load_json.py, generate_report.py, run_pipeline.sh
reports/         rapport généré
```

## Modèle de données

| Table | Granularité |
|---|---|
| `exploded_products` | 1 ligne par produit vendu (59 928 lignes) |
| `transaction_summary` (vue) | 1 ligne par ticket (30 000) |
| `store_sales_summary` | 1 ligne par (store_id, nom, pays, ville, type) |
| `daily_sales_country_currency` | 1 ligne par jour / pays / devise |
| `payment_method_analysis` | 1 ligne par moyen de paiement |

## Installation

Prérequis : Docker Desktop, 4 Go de RAM alloués à Docker.

```bash
cp .env.example .env        # puis modifier les mots de passe
# placer pos_sales_data_30k.json dans data/raw/
docker compose up -d
docker compose ps -a        # attendre healthy ; airflow-init termine en Exited (0)
```

## Utilisation

- Airflow : http://localhost:8080 (identifiants du `.env`)
- pgAdmin : http://localhost:8082 (serveur `postgres_dw`, port 5432)
- PostgreSQL depuis la machine : `localhost:5434`

Déclencher le pipeline :

```bash
docker compose exec airflow-scheduler airflow dags trigger sports_sales_pipeline
```

Le rapport est écrit dans `reports/reports.txt`. Pour tout enchaîner : `./scripts/run_pipeline.sh`.

## Règles métier et qualité des données

- **Pas de double comptage** : `total_amount` est répété sur chaque ligne produit après explosion. Toutes les agrégations passent par la vue `transaction_summary` (1 ligne par ticket).
- **Montants bruts** : `total_amount` est égal à la somme prix × quantité, avant remise. `discount_applied` est une information distincte.
- **Retours** : les transactions retournées sont incluses dans le chiffre d'affaires. Le taux de retour est calculé séparément.
- **Pas de conversion de devises** : les montants de devises différentes ne sont jamais additionnés comme s'ils étaient comparables.
- **`store_id` n'identifie pas un magasin physique** : le jeu de données (synthétique) associe un même `store_id` à plusieurs noms, pays et villes (8 681 `store_id` pour 29 930 combinaisons). Un magasin est donc défini par `(store_id, nom, pays, ville, type)`.
- **Full refresh** : chaque exécution recharge tout (TRUNCATE + INSERT), donc le DAG est rejouable sans doublons.
- **Contrôles** : la tâche `check_data_quality` bloque les KPI si les données sont vides, invalides ou incohérentes.

## Résultats

(Coller ici un extrait de `reports/reports.txt`.)

## Pistes d'amélioration

- Chargement incrémental
- Table de taux de change pour comparer les devises
- Tests automatisés SQL / Python
- Tableau de bord (Power BI, Metabase)
- Migration de la logique SQL vers dbt