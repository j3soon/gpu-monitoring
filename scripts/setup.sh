#!/usr/bin/env bash
# Initial setup: create directories and fix permissions before first run.
#
# Why permissions matter:
#   Bind-mounted data directories must be owned by the UID the process runs as
#   inside the container. We use sudo chown rather than chmod 777 to grant
#   access only to the specific UID instead of all users on the host.
#
#   Prometheus → UID 65534 (nobody)
#   Grafana    → UID 472

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Creating data directories..."

mkdir -p "$PROJECT_DIR/prometheus/data"
sudo chown 65534:65534 "$PROJECT_DIR/prometheus/data"
echo "  prometheus/data — OK (owned by UID 65534)"

mkdir -p "$PROJECT_DIR/grafana/data"
sudo chown 472:472 "$PROJECT_DIR/grafana/data"
echo "  grafana/data    — OK (owned by UID 472)"

echo ""
echo "Setup complete. Start the stack with:"
echo "  docker compose up -d"
