#!/usr/bin/env bash
# Step 6: Verify Grafana dashboards are provisioned and accessible.
#
# How dashboard provisioning works:
#   Grafana reads provider.yml which points to /var/lib/grafana/dashboards/.
#   Every JSON file in that directory is loaded as a dashboard at startup.
#   The JSON files are bind-mounted from grafana/dashboards/ on the host.

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

GRAFANA_URL="http://localhost:3000"
AUTH="admin:admin"

echo ""
echo -e "${BOLD}=== GPU Monitoring Stack — Step 6: Dashboards ===${RESET}"
echo ""

echo -e "${BOLD}Dashboard Files${RESET}"
check \
    "grafana/dashboards/dcgm.json exists" \
    "test -f '$PROJECT_DIR/grafana/dashboards/dcgm.json'" \
    "Run: curl -sf https://grafana.com/api/dashboards/12239/revisions/latest/download -o grafana/dashboards/dcgm.json"

check \
    "grafana/dashboards/node-exporter.json exists" \
    "test -f '$PROJECT_DIR/grafana/dashboards/node-exporter.json'" \
    "Run: curl -sf https://grafana.com/api/dashboards/1860/revisions/latest/download -o grafana/dashboards/node-exporter.json"

echo ""
echo -e "${BOLD}Dashboards Loaded in Grafana${RESET}"
check \
    "DCGM dashboard provisioned" \
    "curl -sf -u '$AUTH' '$GRAFANA_URL/api/search?query=DCGM' | grep -qi 'dcgm'" \
    "Restart Grafana and check grafana/provisioning/dashboards/provider.yml"

check \
    "Node Exporter dashboard provisioned" \
    "curl -sf -u '$AUTH' '$GRAFANA_URL/api/search?query=Node+Exporter' | grep -qi 'node'" \
    "Restart Grafana and check grafana/provisioning/dashboards/provider.yml"

echo ""
echo -e "${BOLD}Dashboard Summary${RESET}"
curl -sf -u "$AUTH" "$GRAFANA_URL/api/search?type=dash-db" 2>/dev/null \
    | python3 -c "
import sys, json
boards = json.load(sys.stdin)
for b in boards:
    print(f'  {b[\"title\"]:<45} uid={b[\"uid\"]}')
" || echo -e "  ${YELLOW}(could not fetch dashboards)${RESET}"

echo ""
TOTAL=$((PASS + FAIL))
echo -e "${BOLD}Summary:${RESET} ${GREEN}${PASS}/${TOTAL} passed${RESET}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}All dashboards provisioned. Stack complete.${RESET}"
    echo -e "  Browse: $GRAFANA_URL  (admin/admin)"
    exit 0
else
    echo -e "${RED}${FAIL} check(s) failed.${RESET}"
    exit 1
fi
