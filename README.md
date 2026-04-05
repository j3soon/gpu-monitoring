# GPU Monitoring Stack

Prometheus + Grafana monitoring for NVIDIA GPUs and host system metrics, running via Docker Compose.

## Stack

| Service | Image | Port | Purpose |
|---|---|---|---|
| dcgm-exporter | nvcr.io/nvidia/k8s/dcgm-exporter | 9400 | NVIDIA GPU metrics |
| node-exporter | prom/node-exporter | 9100 | Host CPU / memory / disk / network |
| prometheus | prom/prometheus | 9090 | Metrics storage and querying |
| grafana | grafana/grafana | 33000 | Dashboards *(changed from default 3000 to avoid conflicts with dev servers)* |

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
bash scripts/setup.sh
docker compose up -d
```

## Validation Scripts

Each step has a corresponding test script:

```bash
bash scripts/01-check-prerequisites.sh   # verify host requirements
bash scripts/02-test-dcgm.sh             # GPU metrics at :9400
bash scripts/03-test-node-exporter.sh    # host metrics at :9100
bash scripts/04-test-prometheus.sh       # all targets UP at :9090
```
