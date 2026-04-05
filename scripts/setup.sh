#!/usr/bin/env bash
# Initial setup: create directories and fix permissions before first run.
#
# Why permissions matter:
#   Prometheus runs as UID 65534 (nobody) inside the container.
#   The data directory is bind-mounted from the host, so it must be
#   owned by that UID. We use sudo chown rather than chmod 777 to grant
#   access only to the specific UID instead of all users on the host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Creating data directories..."
mkdir -p "$PROJECT_DIR/prometheus/data"
sudo chown 65534:65534 "$PROJECT_DIR/prometheus/data"
echo "  prometheus/data — OK (owned by UID 65534)"

echo ""
echo "Setup complete. Start the stack with:"
echo "  docker compose up -d"
