#!/usr/bin/env bash
# Step 4: Verify Prometheus is running and all scrape targets are UP.
#
# How Prometheus stores data:
#   Each scraped metric becomes a time-series identified by its name + label set.
#   Data is stored in a local TSDB (time-series database) in 2-hour blocks,
#   compacted over time.  The HTTP API (/api/v1/*) lets us query this data —
#   which is exactly what Grafana will do in later steps.
#
# What "UP" means on the targets page:
#   Prometheus records a synthetic metric `up{job="...",instance="..."}` after
#   each scrape: 1 = scrape succeeded, 0 = failed.  A target showing State: UP
#   means the last scrape returned HTTP 200 with valid exposition-format text.

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

PROM_URL="http://localhost:9090"

echo ""
echo -e "${BOLD}=== GPU Monitoring Stack — Step 4: Prometheus ===${RESET}"
echo ""

echo -e "${BOLD}Container${RESET}"
check \
    "prometheus running" \
    "docker compose -f '$PROJECT_DIR/compose.yml' ps prometheus 2>/dev/null | grep -qi 'up'" \
    "Run: docker compose up -d"

echo ""
echo -e "${BOLD}HTTP Endpoint${RESET}"
check \
    ":9090 reachable" \
    "curl -sf --max-time 5 $PROM_URL/-/healthy > /dev/null" \
    "Container may still be starting — wait a few seconds and retry"

echo ""
echo -e "${BOLD}Scrape Targets (via API)${RESET}"
# Query the `up` metric per job — Prometheus sets up=1 after a successful scrape,
# up=0 on failure.  This is simpler and more reliable than parsing /api/v1/targets JSON.
for job in prometheus dcgm-exporter node-exporter; do
    check \
        "$job target UP" \
        "curl -sf --max-time 5 '$PROM_URL/api/v1/query?query=up%7Bjob%3D%22$job%22%7D' \
            | grep -q '\"1\"'" \
        "Open $PROM_URL/targets in browser to see error detail for job=$job"
done

echo ""
echo -e "${BOLD}Data Queryable (via API)${RESET}"
for metric in "DCGM_FI_DEV_GPU_TEMP" "node_load1" "up"; do
    check \
        "$metric returns results" \
        "curl -sf --max-time 5 '$PROM_URL/api/v1/query?query=$metric' \
            | grep -q '\"result\":\[{'" \
        "Metric not yet scraped — wait 15s (one scrape interval) and retry"
done

echo ""
echo -e "${BOLD}Active Targets Summary${RESET}"
curl -sf --max-time 5 "$PROM_URL/api/v1/targets" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
for t in data.get('data', {}).get('activeTargets', []):
    job      = t['labels'].get('job', '?')
    instance = t['labels'].get('instance', '?')
    health   = t.get('health', '?')
    print(f'  job={job:<20} instance={instance:<35} health={health}')
" || echo -e "  ${YELLOW}(could not fetch targets)${RESET}"

echo ""
TOTAL=$((PASS + FAIL))
echo -e "${BOLD}Summary:${RESET} ${GREEN}${PASS}/${TOTAL} passed${RESET}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}Prometheus is healthy. All targets UP. Ready for Step 5.${RESET}"
    echo -e "  Browse: $PROM_URL/targets"
    exit 0
else
    echo -e "${RED}${FAIL} check(s) failed.${RESET}"
    exit 1
fi
