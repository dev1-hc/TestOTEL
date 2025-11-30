#!/bin/bash
# Grafana Stack Setup Script
# Sets up Grafana + Tempo + Prometheus + Loki + OTEL Collector

set -e

echo "🚀 Setting up Grafana Observability Stack..."
echo "=============================================="

# Check if Podman is available
if ! command -v podman &> /dev/null; then
    echo "❌ Podman not found. Please install it."
    echo "   sudo apt-get update && sudo apt-get install -y podman"
    exit 1
fi

# Check if podman-compose is installed
if ! command -v podman-compose &> /dev/null; then
    echo "❌ podman-compose not found. Installing..."
    
    # Install pip3 if not available
    if ! command -v pip3 &> /dev/null; then
        echo "📦 Installing python3-pip..."
        sudo apt-get update
        sudo apt-get install -y python3-pip
    fi
    
    pip3 install --break-system-packages podman-compose
fi

echo "📦 Using Podman"

# Create necessary directories
echo "📁 Creating configuration directories..."
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/dashboards
mkdir -p grafana/tempo
mkdir -p grafana/prometheus
mkdir -p grafana/loki
mkdir -p OTEL

# Stop any existing containers
echo "🛑 Stopping existing containers..."
podman-compose -f docker-compose.grafana.yml down 2>/dev/null || true

# Start the stack
echo "🔧 Starting Grafana stack..."
podman-compose -f docker-compose.grafana.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check service health
echo ""
echo "🔍 Checking service status..."
podman ps --filter "name=grafana" --filter "name=tempo" --filter "name=prometheus" --filter "name=loki" --filter "name=otel-collector" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "✅ Grafana Observability Stack is running!"
echo ""
echo "📊 Access Points:"
echo "   Grafana:    http://localhost:3000 (No login required)"
echo "   Prometheus: http://localhost:9090"
echo "   Tempo:      http://localhost:3200"
echo "   Loki:       http://localhost:3100"
echo ""
echo "🔌 OTEL Collector Endpoints:"
echo "   gRPC:       localhost:4317"
echo "   HTTP:       localhost:4318"
echo "   Metrics:    localhost:8889"
echo ""
echo "💡 Next Steps:"
echo "   1. Open Grafana at http://localhost:3000"
echo "   2. Go to Explore to query traces, metrics, and logs"
echo "   3. Run your Node.js app to send telemetry"
echo "   4. View logs in Loki, metrics in Prometheus, traces in Tempo"
echo ""
echo "📝 To view logs: podman-compose -f docker-compose.grafana.yml logs -f [service-name]"
echo "🛑 To stop:      podman-compose -f docker-compose.grafana.yml down"
echo "🗑️  To cleanup:   podman-compose -f docker-compose.grafana.yml down -v"
