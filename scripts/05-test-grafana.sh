#!/usr/bin/env bash
# Step 5: Verify Grafana is running and the Prometheus datasource is provisioned.
#
# How Grafana provisioning works:
#   On startup Grafana scans /etc/grafana/provisioning/ for YAML files.
#   Datasource files are loaded before the UI becomes available, so by the time
#   Grafana is healthy the datasource is already registered — no manual clicks needed.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0

check() {
    local label="$1"
    local cmd="$2"
    local hint="$3"

    printf "  %-45s" "$label"
    if output=$(set +o pipefail; eval "$cmd" 2>&1); then
        echo -e "${GREEN}PASS${RESET}  ${output:0:75}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${RESET}"
        echo -e "    ${YELLOW}hint:${RESET} $hint"
        FAIL=$((FAIL + 1))
    fi
}

GRAFANA_URL="http://localhost:33000"
AUTH="admin:admin"

echo ""
echo -e "${BOLD}=== GPU Monitoring Stack — Step 5: Grafana ===${RESET}"
echo ""

echo -e "${BOLD}Container${RESET}"
check \
    "grafana running" \
    "docker compose -f '$PROJECT_DIR/compose.yml' ps grafana 2>/dev/null | grep -qi 'up'" \
    "Run: bash scripts/setup.sh && docker compose up -d"

echo ""
echo -e "${BOLD}HTTP Endpoint${RESET}"
check \
    ":33000 reachable" \
    "curl -sf --max-time 10 '$GRAFANA_URL/api/health' | grep -q 'ok'" \
    "Container may still be starting — wait a few seconds and retry"

echo ""
echo -e "${BOLD}Datasource Provisioning${RESET}"
check \
    "Prometheus datasource exists" \
    "curl -sf --max-time 5 -u '$AUTH' '$GRAFANA_URL/api/datasources' | grep -q 'Prometheus'" \
    "Check grafana/provisioning/datasources/prometheus.yml and restart Grafana"

check \
    "Prometheus datasource is default" \
    "curl -sf --max-time 5 -u '$AUTH' '$GRAFANA_URL/api/datasources' | python3 -c \"import sys,json; ds=json.load(sys.stdin); exit(0 if any(d.get('isDefault') and d.get('type')=='prometheus' for d in ds) else 1)\"" \
    "isDefault not set — check grafana/provisioning/datasources/prometheus.yml"

check \
    "Prometheus datasource healthy" \
    "uid=\$(curl -sf -u '$AUTH' '$GRAFANA_URL/api/datasources' | python3 -c \"import sys,json; ds=json.load(sys.stdin); print(next(d['uid'] for d in ds if d['type']=='prometheus'))\") && curl -sf --max-time 10 -u '$AUTH' '$GRAFANA_URL/api/datasources/uid/'\$uid'/health' | grep -q 'OK'" \
    "Grafana cannot reach Prometheus — check prometheus container is running"

echo ""
TOTAL=$((PASS + FAIL))
echo -e "${BOLD}Summary:${RESET} ${GREEN}${PASS}/${TOTAL} passed${RESET}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}Grafana is healthy. Datasource provisioned. Ready for Step 6.${RESET}"
    echo -e "  Browse: $GRAFANA_URL  (admin/admin)"
    exit 0
else
    echo -e "${RED}${FAIL} check(s) failed.${RESET}"
    exit 1
fi
