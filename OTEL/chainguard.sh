#!/bin/bash

# Script to run OpenTelemetry Collector container
# Enhanced with better error handling and configuration checks

set -e

OTEL_CONFIG="/etc/otel-config.yaml"
CONTAINER_NAME="otel-collector"

# Check if config exists
if [ ! -f "$OTEL_CONFIG" ]; then
    echo "Error: OTEL config not found at $OTEL_CONFIG"
    echo "Please create the configuration file first"
    exit 1
fi

# Stop and remove existing container if running
if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping and removing existing $CONTAINER_NAME container..."
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Pull latest image
echo "Pulling latest OpenTelemetry Collector image..."
podman pull docker.io/otel/opentelemetry-collector:latest

# Run OTEL Collector
echo "Starting OpenTelemetry Collector..."
podman run -d \
  --name "$CONTAINER_NAME" \
  --network host \
  -v "$OTEL_CONFIG:/otel-config.yaml:ro" \
  --restart unless-stopped \
  docker.io/otel/opentelemetry-collector:latest \
  --config /otel-config.yaml

echo "OpenTelemetry Collector started successfully!"
echo "Container name: $CONTAINER_NAME"
echo "gRPC endpoint: localhost:4317"
echo "HTTP endpoint: localhost:4318"
echo ""
echo "View logs: podman logs -f $CONTAINER_NAME"
