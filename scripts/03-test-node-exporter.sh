#!/usr/bin/env bash
# Step 3: Verify Node Exporter is running and exposing host metrics.
#
# What this checks:
#   - Container is running
#   - :9100/metrics is reachable
#   - Key host metrics are present in the output
#
# How Node Exporter works:
#   Rather than running agent code, it simply reads kernel virtual filesystems:
#     /proc/stat        → CPU time per core and mode (user, system, idle, iowait, ...)
#     /proc/meminfo     → memory usage breakdown
#     /sys/class/net/*  → network interface stats (bytes, packets, errors)
#     /proc/diskstats   → block device I/O counters
#   These are mounted into the container read-only, so the exporter has zero
#   write access to the host — it is a read-only observer.

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

METRICS_URL="http://localhost:9100/metrics"

echo ""
echo -e "${BOLD}=== GPU Monitoring Stack — Step 3: Node Exporter ===${RESET}"
echo ""

echo -e "${BOLD}Containers${RESET}"
check \
    "dcgm-exporter still running" \
    "docker compose -f '$PROJECT_DIR/compose.yml' ps dcgm-exporter 2>/dev/null | grep -qi 'up'" \
    "Run: docker compose up -d"

check \
    "node-exporter running" \
    "docker compose -f '$PROJECT_DIR/compose.yml' ps node-exporter 2>/dev/null | grep -qi 'up'" \
    "Run: docker compose up -d"

echo ""
echo -e "${BOLD}HTTP Endpoint${RESET}"
check \
    ":9100/metrics reachable" \
    "curl -sf --max-time 5 $METRICS_URL > /dev/null" \
    "Container may still be starting — wait a few seconds and retry"

echo ""
echo -e "${BOLD}Host Metrics Present${RESET}"

# Key metrics across the main collector categories:
for metric in \
    "node_cpu_seconds_total:CPU time per core/mode — source: /proc/stat" \
    "node_memory_MemAvailable_bytes:Available memory — source: /proc/meminfo" \
    "node_filesystem_avail_bytes:Disk space available — source: statfs() syscall" \
    "node_network_receive_bytes_total:Network RX bytes — source: /sys/class/net" \
    "node_load1:1-minute load average — source: /proc/loadavg"; do

    name="${metric%%:*}"
    desc="${metric##*:}"
    check \
        "$name" \
        "curl -sf --max-time 5 $METRICS_URL 2>/dev/null | grep -Fm1 '${name}'" \
        "$desc"
done

echo ""
echo -e "${BOLD}Sample: CPU time breakdown (first core)${RESET}"
curl -sf --max-time 5 "$METRICS_URL" 2>/dev/null \
    | grep '^node_cpu_seconds_total{cpu="0"' \
    | awk -F'[{},="]' '{printf "  mode=%-10s  %s seconds\n", $8, $NF}' \
    | sort || echo -e "  ${YELLOW}(could not fetch metrics)${RESET}"

echo ""
TOTAL=$((PASS + FAIL))
echo -e "${BOLD}Summary:${RESET} ${GREEN}${PASS}/${TOTAL} passed${RESET}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}Node Exporter is healthy. Both exporters running. Ready for Step 4.${RESET}"
    exit 0
else
    echo -e "${RED}${FAIL} check(s) failed.${RESET}"
    exit 1
fi
