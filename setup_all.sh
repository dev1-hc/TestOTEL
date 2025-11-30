#!/bin/bash
# Complete Observability Stack Setup
# Sets up OTEL Collector + Grafana + NGINX with port conflict detection

set -e

echo "🚀 Complete Observability Stack Setup"
echo "======================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root for NGINX setup
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run with sudo for NGINX setup${NC}"
    exit 1
fi

# Function to check if port is in use
check_port() {
    local port=$1
    local service=$2
    
    if ss -tuln | grep -q ":${port} "; then
        echo -e "${RED}❌ Port ${port} (${service}) is already in use!${NC}"
        echo -e "${YELLOW}   Find process: sudo lsof -i :${port}${NC}"
        echo -e "${YELLOW}   Kill process: sudo kill -9 \$(sudo lsof -t -i:${port})${NC}"
        return 1
    fi
    return 0
}

# Check all required ports
echo -e "${YELLOW}🔍 Checking ports availability...${NC}"
PORTS_OK=true

check_port 80 "NGINX" || PORTS_OK=false
check_port 3000 "Grafana" || PORTS_OK=false
check_port 3100 "Loki" || PORTS_OK=false
check_port 3200 "Tempo" || PORTS_OK=false
check_port 4317 "OTEL gRPC" || PORTS_OK=false
check_port 4318 "OTEL HTTP" || PORTS_OK=false
check_port 8889 "Prometheus exporter" || PORTS_OK=false
check_port 9090 "Prometheus" || PORTS_OK=false

if [ "$PORTS_OK" = false ]; then
    echo ""
    echo -e "${RED}❌ Port conflicts detected. Please free up the ports above.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All ports available${NC}"

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}📦 Installing curl...${NC}"
    apt-get update
    apt-get install -y curl
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}📦 Installing jq...${NC}"
    apt-get update
    apt-get install -y jq
fi

# Check Podman installation
if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Podman not found. Installing...${NC}"
    apt-get update
    apt-get install -y podman
fi

if ! command -v podman-compose &> /dev/null; then
    echo -e "${YELLOW}📦 Installing podman-compose...${NC}"
    
    # Install pip3 if not available
    if ! command -v pip3 &> /dev/null; then
        echo -e "${YELLOW}📦 Installing python3-pip...${NC}"
        apt-get update
        apt-get install -y python3-pip
    fi
    
    pip3 install --break-system-packages podman-compose
fi

echo -e "${GREEN}✅ Using Podman${NC}"

# Start Grafana Stack
echo ""
echo -e "${YELLOW}🚀 Starting Grafana Observability Stack...${NC}"
echo -e "${YELLOW}   This includes: OTEL Collector, Grafana, Tempo, Prometheus, Loki${NC}"

podman-compose -f docker-compose.grafana.yml up -d

echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 10

echo -e "${GREEN}✅ Grafana stack started${NC}"

# Setup NGINX
echo ""
echo -e "${YELLOW}🔧 Setting up NGINX...${NC}"

# Create directories
mkdir -p /etc/nginx-podman/conf.d
mkdir -p /etc/nginx-podman/ssl
mkdir -p /var/log/nginx-podman
mkdir -p /var/www/html-podman
mkdir -p /etc/fluent-bit
chmod 755 /var/log/nginx-podman

# Create NGINX config with JSON logging directly
cat <<'NGINXCONF' > /etc/nginx-podman/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    # JSON log format for structured logging
    log_format json_combined escape=json
    '{'
        '"time_local":"$time_local",'
        '"remote_addr":"$remote_addr",'
        '"remote_user":"$remote_user",'
        '"request":"$request",'
        '"status":"$status",'
        '"body_bytes_sent":"$body_bytes_sent",'
        '"request_time":"$request_time",'
        '"http_referrer":"$http_referer",'
        '"http_user_agent":"$http_user_agent",'
        '"http_x_forwarded_for":"$http_x_forwarded_for",'
        '"upstream_response_time":"$upstream_response_time",'
        '"upstream_addr":"$upstream_addr",'
        '"upstream_status":"$upstream_status"'
    '}';

    access_log /var/log/nginx/access.log json_combined;
    error_log /var/log/nginx/error.log notice;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 4096;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen 80;
        listen [::]:80;
        server_name localhost;

        add_header X-Request-ID $request_id always;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        location /nginx-status {
            stub_status on;
            access_log off;
        }

        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
    }
}
NGINXCONF

# Create default index.html
cat <<'EOF' > /var/www/html-podman/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Complete Observability Stack</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 { color: #333; margin-bottom: 10px; }
        .status { color: #28a745; font-weight: bold; font-size: 18px; }
        .endpoint {
            background: #f8f9fa;
            padding: 15px;
            margin: 10px 0;
            border-left: 4px solid #007bff;
            border-radius: 4px;
        }
        .endpoint strong { color: #007bff; }
        a { color: #007bff; text-decoration: none; }
        a:hover { text-decoration: underline; }
        ul { line-height: 2; }
        .service { color: #6c757d; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 Complete Observability Stack</h1>
        <p class="status">✅ All Systems Operational!</p>
        
        <h2>🌐 Web Endpoints:</h2>
        <div class="endpoint">
            <strong>Home:</strong> <a href="/">Main Page</a>
        </div>
        <div class="endpoint">
            <strong>Health Check:</strong> <a href="/health">/health</a>
        </div>
        <div class="endpoint">
            <strong>NGINX Status:</strong> <a href="/nginx-status">/nginx-status</a>
        </div>
        
        <h2>📊 Observability Services:</h2>
        <div class="endpoint">
            <strong>Grafana:</strong> <a href="http://localhost:3000" target="_blank">http://localhost:3000</a>
            <span class="service">(Visualization)</span>
        </div>
        <div class="endpoint">
            <strong>Prometheus:</strong> <a href="http://localhost:9090" target="_blank">http://localhost:9090</a>
            <span class="service">(Metrics)</span>
        </div>
        
        <h2>🔧 Integration Status:</h2>
        <ul>
            <li>✅ NGINX running (port 80)</li>
            <li>✅ OTEL Collector receiving (4317, 4318)</li>
            <li>✅ Grafana visualizing (3000)</li>
            <li>✅ Tempo storing traces (3200)</li>
            <li>✅ Prometheus storing metrics (9090)</li>
            <li>✅ Loki storing logs (3100)</li>
            <li>✅ Fluent Bit forwarding NGINX logs</li>
        </ul>
        
        <h2>🚀 Next Steps:</h2>
        <ol>
            <li>Open Grafana at <a href="http://localhost:3000" target="_blank">localhost:3000</a></li>
            <li>Go to <strong>Explore</strong> → Select <strong>Loki</strong></li>
            <li>Query: <code>{service_name="nginx"}</code></li>
            <li>Run your Node.js apps (see NODEJS_INTEGRATION.md)</li>
        </ol>
    </div>
</body>
</html>
EOF

# Start NGINX
if podman ps -a --format "{{.Names}}" | grep -q "^nginx-server$"; then
    echo -e "${YELLOW}🔄 Removing existing NGINX container...${NC}"
    podman stop nginx-server 2>/dev/null || true
    podman rm nginx-server 2>/dev/null || true
fi

podman run -d \
  --name nginx-server \
  -p 80:80 \
  -v /etc/nginx-podman/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /etc/nginx-podman/conf.d:/etc/nginx/conf.d:ro \
  -v /var/www/html-podman:/usr/share/nginx/html:ro \
  -v /var/log/nginx-podman:/var/log/nginx:rw \
  nginx:latest

echo -e "${GREEN}✅ NGINX started${NC}"

# Wait for NGINX to create log file
sleep 2
if [ ! -f /var/log/nginx-podman/access.log ]; then
    touch /var/log/nginx-podman/access.log
    chmod 644 /var/log/nginx-podman/access.log
fi

# Setup Fluent Bit
echo -e "${YELLOW}🔧 Setting up Fluent Bit...${NC}"

cat <<'EOF' > /etc/fluent-bit/fluent-bit.conf
[SERVICE]
    Flush        5
    Daemon       Off
    Log_Level    info
    Parsers_File parsers.conf

[INPUT]
    Name              tail
    Path              /var/log/nginx/access.log
    Tag               nginx.access
    Parser            nginx_json
    Refresh_Interval  5
    Read_from_Head    True

[OUTPUT]
    Name   opentelemetry
    Match  *
    Host   host.containers.internal
    Port   4318
    Logs_uri /v1/logs
    Log_response_payload True
    Tls    Off
    add_label service.name nginx
    add_label deployment.environment production
EOF

cat <<'EOF' > /etc/fluent-bit/parsers.conf
[PARSER]
    Name        nginx_json
    Format      json
    Time_Key    time_local
    Time_Format %d/%b/%Y:%H:%M:%S %z
    Time_Keep   On
EOF

# Start Fluent Bit
if podman ps -a --format "{{.Names}}" | grep -q "^fluent-bit-nginx$"; then
    echo -e "${YELLOW}🔄 Removing existing Fluent Bit container...${NC}"
    podman stop fluent-bit-nginx 2>/dev/null || true
    podman rm fluent-bit-nginx 2>/dev/null || true
fi

podman run -d \
  --name fluent-bit-nginx \
  -v /etc/fluent-bit/fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro \
  -v /etc/fluent-bit/parsers.conf:/fluent-bit/etc/parsers.conf:ro \
  -v /var/log/nginx-podman:/var/log/nginx:ro \
  fluent/fluent-bit:latest

echo -e "${GREEN}✅ Fluent Bit started${NC}"

# Generate test traffic
echo -e "${YELLOW}🧪 Generating test traffic...${NC}"
sleep 3
curl -s http://localhost/ > /dev/null || true
curl -s http://localhost/health > /dev/null || true
curl -s http://localhost/nginx-status > /dev/null || true

sleep 2

# Display results
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Complete Observability Stack Running!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📊 Container Status:${NC}"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "grafana|tempo|prometheus|loki|otel-collector|nginx-server|fluent-bit-nginx" || podman ps

echo ""
echo -e "${YELLOW}🌐 Access Points:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}🌐 NGINX:${NC}          http://localhost"
echo -e "  ${GREEN}❤️  Health:${NC}         http://localhost/health"
echo -e "  ${GREEN}📊 Grafana:${NC}        http://localhost:3000 ${YELLOW}(no login)${NC}"
echo -e "  ${GREEN}📈 Prometheus:${NC}     http://localhost:9090"
echo -e "  ${GREEN}🔧 OTEL gRPC:${NC}      localhost:4317"
echo -e "  ${GREEN}🔧 OTEL HTTP:${NC}      localhost:4318"

echo ""
echo -e "${YELLOW}📝 View Real-time Logs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NGINX Logs:      tail -f /var/log/nginx-podman/access.log | jq '.'"
echo "  OTEL Collector:  podman logs -f otel-collector"
echo "  Fluent Bit:      podman logs -f fluent-bit-nginx"
echo "  Grafana:         podman logs -f grafana"
echo "  Tempo:           podman logs -f tempo"
echo "  Prometheus:      podman logs -f prometheus"
echo "  Loki:            podman logs -f loki"

echo ""
echo -e "${YELLOW}🎯 Quick Start Guide:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Open Grafana:     http://localhost:3000"
echo "  2. Go to: Explore → Select 'Loki'"
echo "  3. Query: {service_name=\"nginx\"}"
echo "  4. Generate traffic: curl http://localhost"
echo "  5. See logs appear in Grafana!"
echo ""
echo "  For Node.js apps:"
echo "  cd nodejs-examples && npm install && npm start"
echo "  Then view traces in Grafana Explore → Tempo"

echo ""
echo -e "${YELLOW}🛑 Management Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Stop all:    podman-compose -f docker-compose.grafana.yml down"
echo "               podman stop nginx-server fluent-bit-nginx"
echo "  Cleanup:     ./cleanup.sh"
echo "  Restart:     ./setup_all.sh"

echo ""
echo -e "${GREEN}🎉 Everything is ready! Start exploring your telemetry!${NC}"
echo ""
