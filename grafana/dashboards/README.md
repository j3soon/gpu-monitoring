# Grafana Dashboards

Community dashboards provisioned automatically at Grafana startup.

## Sources

| File | Dashboard | Grafana ID | Source |
|---|---|---|---|
| `dcgm.json` | [NVIDIA DCGM Exporter Dashboard](https://docs.nvidia.com/datacenter/dcgm/latest/gpu-telemetry/dcgm-exporter.html) | ~~[12239](https://grafana.com/grafana/dashboards/12239)~~ (outdated, last updated 2021-09-23) | [NVIDIA/dcgm-exporter](https://github.com/NVIDIA/dcgm-exporter/blob/main/grafana/dcgm-exporter-dashboard.json) |
| `node-exporter.json` | Node Exporter Full | [1860](https://grafana.com/grafana/dashboards/1860) | rfmoz |
| `blackbox.json` | Prometheus Blackbox Exporter | [7587](https://grafana.com/grafana/dashboards/7587) | sparanoid |

```bash
curl -sf https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/grafana/dcgm-exporter-dashboard.json -o dcgm.json
curl -sf https://grafana.com/api/dashboards/1860/revisions/latest/download  -o node-exporter.json
curl -sf https://grafana.com/api/dashboards/7587/revisions/latest/download  -o blackbox.json
```
