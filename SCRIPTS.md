# Script Reference Guide

## 📜 Available Scripts

### 🚀 Setup & Installation

#### `quick_start.sh` - Quick Start Script
**Purpose**: Automated one-command setup for the entire integration  
**Usage**: 
```bash
chmod +x quick_start.sh
./quick_start.sh
```
**What it does**:
- Copies OTEL configuration to `/etc/otel-config.yaml`
- Starts OTEL Collector container
- Runs the full integration script

---

#### `integrate_nginx_otel.sh` - Main Integration Script
**Purpose**: Complete integration setup with all components  
**Usage**: 
```bash
chmod +x integrate_nginx_otel.sh
sudo ./integrate_nginx_otel.sh
```
**What it does**:
- Creates OTEL configuration if not exists
- Starts OTEL Collector container
- Creates NGINX configuration with JSON logging
- Creates and starts NGINX container
- Sets up Fluent Bit for log forwarding
- Creates Fluent Bit container
- Tests the integration
- Displays comprehensive summary

**Components Created**:
- OTEL Collector (host network, ports 4317, 4318)
- NGINX (host network, port 80)
- Fluent Bit (log forwarder)

---

#### `OTEL/chainguard.sh` - OTEL Collector Starter
**Purpose**: Standalone script to start OTEL Collector  
**Usage**: 
```bash
cd OTEL
chmod +x chainguard.sh
./chainguard.sh
```
**What it does**:
- Checks for OTEL configuration file
- Stops existing OTEL container if running
- Pulls latest OTEL Collector image
- Starts OTEL Collector with host network
- Displays connection information

---

#### `setup.ps1` - Windows PowerShell Setup
**Purpose**: Windows-friendly setup script  
**Usage**: 
```powershell
.\setup.ps1
```
**What it does**:
- Detects if running in WSL
- Provides instructions for Podman Desktop
- Launches WSL and runs quick_start.sh
- Makes all scripts executable

---

### 🧪 Testing & Monitoring

#### `test_integration.sh` - Integration Test Script
**Purpose**: Comprehensive testing of the integration  
**Usage**: 
```bash
chmod +x test_integration.sh
./test_integration.sh
```
**What it does**:
- Checks container status
- Tests all NGINX endpoints (/, /health, /nginx-status)
- Generates 50 test requests
- Displays recent NGINX logs
- Shows OTEL Collector logs
- Displays Fluent Bit status
- Provides summary and next steps

**Tests Performed**:
- Homepage (HTTP 200)
- Health endpoint
- NGINX status endpoint
- Log processing pipeline

---

#### `monitor.sh` - Interactive Telemetry Monitor
**Purpose**: Interactive menu for viewing live telemetry  
**Usage**: 
```bash
chmod +x monitor.sh
./monitor.sh
```
**Menu Options**:
1. OTEL Collector logs (live)
2. NGINX container logs (live)
3. NGINX access logs (live, JSON formatted)
4. NGINX error logs (live)
5. Fluent Bit logs (live)
6. Container status
7. Generate test traffic
8. NGINX metrics (stub_status)
9. Exit

**Interactive Features**:
- Live log tailing
- Traffic generation with custom count
- Real-time metrics viewing
- Status dashboard

---

### 🧹 Cleanup

#### `cleanup.sh` - Complete Cleanup Script
**Purpose**: Remove all containers, configs, and optionally images  
**Usage**: 
```bash
chmod +x cleanup.sh
./cleanup.sh
```
**Cleanup Options**:
1. **Containers**: Stop and remove all containers
2. **Files**: Remove configurations and logs
3. **Images**: Remove downloaded container images

**Interactive Prompts**:
- Confirm container removal
- Confirm file cleanup
- Confirm image removal

**Removes**:
- Containers: nginx-server, otel-collector, fluent-bit-nginx
- Configs: /etc/nginx-podman, /etc/fluent-bit, /etc/otel-config.yaml
- Logs: /var/log/nginx-podman
- Web root: /var/www/html-podman
- Systemd service: /etc/systemd/system/nginx-podman.service

---

## 📊 Configuration Files

### `OTEL/otel-config.yaml` - OTEL Collector Configuration
**Purpose**: Configuration for OpenTelemetry Collector  
**Key Components**:
- **Receivers**: OTLP (gRPC on 4317, HTTP on 4318)
- **Processors**: batch, memory_limiter, attributes
- **Exporters**: debug, logging
- **Pipelines**: traces, metrics, logs

---

### `OTEL/nginx.conf` - NGINX Configuration (Generated)
**Purpose**: NGINX configuration with OTEL-ready logging  
**Features**:
- JSON-formatted access logs
- Request timing metrics
- IPv4 and IPv6 support
- Health check endpoint (/health)
- Status endpoint (/nginx-status)
- Custom headers (X-Request-ID, X-Server-Name)

---

## 🔄 Typical Workflows

### Initial Setup
```bash
# 1. Clone or navigate to project
cd /path/to/TestOTEL

# 2. Make scripts executable
chmod +x *.sh OTEL/*.sh

# 3. Run quick start
./quick_start.sh

# 4. Test the integration
./test_integration.sh
```

### Daily Monitoring
```bash
# Option 1: Interactive monitor
./monitor.sh

# Option 2: Manual log viewing
podman logs -f otel-collector
tail -f /var/log/nginx-podman/access.log
```

### Generate Test Traffic
```bash
# Using monitor script
./monitor.sh
# Select option 7

# Or manually
for i in {1..100}; do curl -s http://localhost/ > /dev/null; done
```

### View Telemetry
```bash
# OTEL Collector
podman logs -f otel-collector

# NGINX Access Logs (JSON)
tail -f /var/log/nginx-podman/access.log | jq '.'

# Fluent Bit
podman logs -f fluent-bit-nginx
```

### Complete Cleanup and Reinstall
```bash
# 1. Full cleanup
./cleanup.sh
# Answer 'y' to all prompts

# 2. Fresh install
./quick_start.sh
```

---

## 🎯 Script Decision Tree

```
Need to set up?
├─ First time? → quick_start.sh
├─ Manual control? → integrate_nginx_otel.sh
└─ Windows? → setup.ps1

Need to monitor?
├─ Interactive? → monitor.sh
├─ Quick test? → test_integration.sh
└─ Manual? → podman logs -f <container>

Need to clean up?
└─ cleanup.sh

Need just OTEL?
└─ OTEL/chainguard.sh
```

---

## 💡 Tips

### Make All Scripts Executable at Once
```bash
chmod +x *.sh OTEL/*.sh
```

### Quick Status Check
```bash
podman ps
```

### Restart a Container
```bash
podman restart nginx-server
podman restart otel-collector
```

### View All Logs
```bash
# Combined view (requires tmux or screen)
tmux new-session \; \
  send-keys 'podman logs -f otel-collector' C-m \; \
  split-window -h \; \
  send-keys 'podman logs -f nginx-server' C-m \; \
  split-window -v \; \
  send-keys 'tail -f /var/log/nginx-podman/access.log' C-m
```

### Send Specific Log Pattern
```bash
# Generate 404 errors
curl http://localhost/nonexistent

# Generate slow requests
curl http://localhost/?sleep=5
```

---

## 🐛 Troubleshooting

### Script Permission Denied
```bash
chmod +x <script-name>.sh
```

### Container Already Exists
```bash
podman rm -f <container-name>
# Then rerun the script
```

### Port Already in Use
```bash
# Find what's using the port
sudo lsof -i :80
sudo lsof -i :4317

# Or stop the conflicting service
```

### OTEL Config Not Found
```bash
# Copy from project
sudo cp OTEL/otel-config.yaml /etc/otel-config.yaml
```

---

## 📚 Additional Resources

- Run any script with `bash <script>.sh` if execute permission issues
- Check script contents with `cat <script>.sh`
- Edit configs with `nano` or `vim`
- All scripts include built-in help and error messages

---

**Quick Reference Card**

| Task | Command |
|------|---------|
| Setup | `./quick_start.sh` |
| Test | `./test_integration.sh` |
| Monitor | `./monitor.sh` |
| Cleanup | `./cleanup.sh` |
| OTEL Only | `./OTEL/chainguard.sh` |
| Status | `podman ps` |
| OTEL Logs | `podman logs -f otel-collector` |
| NGINX Logs | `tail -f /var/log/nginx-podman/access.log` |
