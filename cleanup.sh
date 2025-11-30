#!/bin/bash
# Cleanup Script - Remove all OTEL/Grafana/NGINX containers and data

set -e

echo "🗑️  Cleaning up all observability containers and data..."
echo "=========================================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if podman-compose exists
if command -v podman-compose &> /dev/null; then
    echo -e "${YELLOW}🛑 Stopping Grafana stack (Podman Compose)...${NC}"
    if [ -f "docker-compose.grafana.yml" ]; then
        podman-compose -f docker-compose.grafana.yml down -v 2>/dev/null || true
        echo -e "${GREEN}✅ Podman Compose stack removed${NC}"
    fi
fi

# Stop and remove individual containers
echo -e "${YELLOW}🛑 Stopping containers...${NC}"
CONTAINERS=(
    "nginx-server"
    "fluent-bit-nginx"
    "otel-collector"
    "otelcol-contrib"
    "grafana"
    "tempo"
    "prometheus"
    "loki"
)

for container in "${CONTAINERS[@]}"; do
    if podman ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${container}$"; then
        echo -e "${YELLOW}  Removing: ${container}${NC}"
        podman stop "$container" 2>/dev/null || true
        podman rm -f "$container" 2>/dev/null || true
    fi
done

echo -e "${GREEN}✅ All containers removed${NC}"

# Remove Podman volumes
echo -e "${YELLOW}🗑️  Removing Podman volumes...${NC}"
podman volume rm grafana-data tempo-data prometheus-data loki-data 2>/dev/null || true
echo -e "${GREEN}✅ Podman volumes removed${NC}"

# Remove configuration files
echo -e "${YELLOW}🗑️  Removing configuration files...${NC}"
sudo rm -rf /etc/nginx-podman 2>/dev/null || true
sudo rm -rf /etc/fluent-bit 2>/dev/null || true
sudo rm -f /etc/otel-config.yaml 2>/dev/null || true
echo -e "${GREEN}✅ Configuration files removed${NC}"

# Remove log files
echo -e "${YELLOW}🗑️  Removing log files...${NC}"
sudo rm -rf /var/log/nginx-podman 2>/dev/null || true
echo -e "${GREEN}✅ Log files removed${NC}"

# Remove web root
echo -e "${YELLOW}🗑️  Removing web root...${NC}"
sudo rm -rf /var/www/html-podman 2>/dev/null || true
echo -e "${GREEN}✅ Web root removed${NC}"

# Show remaining containers
echo ""
echo -e "${YELLOW}📊 Remaining Podman containers:${NC}"
podman ps -a 2>/dev/null || echo "  None"

echo ""
echo -e "${GREEN}🎉 Cleanup complete!${NC}"
echo -e "${YELLOW}All observability containers, volumes, and configurations removed.${NC}"
