#!/usr/bin/env bash
# Step 2: Verify DCGM Exporter is running and exposing GPU metrics.
#
# What this checks:
#   - Container is running
#   - :9400/metrics is reachable
#   - Key GPU metrics are present in the output
#
# Prometheus exposition format primer:
#   Each metric line looks like:
#     METRIC_NAME{label="value",...} numeric_value [timestamp]
#   Lines starting with # are comments (HELP = description, TYPE = metric type).
#   DCGM metric names follow the pattern DCGM_FI_DEV_* where FI = Field ID, DEV = device.

set -euo pipefail

# Always run docker compose commands from the project root
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

    printf "  %-40s" "$label"
    if output=$(set +o pipefail; eval "$cmd" 2>&1); then
        echo -e "${GREEN}PASS${RESET}  ${output:0:80}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${RESET}"
        echo -e "    ${YELLOW}hint:${RESET} $hint"
        FAIL=$((FAIL + 1))
    fi
}

METRICS_URL="http://localhost:9400/metrics"

echo ""
echo -e "${BOLD}=== GPU Monitoring Stack — Step 2: DCGM Exporter ===${RESET}"
echo ""

echo -e "${BOLD}Container${RESET}"
check \
    "dcgm-exporter container running" \
    "docker compose -f '$PROJECT_DIR/compose.yml' ps dcgm-exporter 2>/dev/null | grep -qi 'up'" \
    "Run: docker compose up -d  (from the gpu-monitoring directory)"

echo ""
echo -e "${BOLD}HTTP Endpoint${RESET}"
check \
    ":9400/metrics reachable" \
    "curl -sf --max-time 5 $METRICS_URL > /dev/null" \
    "Container may still be starting — wait a few seconds and retry"

echo ""
echo -e "${BOLD}GPU Metrics Present${RESET}"

# The most important metrics to confirm DCGM is working:
for metric in \
    "DCGM_FI_DEV_GPU_UTIL:GPU compute utilization %" \
    "DCGM_FI_DEV_FB_USED:Framebuffer (VRAM) used MB" \
    "DCGM_FI_DEV_GPU_TEMP:GPU temperature °C" \
    "DCGM_FI_DEV_POWER_USAGE:Power draw watts"; do

    name="${metric%%:*}"
    desc="${metric##*:}"
    check \
        "$name" \
        "curl -sf --max-time 5 $METRICS_URL 2>/dev/null | grep -Fm1 '${name}'" \
        "$desc — metric not found; check DCGM container logs: docker compose logs dcgm-exporter"
done

echo ""
echo -e "${BOLD}Sample Output (first 5 non-comment lines)${RESET}"
if curl -sf --max-time 5 "$METRICS_URL" 2>/dev/null | grep -v '^#' | grep -v '^$' | head -5; then
    true
else
    echo -e "  ${YELLOW}(could not fetch metrics)${RESET}"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo -e "${BOLD}Summary:${RESET} ${GREEN}${PASS}/${TOTAL} passed${RESET}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}DCGM Exporter is healthy. Ready for Step 3.${RESET}"
    exit 0
else
    echo -e "${RED}${FAIL} check(s) failed.${RESET}"
    exit 1
fi
