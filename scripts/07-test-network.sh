#!/usr/bin/env bash
# Step 7: Verify blackbox-exporter is running and network probes are succeeding.
#
# How blackbox probing works:
#   Unlike other exporters, blackbox-exporter does not scrape a fixed target.
#   Prometheus passes the probe target as a query parameter (?target=<url>),
#   and blackbox returns metrics for that specific probe on demand.
#   This script checks the exporter directly and via Prometheus.

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

BLACKBOX_URL="http://localhost:9115"
PROMETHEUS_URL="http://localhost:9090"

echo ""
echo -e "${BOLD}=== GPU Monitoring Stack — Step 7: Network Probes ===${RESET}"
echo ""

echo -e "${BOLD}Blackbox Exporter${RESET}"
check \
    "blackbox-exporter reachable at :9115" \
    "curl -sf '$BLACKBOX_URL/health'" \
    "Run: docker compose up -d blackbox-exporter"

check \
    "HTTP probe: github.com returns 2xx" \
    "curl -sf '$BLACKBOX_URL/probe?target=https://github.com&module=http_2xx' | grep -m1 'probe_success 1'" \
    "Check blackbox/blackbox.yml http_2xx module and network connectivity"

check \
    "ICMP probe: github.com responds to ping" \
    "curl -sf '$BLACKBOX_URL/probe?target=github.com&module=icmp' | grep -m1 'probe_success 1'" \
    "Check blackbox/blackbox.yml icmp module and NET_RAW capability in compose.yml"

check \
    "ICMP probe: 8.8.8.8 responds to ping" \
    "curl -sf '$BLACKBOX_URL/probe?target=8.8.8.8&module=icmp' | grep -m1 'probe_success 1'" \
    "Check network connectivity to 8.8.8.8"

echo ""
echo -e "${BOLD}Prometheus Scrape Targets${RESET}"
check \
    "blackbox-http targets UP in Prometheus" \
    "curl -sf '$PROMETHEUS_URL/api/v1/targets' | python3 -c \"
import sys, json
targets = json.load(sys.stdin)['data']['activeTargets']
bb = [t for t in targets if t['labels'].get('job') == 'blackbox-http']
assert len(bb) > 0, 'no targets found — Prometheus may not have scraped yet'
assert all(t['health'] == 'up' for t in bb), f'not all up: {[t[\"health\"] for t in bb]}'
print(f'{len(bb)} target(s) up')
\"" \
    "Wait a scrape interval and check: curl $PROMETHEUS_URL/api/v1/targets"

check \
    "blackbox-icmp targets UP in Prometheus" \
    "curl -sf '$PROMETHEUS_URL/api/v1/targets' | python3 -c \"
import sys, json
targets = json.load(sys.stdin)['data']['activeTargets']
bb = [t for t in targets if t['labels'].get('job') == 'blackbox-icmp']
assert len(bb) > 0, 'no targets found — Prometheus may not have scraped yet'
assert all(t['health'] == 'up' for t in bb), f'not all up: {[t[\"health\"] for t in bb]}'
print(f'{len(bb)} target(s) up')
\"" \
    "Wait a scrape interval and check: curl $PROMETHEUS_URL/api/v1/targets"

echo ""
echo -e "${BOLD}Probe Latency (live)${RESET}"
curl -sf "$BLACKBOX_URL/probe?target=github.com&module=icmp" 2>/dev/null \
    | grep '^probe_duration_seconds' \
    | awk '{printf "  github.com ICMP latency: %.1f ms\n", $2 * 1000}' \
    || echo -e "  ${YELLOW}(could not fetch latency)${RESET}"

curl -sf "$BLACKBOX_URL/probe?target=https://github.com&module=http_2xx" 2>/dev/null \
    | grep '^probe_duration_seconds' \
    | awk '{printf "  github.com HTTP latency: %.1f ms\n", $2 * 1000}' \
    || echo -e "  ${YELLOW}(could not fetch latency)${RESET}"

echo ""
TOTAL=$((PASS + FAIL))
echo -e "${BOLD}Summary:${RESET} ${GREEN}${PASS}/${TOTAL} passed${RESET}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}All network probes passing.${RESET}"
    exit 0
else
    echo -e "${RED}${FAIL} check(s) failed.${RESET}"
    exit 1
fi
