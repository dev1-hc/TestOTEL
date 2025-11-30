# Grafana Provisioning Files

This folder contains all Grafana configuration files for automatic provisioning.

## Structure

```
grafana/
├── provisioning/
│   ├── datasources/
│   │   └── datasources.yml       # Auto-configure Tempo, Prometheus, Loki
│   └── dashboards/
│       └── dashboards.yml         # Dashboard provider config
├── dashboards/
│   └── otel-overview.json         # Pre-built OTEL dashboard
├── tempo/
│   └── tempo.yaml                 # Tempo configuration
├── prometheus/
│   └── prometheus.yml             # Prometheus configuration
└── loki/
    └── loki-config.yaml           # Loki configuration
```

## What Gets Auto-Configured

### Data Sources (provisioning/datasources/)
- **Tempo** - Traces backend with trace-to-logs correlation
- **Prometheus** - Metrics backend with exemplar support
- **Loki** - Logs backend with log-to-trace linking

### Dashboards (dashboards/)
- **OTEL Overview Dashboard** - Pre-configured with:
  - Request rate by route
  - P95/P50 latency
  - Error rate gauge
  - Status code distribution
  - Memory usage
  - Recent logs viewer

## Usage

Just copy the entire `grafana/` folder to your project and run:

```bash
docker compose -f docker-compose.grafana.yml up -d
```

Grafana will automatically:
1. Configure all 3 data sources
2. Load the OTEL Overview dashboard
3. Enable trace↔log↔metric correlation

Access Grafana at **http://localhost:3000** (no login required)

## Customization

### Add More Dashboards
1. Create dashboard in Grafana UI
2. Export as JSON: Dashboard Settings → JSON Model
3. Save to `grafana/dashboards/my-dashboard.json`
4. Restart Grafana - dashboard appears automatically

### Modify Data Source Settings
Edit `grafana/provisioning/datasources/datasources.yml`

### Enable Authentication
In `docker-compose.grafana.yml`, change:
```yaml
GF_AUTH_ANONYMOUS_ENABLED=false
GF_SECURITY_ADMIN_PASSWORD=yourpassword
```
