# GPU Monitoring Stack

Minimal Prometheus + Grafana monitoring for NVIDIA GPUs and host system metrics, running via Docker Compose.

## Stack

| Service | Image | Port | Purpose |
|---|---|---|---|
| dcgm-exporter | nvcr.io/nvidia/k8s/dcgm-exporter:4.5.2-4.8.1-ubuntu22.04 | 9400 | NVIDIA GPU metrics |
| node-exporter | prom/node-exporter:v1.11.0 | 9100 | Host CPU / memory / disk / network |
| prometheus | prom/prometheus:v3.11.0 | 9090 | Metrics storage and querying |
| grafana | grafana/grafana:12.4.2 | 33000 | Dashboards *(changed from default 3000 to avoid conflicts with dev servers)* |
| blackbox-exporter | prom/blackbox-exporter:v0.28.0 | 9115 | HTTP and ICMP probes for network monitoring |

## Prerequisites

- NVIDIA drivers (`nvidia-smi`)
- NVIDIA Container Toolkit (`nvidia-ctk`)
- Docker with Compose v2

Verify with:
```bash
bash scripts/01-check-prerequisites.sh
```

## Quick Start

```bash
bash scripts/setup.sh      # create data dirs with correct permissions (run once)
docker compose up -d
```

Open http://localhost:33000 (admin / admin).

## Validation Scripts

> All test scripts were vibe coded by [Claude Code](https://claude.ai/code).

Run each script to verify the corresponding layer of the stack:

```bash
bash scripts/01-check-prerequisites.sh   # host requirements (drivers, toolkit, docker)
bash scripts/02-test-dcgm.sh             # GPU metrics at :9400
bash scripts/03-test-node-exporter.sh    # host metrics at :9100
bash scripts/04-test-prometheus.sh       # all scrape targets UP at :9090
bash scripts/05-test-grafana.sh          # Grafana reachable, datasource provisioned
bash scripts/06-test-dashboards.sh       # GPU, node, and blackbox dashboards loaded at :33000
bash scripts/07-test-network.sh          # HTTP and ICMP probes passing at :9115
```
