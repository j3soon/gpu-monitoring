#!/usr/bin/env bash
# Step 1: Verify host prerequisites for the GPU monitoring stack.
#
# What this checks:
#   - nvidia-smi         : NVIDIA drivers are installed and GPUs are visible
#   - docker compose     : Docker Compose v2 is available (ships with modern Docker)
#   - nvidia-ctk         : NVIDIA Container Toolkit is installed (GPU passthrough to containers)
#
# Why each matters:
#   nvidia-smi       → confirms the kernel driver can enumerate your GPUs
#   docker compose   → the v2 plugin syntax (not legacy docker-compose) is required
#   nvidia-ctk       → without this, Docker containers cannot access GPU devices;
#                      it configures the container runtime to inject /dev/nvidia* into containers

set -euo pipefail

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

    printf "  %-30s" "$label"
    if output=$(eval "$cmd" 2>&1); then
        echo -e "${GREEN}PASS${RESET}  $output"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${RESET}"
        echo -e "    ${YELLOW}hint:${RESET} $hint"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo -e "${BOLD}=== GPU Monitoring Stack — Step 1: Prerequisites ===${RESET}"
echo ""

# ── NVIDIA Drivers ────────────────────────────────────────────────────────────
echo -e "${BOLD}NVIDIA Drivers${RESET}"
check \
    "nvidia-smi available" \
    "command -v nvidia-smi > /dev/null" \
    "Install NVIDIA drivers: https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/"

check \
    "GPU detected" \
    "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1" \
    "Drivers installed but no GPU found — check PCIe slot / driver version"

echo ""

# ── Docker ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}Docker${RESET}"
check \
    "docker available" \
    "command -v docker > /dev/null" \
    "Install Docker: https://docs.docker.com/engine/install/"

check \
    "docker compose v2" \
    "docker compose version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+'" \
    "Need Docker Compose v2 — run: sudo apt install docker-compose-plugin  (or upgrade Docker Desktop)"

check \
    "docker daemon running" \
    "docker info > /dev/null 2>&1" \
    "Start the Docker daemon: sudo systemctl start docker"

echo ""

# ── NVIDIA Container Toolkit ──────────────────────────────────────────────────
echo -e "${BOLD}NVIDIA Container Toolkit${RESET}"
check \
    "nvidia-ctk available" \
    "command -v nvidia-ctk > /dev/null" \
    "Install: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"

check \
    "nvidia-ctk version" \
    "nvidia-ctk --version 2>/dev/null | head -1" \
    "nvidia-ctk found but cannot run — check installation"

check \
    "nvidia runtime configured" \
    "docker info 2>/dev/null | grep -i 'nvidia'" \
    "Run: sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo -e "${BOLD}Summary:${RESET} ${GREEN}${PASS}/${TOTAL} passed${RESET}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}All prerequisites met. Ready for Step 2.${RESET}"
    exit 0
else
    echo -e "${RED}${FAIL} check(s) failed. Fix the issues above before continuing.${RESET}"
    exit 1
fi
