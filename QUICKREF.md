# NGINX + OTEL Quick Reference

## 🚀 Setup (First Time)

```bash
chmod +x setup_complete.sh
sudo ./setup_complete.sh
```

## 📊 Monitor & Analyze

```bash
./monitor.sh
```

| Option | Action |
|--------|--------|
| **8** | Analyze logs (endpoints, stats, response times) |
| **9** | Show detailed OTEL output |
| **10** | View NGINX metrics (stub_status) |
| **3** | Live tail access logs (formatted) |
| **7** | Generate test traffic |
| **1** | OTEL Collector logs (live) |
| **6** | Container status |

## 🧪 Test Endpoints

```bash
curl http://localhost              # Main page
curl http://localhost/health       # Health check (200 OK)
curl http://localhost/nginx-status # NGINX metrics
```

## 🔍 View Logs Directly

```bash
# Access logs (JSON)
tail -f /var/log/nginx-podman/access.log

# OTEL Collector
podman logs -f otel-collector

# Fluent Bit (forwarder)
podman logs -f fluent-bit-nginx

# NGINX container
podman logs -f nginx-server
```

## 📈 Analyze Logs with jq

```bash
# Top endpoints
jq -r '.request | split(" ")[1]' /var/log/nginx-podman/access.log | sort | uniq -c | sort -rn

# Status codes
jq -r '.status' /var/log/nginx-podman/access.log | sort | uniq -c

# Average response time
jq -r '.request_time | tonumber' /var/log/nginx-podman/access.log | awk '{sum+=$1; n++} END {print sum/n}'

# Client IPs
jq -r '.remote_addr' /var/log/nginx-podman/access.log | sort | uniq -c | sort -rn
```

## 🐳 Container Management

```bash
# View all containers
podman ps

# Restart a container
podman restart nginx-server
podman restart otel-collector
podman restart fluent-bit-nginx

# Stop all
podman stop nginx-server otel-collector fluent-bit-nginx

# View container logs
podman logs -f <container-name>
```

## 📁 Important Locations

| Type | Location |
|------|----------|
| NGINX config | `/etc/nginx-podman/nginx.conf` |
| OTEL config | `/etc/otel-config.yaml` |
| Fluent Bit config | `/etc/fluent-bit/fluent-bit.conf` |
| Access logs | `/var/log/nginx-podman/access.log` |
| Error logs | `/var/log/nginx-podman/error.log` |
| Web root | `/var/www/html-podman/` |

## 🧹 Cleanup

```bash
./cleanup.sh
```

**Warning:** This removes:
- All containers (nginx-server, otel-collector, fluent-bit-nginx)
- All configuration files
- All logs
- Optionally: container images

## 🔧 Troubleshooting

### Logs not appearing?
```bash
# Check if log files exist
ls -lh /var/log/nginx-podman/

# Check volume mounts
podman inspect nginx-server | grep -A 5 Mounts

# Run diagnostics
./diagnose_logs.sh
```

### Fluent Bit parser error?
```bash
# Fix parser configuration
sudo ./fix_fluent_bit_parser.sh
```

### OTEL not receiving data?
```bash
# Check OTEL is listening
curl http://localhost:4318/v1/logs -X POST -H "Content-Type: application/json" -d '{}'

# Check Fluent Bit is forwarding
podman logs fluent-bit-nginx | grep output
```

## 🎯 Common Tasks

### Generate Test Traffic
```bash
for i in {1..50}; do curl -s http://localhost/ >/dev/null; done
```

### View Live Traffic
```bash
tail -f /var/log/nginx-podman/access.log | jq -r '"[\(.time_local)] \(.request) → \(.status) (\(.request_time)s)"'
```

### Check What's Being Logged to OTEL
```bash
podman logs --tail 20 otel-collector | grep "log records"
```

### Export Logs for Analysis
```bash
cp /var/log/nginx-podman/access.log ./nginx-access-$(date +%Y%m%d).log
```

## 📊 What the Logs Tell You

Access logs include:
- **Endpoint called**: Which URLs are being hit
- **Status codes**: Success (200), errors (404, 500, etc.)
- **Response times**: How fast your server responds
- **Client IPs**: Who's accessing your server
- **User agents**: What browsers/tools are used
- **Request methods**: GET, POST, etc.

Use option **8** in `monitor.sh` to see all this analyzed automatically!
