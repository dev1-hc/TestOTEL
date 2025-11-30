# OpenTelemetry Observability Stack

Complete observability setup with OTEL Collector + Grafana visualization for NGINX and Node.js applications.

## 🏗️ Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────┐
│   Node.js   │────▶│     OTEL     │────▶│  Tempo  │ (Traces)
│     App     │     │  Collector   │     ├─────────┤
└─────────────┘     └──────────────┘     │Prometheus│ (Metrics)
                                         ├─────────┤
┌─────────────┐                          │  Loki   │ (Logs)
│   NGINX     │                          └────┬────┘
│ (Optional)  │                               │
└─────────────┘                               ▼
                                        ┌─────────┐
                                        │ Grafana │
                                        └─────────┘
```

## 📦 What's Included

- **OTEL Collector**: Central telemetry pipeline (ports 4317/4318)
- **Grafana**: Visualization UI (port 3000)
- **Tempo**: Distributed tracing backend
- **Prometheus**: Metrics storage and querying
- **Loki**: Log aggregation
- **Node.js Examples**: Instrumented Express.js app with traces, metrics, logs

## 🚀 Quick Start

### Option A: Node.js Apps + Grafana Visualization

**1. Start Observability Stack**
```bash
chmod +x setup_grafana.sh
./setup_grafana.sh
```

This starts all services:
- ✅ OTEL Collector (localhost:4317, localhost:4318)
- ✅ Grafana (http://localhost:3000)
- ✅ Tempo, Prometheus, Loki (backends)

**2. Run Node.js Example App**

```bash
cd nodejs-examples
npm install
npm start
```

Your app now sends traces, metrics, and logs to OTEL Collector!

**3. View in Grafana**

Open **http://localhost:3000**
- No login required
- Go to **Dashboards** → **OTEL Overview Dashboard**
- Or use **Explore** to query traces/metrics/logs

### Option B: NGINX + Fluent Bit + OTEL

**Setup NGINX with log forwarding:**
```bash
chmod +x setup_nginx.sh
sudo ./setup_nginx.sh
```

This sets up:
- ✅ NGINX web server (port 80) with JSON logging
- ✅ Fluent Bit log forwarder
- ✅ OTEL Collector (standalone)

**Access:**
- NGINX: http://localhost
- Health: http://localhost/health
- Status: http://localhost/nginx-status

**View logs:**
```bash
tail -f /var/log/nginx-podman/access.log | jq '.'
podman logs -f otel-collector
```

## 📁 Project Structure

```
TestOTEL/
├── setup_grafana.sh              # Setup Grafana + backends (Option A)
├── setup_nginx.sh                # Setup NGINX + OTEL (Option B)
├── docker-compose.grafana.yml    # Full observability stack
├── OTEL/
│   ├── otel-config.yaml          # OTEL Collector configuration
│   ├── nginx.conf                # NGINX configuration (for Option B)
│   └── chainguard.sh             # Manual OTEL startup (if needed)
├── grafana/
│   ├── provisioning/             # Auto-configured data sources & dashboards
│   ├── dashboards/               # Pre-built OTEL dashboard
│   ├── tempo/                    # Trace backend config
│   ├── prometheus/               # Metrics backend config
│   └── loki/                     # Logs backend config
├── nodejs-examples/
│   ├── otel-setup.js             # Reusable OTEL config for Node.js
│   ├── example-app.js            # Instrumented Express.js app
│   └── package.json              # Dependencies
├── GRAFANA_GUIDE.md              # Grafana usage guide
├── NODEJS_INTEGRATION.md         # Node.js instrumentation guide
├── ARCHITECTURE.md               # Architecture details
└── README.md                     # This file
```

## 📊 Available Endpoints

After running `setup_grafana.sh`:

- **Grafana**: http://localhost:3000 (visualization)
- **Prometheus**: http://localhost:9090 (metrics query)
- **Tempo**: http://localhost:3200 (traces)
- **Loki**: http://localhost:3100 (logs)
- **OTEL gRPC**: localhost:4317
- **OTEL HTTP**: localhost:4318
- **Node.js App**: http://localhost:3001 (example app)

## 🔧 Management Commands

### View Logs
```bash
# All services
docker compose -f docker-compose.grafana.yml logs -f

# Specific service
docker compose -f docker-compose.grafana.yml logs -f otel-collector
docker compose -f docker-compose.grafana.yml logs -f grafana
```

### Restart Services
```bash
docker compose -f docker-compose.grafana.yml restart
```

### Stop Everything
```bash
docker compose -f docker-compose.grafana.yml down
```

### Complete Cleanup (removes all data)
```bash
docker compose -f docker-compose.grafana.yml down -v
```

## 📚 Documentation

- **[GRAFANA_GUIDE.md](GRAFANA_GUIDE.md)** - Complete Grafana usage guide
  - How to query traces, metrics, logs
  - Creating dashboards
  - Setting up alerts
  - Troubleshooting

- **[NODEJS_INTEGRATION.md](NODEJS_INTEGRATION.md)** - Node.js instrumentation guide
  - Installation and setup
  - Auto-instrumentation
  - Manual tracing and logging
  - Express.js examples

## 🎯 Use Cases

### Use Case 1: Monitor Node.js Applications
1. Run `./setup_grafana.sh`
2. Add OTEL to your app (see NODEJS_INTEGRATION.md)
3. Start your app
4. View telemetry in Grafana

### Use Case 2: Monitor NGINX Web Server
1. Run `sudo ./setup_nginx.sh`
   - Automatically starts Grafana stack if not running
2. NGINX serves traffic on port 80
3. Fluent Bit forwards logs to OTEL Collector
4. **View logs in Grafana Loki** at http://localhost:3000

### Use Case 3: Full Stack Monitoring
1. Run `./setup_grafana.sh` (Grafana + backends)
2. Run `sudo ./setup_nginx.sh` (detects existing stack, adds NGINX)
3. Run Node.js apps
4. **View everything in Grafana**: NGINX logs + Node.js traces/metrics/logs

## 🐛 Troubleshooting

### No Data in Grafana
```bash
# Check OTEL Collector logs
docker compose -f docker-compose.grafana.yml logs otel-collector

# Verify services are running
docker compose -f docker-compose.grafana.yml ps

# Test OTEL Collector endpoint
curl http://localhost:4318/v1/traces
```

### Node.js App Not Sending Telemetry
1. Check app logs for "OpenTelemetry initialized"
2. Verify OTEL_COLLECTOR_URL environment variable
3. Ensure OTEL packages are installed (`npm install`)

### Grafana Data Sources Not Working
1. In Grafana: Connections → Data sources → Test
2. Verify all containers on same network (`otel-network`)
3. Check container names resolve: `docker exec -it grafana ping tempo`

See **GRAFANA_GUIDE.md** for detailed troubleshooting.

## 🔧 Advanced Usage

### Custom Metrics in Node.js
```javascript
const { metrics } = require('@opentelemetry/api');
const meter = metrics.getMeter('my-app');

const counter = meter.createCounter('custom_requests');
counter.add(1, { endpoint: '/api/users' });
```

### Custom Dashboards
1. Create in Grafana UI
2. Export as JSON: Dashboard Settings → JSON Model
3. Save to `grafana/dashboards/my-dashboard.json`
4. Restart Grafana

### Enable Grafana Authentication
Edit `docker-compose.grafana.yml`:
```yaml
environment:
  - GF_AUTH_ANONYMOUS_ENABLED=false
  - GF_SECURITY_ADMIN_PASSWORD=yourpassword
```

## 🚀 Production Considerations

- Use persistent volumes for data (already configured)
- Set resource limits in docker-compose
- Enable authentication in Grafana
- Configure retention policies for Tempo/Prometheus/Loki
- Use HTTPS with proper certificates
- Set up alerting for critical metrics

## 📖 Additional Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [Prometheus Query Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)

## 📝 License

MIT
```nginx
server {
    listen 8080;
    server_name myapp.local;
    
    location /api {
        proxy_pass http://backend:3000;
        proxy_set_header X-Request-ID $request_id;
    }
}
```

Then restart NGINX:
```bash
podman restart nginx-server
```

## 🐛 Troubleshooting

### OTEL Collector Not Starting
```bash
# Check config syntax
podman run --rm -v /etc/otel-config.yaml:/config.yaml \
  otel/opentelemetry-collector:latest \
  --config /config.yaml --dry-run

## 📝 License

MIT
