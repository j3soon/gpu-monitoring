# Grafana Dashboards

Community dashboards provisioned automatically at Grafana startup.

## Sources

| File | Dashboard | Grafana ID | Source |
|---|---|---|---|
| `dcgm.json` | NVIDIA DCGM Exporter Dashboard | [12239](https://grafana.com/grafana/dashboards/12239) | NVIDIA |
| `node-exporter.json` | Node Exporter Full | [1860](https://grafana.com/grafana/dashboards/1860) | rfmoz |

```bash
curl -sf https://grafana.com/api/dashboards/12239/revisions/latest/download -o dcgm.json
curl -sf https://grafana.com/api/dashboards/1860/revisions/latest/download  -o node-exporter.json
```
