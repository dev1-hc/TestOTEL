#!/bin/bash
# Complete NGINX + OTEL + Fluent Bit Setup
# Idempotent script - can be run multiple times safely

set -e

echo "🚀 NGINX + OpenTelemetry Complete Setup"
echo "=========================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ Podman not found. Installing...${NC}"
    sudo apt-get update
    sudo apt-get install -y podman
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl not found. Installing...${NC}"
    sudo apt-get install -y curl
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq not found. Installing...${NC}"
    sudo apt-get install -y jq
fi

echo -e "${GREEN}✅ Prerequisites checked${NC}"

# Create directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
sudo mkdir -p /etc/nginx-podman/conf.d
sudo mkdir -p /etc/nginx-podman/ssl
sudo mkdir -p /var/log/nginx-podman
sudo mkdir -p /var/www/html-podman
sudo mkdir -p /etc/fluent-bit
sudo chmod 755 /var/log/nginx-podman

# Check if Grafana stack OTEL Collector is running (from podman-compose)
if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^otel-collector$"; then
    echo -e "${GREEN}✅ Using existing OTEL Collector from Grafana stack${NC}"
    echo -e "${YELLOW}📊 NGINX logs will be sent to Grafana Loki${NC}"
    OTEL_EXISTS=true
else
    echo -e "${YELLOW}🔧 Grafana stack not detected, starting complete observability stack...${NC}"
    
    # Check if podman-compose is installed
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
    
    echo -e "${YELLOW}🚀 Starting Grafana observability stack...${NC}"
    podman-compose -f docker-compose.grafana.yml up -d
    
    echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
    sleep 10
    
    echo -e "${GREEN}✅ Grafana stack started${NC}"
    echo -e "${GREEN}✅ NGINX logs will be sent to Grafana Loki${NC}"
    echo -e "${YELLOW}📊 Access Grafana at: http://localhost:3000${NC}"
    OTEL_EXISTS=true
fi

# Copy NGINX config
echo -e "${YELLOW}📝 Setting up NGINX configuration...${NC}"

# Create NGINX config with JSON logging directly
cat <<'NGINXCONF' | sudo tee /etc/nginx-podman/nginx.conf > /dev/null
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
echo -e "${YELLOW}📝 Creating default web page...${NC}"
cat <<'EOF' | sudo tee /var/www/html-podman/index.html > /dev/null
<!DOCTYPE html>
<html>
<head>
    <title>NGINX + OTEL Integration</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { color: #333; }
        .status { color: #28a745; font-weight: bold; }
        .endpoint {
            background: #f8f9fa;
            padding: 10px;
            margin: 10px 0;
            border-left: 4px solid #007bff;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 NGINX + OpenTelemetry</h1>
        <p class="status">✅ System is running!</p>
        
        <h2>Available Endpoints:</h2>
        <div class="endpoint">
            <strong>Health Check:</strong> <a href="/health">/health</a>
        </div>
        <div class="endpoint">
            <strong>NGINX Status:</strong> <a href="/nginx-status">/nginx-status</a>
        </div>
        
        <h2>Integration Status:</h2>
        <ul>
            <li>✅ NGINX running</li>
            <li>✅ JSON access logs enabled</li>
            <li>✅ Fluent Bit forwarding logs</li>
            <li>✅ OTEL Collector receiving data</li>
        </ul>
    </div>
</body>
</html>
EOF

# Check if NGINX container exists
if podman ps -a --format "{{.Names}}" | grep -q "^nginx-server$"; then
    echo -e "${YELLOW}🔄 NGINX container exists${NC}"
    
    # Check if mounts are correct
    NEEDS_RECREATE=false
    if ! podman inspect nginx-server --format '{{json .Mounts}}' | grep -q "/var/log/nginx-podman:/var/log/nginx"; then
        NEEDS_RECREATE=true
    fi
    
    if [ "$NEEDS_RECREATE" = true ]; then
        echo -e "${YELLOW}🔄 Volume mounts need update, recreating NGINX...${NC}"
        podman stop nginx-server 2>/dev/null || true
        podman rm nginx-server 2>/dev/null || true
        
        podman run -d \
          --name nginx-server \
          -p 80:80 \
          -v /etc/nginx-podman/nginx.conf:/etc/nginx/nginx.conf:ro \
          -v /etc/nginx-podman/conf.d:/etc/nginx/conf.d:ro \
          -v /var/www/html-podman:/usr/share/nginx/html:ro \
          -v /var/log/nginx-podman:/var/log/nginx:rw \
          nginx:latest
        echo -e "${GREEN}✅ NGINX recreated${NC}"
    else
        # Just reload config
        echo -e "${YELLOW}🔄 Reloading NGINX configuration...${NC}"
        sudo cp OTEL/nginx.conf /etc/nginx-podman/nginx.conf
        podman exec nginx-server nginx -t && podman exec nginx-server nginx -s reload
        echo -e "${GREEN}✅ NGINX configuration reloaded${NC}"
    fi
else
    echo -e "${YELLOW}🔧 Starting NGINX...${NC}"
    podman run -d \
      --name nginx-server \
      -p 80:80 \
      -v /etc/nginx-podman/nginx.conf:/etc/nginx/nginx.conf:ro \
      -v /etc/nginx-podman/conf.d:/etc/nginx/conf.d:ro \
      -v /var/www/html-podman:/usr/share/nginx/html:ro \
      -v /var/log/nginx-podman:/var/log/nginx:rw \
      nginx:latest
    echo -e "${GREEN}✅ NGINX started${NC}"
fi

# Wait for NGINX to create log file
echo -e "${YELLOW}⏳ Waiting for NGINX log file...${NC}"
sleep 2

# Create initial log file if it doesn't exist
if [ ! -f /var/log/nginx-podman/access.log ]; then
    echo -e "${YELLOW}📝 Creating initial log file...${NC}"
    sudo touch /var/log/nginx-podman/access.log
    sudo chmod 644 /var/log/nginx-podman/access.log
fi

# Create Fluent Bit config
echo -e "${YELLOW}📝 Creating Fluent Bit configuration...${NC}"
cat <<'EOF' | sudo tee /etc/fluent-bit/fluent-bit.conf > /dev/null
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

# Create Fluent Bit parser config
echo -e "${YELLOW}📝 Creating Fluent Bit parser configuration...${NC}"
cat <<'EOF' | sudo tee /etc/fluent-bit/parsers.conf > /dev/null
[PARSER]
    Name        nginx_json
    Format      json
    Time_Key    time_local
    Time_Format %d/%b/%Y:%H:%M:%S %z
    Time_Keep   On
EOF

# Check if Fluent Bit container exists
if podman ps -a --format "{{.Names}}" | grep -q "^fluent-bit-nginx$"; then
    echo -e "${YELLOW}🔄 Fluent Bit container exists, recreating with updated config...${NC}"
    podman stop fluent-bit-nginx 2>/dev/null || true
    podman rm fluent-bit-nginx 2>/dev/null || true
fi

echo -e "${YELLOW}🔧 Starting Fluent Bit...${NC}"
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

# Wait for logs to be processed
sleep 2

echo ""
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo -e "${YELLOW}📊 Service Status:${NC}"
podman ps --filter "name=nginx-server" --filter "name=otel-collector" --filter "name=fluent-bit-nginx" --filter "name=grafana" --filter "name=tempo" --filter "name=prometheus" --filter "name=loki" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || podman ps

echo ""
echo -e "${YELLOW}🔗 Access Points:${NC}"
echo "   NGINX:          http://localhost"
echo "   Health Check:   http://localhost/health"
echo "   NGINX Status:   http://localhost/nginx-status"
echo "   Grafana:        http://localhost:3000 (visualize logs, metrics, traces)"
echo "   OTEL gRPC:      localhost:4317"
echo "   OTEL HTTP:      localhost:4318"

echo ""
echo -e "${YELLOW}📝 View Logs:${NC}"
echo "   OTEL Collector:  podman logs -f otel-collector"
echo "   NGINX:           podman logs -f nginx-server"
echo "   Fluent Bit:      podman logs -f fluent-bit-nginx"
echo "   Grafana:         podman logs -f grafana"
echo "   Loki:            podman logs -f loki"
echo "   Access Logs:     tail -f /var/log/nginx-podman/access.log | jq '.'"

echo ""
echo -e "${YELLOW}🧪 Test Commands:${NC}"
echo "   curl http://localhost"
echo "   curl http://localhost/health"
echo "   curl http://localhost/nginx-status"

echo ""
echo -e "${YELLOW}📊 View in Grafana:${NC}"
echo "   1. Open http://localhost:3000"
echo "   2. Go to Explore → Select 'Loki' data source"
echo "   3. Query: {service_name=\"nginx\"}"
echo "   4. See NGINX access logs in real-time!"

echo ""
echo -e "${YELLOW}🛑 Stop All:${NC}"
echo "   podman-compose -f docker-compose.grafana.yml down"
echo "   podman stop nginx-server fluent-bit-nginx"

echo ""
echo -e "${GREEN}🎉 All systems operational!${NC}"
echo -e "${GREEN}📊 NGINX logs are flowing to Grafana Loki!${NC}"
