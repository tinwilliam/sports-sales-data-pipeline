#!/bin/bash

#
#Version simplifiee du script run_pipeline.sh pour declencher le DAG Airflow
#
#set -e
#cd "$(dirname "$0")/.."

#docker compose up -d

#echo "Attente du webserver Airflow..."
#until curl -sf http://localhost:8080/health > /dev/null; do sleep 3; done

#docker compose exec -T airflow-scheduler airflow dags trigger sports_sales_pipeline
#echo "DAG declenche. Rapport attendu dans reports/reports.txt"
#

# version plus robuste avec verification de l'etat du DAG
set -e
cd "$(dirname "$0")/.."

DAG_ID="sports_sales_pipeline"
RUN_ID="manual_$(date +%Y%m%d_%H%M%S)"
AF="docker compose exec -T airflow-scheduler airflow"

echo "[1/4] Demarrage de l'environnement Docker..."
docker compose up -d

echo "[2/4] Attente du webserver Airflow..."
for i in $(seq 1 60); do
  curl -sf http://localhost:8080/health > /dev/null && break
  [ "$i" -eq 60 ] && { echo "ERREUR : webserver indisponible apres 3 min"; exit 1; }
  sleep 3
done

echo "[3/4] Attente de la detection du DAG..."
for i in $(seq 1 30); do
  $AF dags list 2>/dev/null | grep -q "$DAG_ID" && break
  [ "$i" -eq 30 ] && { echo "ERREUR : DAG $DAG_ID introuvable"; exit 1; }
  sleep 3
done

echo "[4/4] Declenchement du DAG (run_id=$RUN_ID)..."
$AF dags trigger "$DAG_ID" --run-id "$RUN_ID" > /dev/null 2>&1

while true; do
  STATE=$($AF dags list-runs -d "$DAG_ID" -o json 2>/dev/null | python3 -c "
import sys, json
t = sys.stdin.read()
runs = json.loads(t[t.index('['):])
print(next((r['state'] for r in runs if r['run_id'] == '$RUN_ID'), 'unknown'))
")
  echo "  etat : $STATE"
  case "$STATE" in
    success) break ;;
    failed)  echo "ERREUR : le run a echoue (voir http://localhost:8080)"; exit 1 ;;
  esac
  sleep 5
done

echo "Pipeline termine. Rapport : reports/reports.txt"