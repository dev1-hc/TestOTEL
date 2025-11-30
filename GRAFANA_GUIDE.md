# Grafana Observability Stack Guide

Complete setup for visualizing OTEL telemetry in Grafana using Tempo (traces), Prometheus (metrics), and Loki (logs).

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────┐
│   Node.js   │────▶│     OTEL     │────▶│  Tempo  │ (Traces)
│     App     │     │  Collector   │     ├─────────┤
└─────────────┘     └──────────────┘     │Prometheus│ (Metrics)
                                         ├─────────┤
┌─────────────┐                          │  Loki   │ (Logs)
│   NGINX     │                          └────┬────┘
│ (FluentBit) │                               │
└─────────────┘                               │
                                              ▼
                                        ┌─────────┐
                                        │ Grafana │
                                        └─────────┘
```

**OTEL Collector** = Data pipeline (no storage)
**Tempo/Prometheus/Loki** = Storage backends
**Grafana** = Visualization UI

## Quick Start

### Windows
```powershell
.\setup_grafana.ps1
```

### Linux/Ubuntu
```bash
chmod +x setup_grafana.sh
./setup_grafana.sh
```

This starts:
- **Grafana** on port 3000
- **Prometheus** on port 9090
- **Tempo** on port 3200
- **Loki** on port 3100
- **OTEL Collector** on ports 4317/4318/8889

## Access Grafana

1. Open browser: http://localhost:3000
2. **No login required** (auto-login enabled for demo)
3. All data sources are pre-configured

## Viewing Telemetry

### 1. Explore Traces (Tempo)

1. Click **Explore** (compass icon)
2. Select **Tempo** data source
3. Query options:
   - **Search**: Filter by service, tags, duration
   - **TraceQL**: `{service.name="nodejs-app"}` 
   - **Trace ID**: Paste specific trace ID

**Example TraceQL Queries:**
```traceql
# All traces from nodejs-app
{service.name="nodejs-app"}

# Slow requests (>500ms)
{service.name="nodejs-app" && duration > 500ms}

# Error traces
{status=error}

# Specific endpoint
{http.target="/api/users"}
```

### 2. Explore Metrics (Prometheus)

1. Click **Explore**
2. Select **Prometheus** data source
3. Use PromQL queries:

**Example Queries:**
```promql
# Request rate
rate(http_server_duration_count[5m])

# P95 latency
histogram_quantile(0.95, rate(http_server_duration_bucket[5m]))

# Error rate
rate(http_server_duration_count{http_status_code=~"5.."}[5m])

# Active connections
nodejs_active_handles_total

# Memory usage
process_resident_memory_bytes / 1024 / 1024
```

### 3. Explore Logs (Loki)

1. Click **Explore**
2. Select **Loki** data source
3. Use LogQL queries:

**Example Queries:**
```logql
# All logs from nodejs-app
{service_name="nodejs-app"}

# Error logs only
{service_name="nodejs-app"} |= "error" | json

# Specific trace ID
{service_name="nodejs-app"} | json | trace_id="abc123"

# HTTP 500 errors
{service_name="nginx"} | json | status="500"

# Logs with line filters
{service_name="nodejs-app"} |~ "user|order|payment"
```

## Creating Dashboards

### Option 1: Import Pre-built Dashboard

1. Go to **Dashboards** → **Import**
2. Enter dashboard ID:
   - **Node.js**: 11956
   - **NGINX**: 12708
   - **OTEL Collector**: 15983
3. Select data sources (Prometheus, Tempo, Loki)
4. Click **Import**

### Option 2: Create Custom Dashboard

1. Click **+** → **Dashboard** → **Add visualization**
2. Select data source
3. Configure query:

**Trace Panel:**
- Data source: Tempo
- Query: `{service.name="nodejs-app"}`
- Visualization: Traces

**Metric Panel:**
- Data source: Prometheus
- Query: `rate(http_server_duration_count[5m])`
- Visualization: Time series / Gauge / Stat

**Log Panel:**
- Data source: Loki
- Query: `{service_name="nodejs-app"}`
- Visualization: Logs

4. Click **Save dashboard**

## Correlation Features

Grafana automatically links traces ↔ logs ↔ metrics:

### Traces → Logs
- Click trace span → **Logs for this span** button
- Automatically filters logs by trace ID and time range

### Logs → Traces
- Click log line with trace_id → **Tempo** button appears
- Jumps to full trace visualization

### Metrics → Traces (Exemplars)
- Hover over metric graph spike
- Click exemplar dot → Shows sample trace
- Requires trace IDs in metrics (auto-configured)

## Example Dashboard Panels

### Panel 1: Request Rate
```promql
sum(rate(http_server_duration_count[5m])) by (http_route)
```
Visualization: **Time series**

### Panel 2: Error Rate
```promql
sum(rate(http_server_duration_count{http_status_code=~"5.."}[5m])) by (http_route)
```
Visualization: **Time series** (red line)

### Panel 3: P95 Latency
```promql
histogram_quantile(0.95, sum(rate(http_server_duration_bucket[5m])) by (le, http_route))
```
Visualization: **Time series**

### Panel 4: Recent Errors
```logql
{service_name="nodejs-app"} |= "error" | json
```
Visualization: **Logs**

### Panel 5: Service Map
Data source: **Tempo**
Visualization: **Node Graph**
Query: Service map from traces

## Run Your App

Start your Node.js app to generate telemetry:

```bash
cd nodejs-examples
npm install
npm start
```

Generate traffic:
```bash
curl http://localhost:3001/
curl http://localhost:3001/api/users/123
curl http://localhost:3001/api/orders -X POST -H "Content-Type: application/json" -d '{"item":"test"}'
```

## Verify Data Flow

### Check OTEL Collector
```bash
# Docker
docker logs otel-collector

# Look for:
# - "Traces" → Tempo is receiving
# - "Metrics" → Prometheus is scraping
# - "Logs" → Loki is receiving
```

### Check Tempo
```bash
curl http://localhost:3200/api/search?tags=service.name=nodejs-app
```

### Check Prometheus
```bash
curl http://localhost:9090/api/v1/label/__name__/values | jq
```

### Check Loki
```bash
curl -G 'http://localhost:3100/loki/api/v1/query' --data-urlencode 'query={service_name="nodejs-app"}'
```

## Troubleshooting

### No Traces in Grafana
1. Check OTEL Collector logs: `docker logs otel-collector`
2. Verify Tempo is running: `docker ps | grep tempo`
3. Check Tempo endpoint: `curl http://localhost:3200/ready`
4. Verify app is sending traces: Check app startup logs for "OpenTelemetry initialized"

### No Metrics in Grafana
1. Check Prometheus targets: http://localhost:9090/targets
2. Verify `otel-collector:8889` target is **UP**
3. Check OTEL Collector metrics endpoint: `curl http://localhost:8889/metrics`
4. Verify Prometheus scraping: `docker logs prometheus | grep otel-collector`

### No Logs in Grafana
1. Check Loki is running: `docker ps | grep loki`
2. Verify Loki endpoint: `curl http://localhost:3100/ready`
3. Check OTEL Collector logs for Loki export errors
4. Test Loki query: `curl http://localhost:3100/loki/api/v1/labels`

### Connection Refused Errors
- Ensure all services are on same Docker network (`otel-network`)
- Check `docker compose -f docker-compose.grafana.yml ps`
- Verify service names resolve: `docker exec -it grafana ping tempo`

### Data Source Not Working
1. In Grafana, go to **Connections** → **Data sources**
2. Click data source → **Test** button
3. Should show "Data source is working"
4. If not, check URL uses container name (not localhost)

## Management Commands

### View Logs
```bash
# All services
docker compose -f docker-compose.grafana.yml logs -f

# Specific service
docker compose -f docker-compose.grafana.yml logs -f grafana
docker compose -f docker-compose.grafana.yml logs -f tempo
docker compose -f docker-compose.grafana.yml logs -f prometheus
docker compose -f docker-compose.grafana.yml logs -f loki
docker compose -f docker-compose.grafana.yml logs -f otel-collector
```

### Restart Services
```bash
# Restart all
docker compose -f docker-compose.grafana.yml restart

# Restart specific service
docker compose -f docker-compose.grafana.yml restart otel-collector
```

### Stop Stack
```bash
docker compose -f docker-compose.grafana.yml down
```

### Complete Cleanup (removes data)
```bash
docker compose -f docker-compose.grafana.yml down -v
```

## Advanced Configuration

### Enable Authentication in Grafana
Edit `docker-compose.grafana.yml`:
```yaml
environment:
  - GF_AUTH_ANONYMOUS_ENABLED=false  # Disable anonymous
  - GF_SECURITY_ADMIN_PASSWORD=admin # Set password
```

### Persist Grafana Dashboards
1. Create dashboards in Grafana UI
2. Export as JSON: **Dashboard settings** → **JSON Model**
3. Save to `grafana/provisioning/dashboards/`
4. Restart Grafana

### Add Custom Metrics
In your Node.js app:
```javascript
const { metrics } = require('@opentelemetry/api');
const meter = metrics.getMeter('my-app');

const counter = meter.createCounter('custom_counter');
counter.add(1, { label: 'value' });
```

### Configure Alerting
1. In Grafana, go to **Alerting** → **Alert rules**
2. Click **New alert rule**
3. Set query and threshold:
   - **Query**: `rate(http_server_duration_count{http_status_code=~"5.."}[5m]) > 0.1`
   - **Threshold**: Error rate > 10%
4. Configure notification channel (email, Slack, etc.)

## Next Steps

1. ✅ Run setup script (`setup_grafana.ps1` or `setup_grafana.sh`)
2. ✅ Open Grafana at http://localhost:3000
3. ✅ Start your Node.js app
4. ✅ Explore traces, metrics, and logs
5. ✅ Create custom dashboards
6. ✅ Set up alerts for critical metrics

For more details, see:
- [Grafana Documentation](https://grafana.com/docs/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [Prometheus Query Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Guide](https://grafana.com/docs/loki/latest/logql/)
