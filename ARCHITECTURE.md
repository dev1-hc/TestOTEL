# Architecture Overview - NGINX + OTEL Integration

## 🏗️ High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                        HOST SYSTEM (Linux/WSL)                      │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    PODMAN HOST NETWORK                        │  │
│  │                                                                │  │
│  │  ┌─────────────────┐         ┌──────────────────┐            │  │
│  │  │  NGINX Container │────────▶│  Fluent Bit      │            │  │
│  │  │  (Port 80)       │  Logs  │  Container       │            │  │
│  │  │                  │         │                  │            │  │
│  │  │ - Web Server     │         │ - Tail Logs      │            │  │
│  │  │ - JSON Logs      │         │ - Parse JSON     │            │  │
│  │  │ - Health Check   │         │ - Add Metadata   │            │  │
│  │  │ - Metrics        │         │                  │            │  │
│  │  └─────────────────┘         └──────────────────┘            │  │
│  │         │                              │                      │  │
│  │         │ Volume Mounts                │ OTLP HTTP           │  │
│  │         ▼                              ▼                      │  │
│  │  /var/log/nginx-podman/        ┌──────────────────┐          │  │
│  │  ├── access.log (JSON)         │  OTEL Collector  │          │  │
│  │  └── error.log                 │  (4317, 4318)    │          │  │
│  │                                 │                  │          │  │
│  │  /etc/nginx-podman/             │ - Receive OTLP   │          │  │
│  │  ├── nginx.conf                 │ - Process Data   │          │  │
│  │  ├── conf.d/                    │ - Batch          │          │  │
│  │  └── ssl/                       │ - Export         │          │  │
│  │                                 └──────────────────┘          │  │
│  │  /var/www/html-podman/                 │                      │  │
│  │  └── index.html                        │                      │  │
│  │                                         ▼                      │  │
│  │                              ┌──────────────────────┐         │  │
│  │                              │  Exporters:          │         │  │
│  │                              │  - Debug (stdout)    │         │  │
│  │                              │  - Logging           │         │  │
│  │                              │  - [Future: Jaeger]  │         │  │
│  │                              │  - [Future: Prom]    │         │  │
│  │                              └──────────────────────┘         │  │
│  │                                                                │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│         ▲                                                            │
│         │ HTTP Requests                                             │
│         │                                                            │
│  ┌──────┴───────┐                                                   │
│  │   Clients    │                                                   │
│  │  (curl, etc) │                                                   │
│  └──────────────┘                                                   │
└────────────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow

### 1. HTTP Request Flow
```
Client Request
    ↓
NGINX Container (Port 80)
    ↓
NGINX processes request
    ↓
Response to Client
    ↓
NGINX writes log (JSON format)
    ↓
/var/log/nginx-podman/access.log
```

### 2. Telemetry Flow
```
NGINX Access Log (JSON)
    ↓
Fluent Bit tails log file
    ↓
Fluent Bit parses JSON
    ↓
Fluent Bit adds metadata
    ↓
OTLP HTTP (localhost:4318)
    ↓
OTEL Collector receives
    ↓
Memory Limiter Processor
    ↓
Batch Processor
    ↓
Attributes Processor
    ↓
Debug/Logging Exporters
    ↓
Container Logs (podman logs)
```

## 📦 Container Details

### NGINX Container
```
Name: nginx-server
Image: docker.io/library/nginx:latest
Network: host
Ports: 80 (HTTP)
Restart: unless-stopped

Volumes:
  /etc/nginx-podman/nginx.conf → /etc/nginx/nginx.conf (ro)
  /etc/nginx-podman/conf.d → /etc/nginx/conf.d (ro)
  /var/log/nginx-podman → /var/log/nginx (rw)
  /var/www/html-podman → /usr/share/nginx/html (ro)

Features:
  - JSON access logs
  - Request timing
  - Health endpoint (/health)
  - Status endpoint (/nginx-status)
  - IPv4/IPv6 support
```

### OTEL Collector Container
```
Name: otel-collector
Image: docker.io/otel/opentelemetry-collector:latest
Network: host
Ports: 4317 (gRPC), 4318 (HTTP)
Restart: unless-stopped

Volumes:
  /etc/otel-config.yaml → /otel-config.yaml (ro)

Receives:
  - OTLP gRPC (4317)
  - OTLP HTTP (4318)

Processes:
  - Memory Limiter (512MB limit)
  - Batch (10s timeout, 1024 batch size)
  - Attributes (service.name, etc.)

Exports:
  - Debug (detailed verbosity)
  - Logging (info level)
```

### Fluent Bit Container
```
Name: fluent-bit-nginx
Image: docker.io/fluent/fluent-bit:latest
Network: host
Restart: unless-stopped

Volumes:
  /etc/fluent-bit/fluent-bit.conf → /fluent-bit/etc/fluent-bit.conf (ro)
  /var/log/nginx-podman → /var/log/nginx-podman (ro)

Inputs:
  - Tail: /var/log/nginx-podman/access.log (JSON parser)
  - Tail: /var/log/nginx-podman/error.log

Filters:
  - Add service.name = nginx
  - Add log.source = fluent-bit

Outputs:
  - OpenTelemetry: localhost:4318
```

## 🌐 Network Topology

```
┌─────────────────────────────────────────────┐
│          Host Network (Shared)              │
│                                             │
│  localhost:80    ─────────▶ NGINX          │
│  localhost:4317  ─────────▶ OTEL (gRPC)    │
│  localhost:4318  ─────────▶ OTEL (HTTP)    │
│                                             │
│  All containers share host network stack   │
│  No port mapping needed                     │
│  Containers can access each other via       │
│  localhost                                  │
└─────────────────────────────────────────────┘
```

## 📊 Log Format

### NGINX Access Log (JSON)
```json
{
  "time_local": "30/Nov/2025:10:15:30 +0000",
  "remote_addr": "127.0.0.1",
  "remote_user": "",
  "request": "GET / HTTP/1.1",
  "status": "200",
  "body_bytes_sent": "612",
  "request_time": "0.001",
  "http_referrer": "",
  "http_user_agent": "curl/7.68.0",
  "http_x_forwarded_for": "",
  "upstream_response_time": "",
  "upstream_addr": "",
  "upstream_status": ""
}
```

### OTLP Log Record
```json
{
  "resourceLogs": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "nginx"}
      }]
    },
    "scopeLogs": [{
      "scope": {"name": "nginx-access-log"},
      "logRecords": [{
        "timeUnixNano": "1701340530000000000",
        "severityNumber": 9,
        "severityText": "INFO",
        "body": {"stringValue": "{...JSON log...}"},
        "attributes": [{
          "key": "log.source",
          "value": {"stringValue": "nginx-access"}
        }]
      }]
    }]
  }]
}
```

## 🔧 Configuration Hierarchy

```
/etc/
├── otel-config.yaml              # OTEL Collector configuration
├── nginx-podman/
│   ├── nginx.conf                # Main NGINX config
│   ├── conf.d/                   # Additional NGINX configs
│   │   └── *.conf                # Virtual hosts, locations
│   └── ssl/                      # SSL certificates
│       ├── cert.pem
│       └── key.pem
└── fluent-bit/
    └── fluent-bit.conf           # Fluent Bit configuration

/var/
├── log/
│   └── nginx-podman/             # NGINX logs
│       ├── access.log            # JSON formatted
│       └── error.log             # Standard format
└── www/
    └── html-podman/              # Web root
        └── index.html            # Default page
```

## 🚀 Startup Sequence

```
1. OTEL Collector starts
   ├── Reads /etc/otel-config.yaml
   ├── Opens ports 4317, 4318
   └── Ready to receive telemetry

2. NGINX starts
   ├── Reads /etc/nginx-podman/nginx.conf
   ├── Opens port 80
   ├── Serves /var/www/html-podman
   └── Writes logs to /var/log/nginx-podman/

3. Fluent Bit starts
   ├── Reads /etc/fluent-bit/fluent-bit.conf
   ├── Tails /var/log/nginx-podman/*.log
   ├── Connects to OTEL (localhost:4318)
   └── Forwards logs in real-time

4. System ready
   └── All containers running and integrated
```

## 📈 Observability Stack

### Current Implementation
```
┌─────────────┐
│   NGINX     │ ──▶ JSON Logs
└─────────────┘
       │
       ▼
┌─────────────┐
│ Fluent Bit  │ ──▶ Parse & Forward
└─────────────┘
       │
       ▼
┌─────────────┐
│    OTEL     │ ──▶ Process & Export
└─────────────┘
       │
       ▼
┌─────────────┐
│Debug/Logging│ ──▶ Container Logs
└─────────────┘
```

### Future Extensions
```
OTEL Collector can export to:

┌─────────────┐
│   Jaeger    │ ──▶ Distributed Tracing
└─────────────┘

┌─────────────┐
│ Prometheus  │ ──▶ Metrics & Alerts
└─────────────┘

┌─────────────┐
│   Grafana   │ ──▶ Dashboards
└─────────────┘

┌─────────────┐
│Elasticsearch│ ──▶ Log Aggregation
└─────────────┘

┌─────────────┐
│   Zipkin    │ ──▶ Trace Analysis
└─────────────┘
```

## 🎯 Key Integration Points

### 1. Log Collection
- NGINX writes JSON logs
- Fluent Bit tails logs in real-time
- Automatic parsing and metadata addition

### 2. Telemetry Transport
- OTLP protocol (OpenTelemetry standard)
- HTTP transport (port 4318)
- Reliable delivery with batching

### 3. Data Processing
- Memory limits to prevent OOM
- Batching for efficiency
- Attribute enrichment for context

### 4. Observability
- Debug output for development
- Structured logging
- Ready for production exporters

## 🔒 Security Considerations

```
Current Setup (Development):
├── No authentication on OTEL endpoints
├── No SSL/TLS encryption
├── Host network (all ports exposed)
└── Suitable for local testing

Production Recommendations:
├── Add TLS certificates to NGINX
├── Enable OTEL authentication
├── Use bridge network with specific port mappings
├── Implement rate limiting
├── Add firewall rules
└── Use secrets management
```

## 📊 Performance Characteristics

```
NGINX:
├── Handles ~10,000 req/s (depends on hardware)
├── Minimal overhead from JSON logging
└── Efficient with host network

Fluent Bit:
├── Low memory footprint (~10-20 MB)
├── Real-time log processing
└── Buffering for reliability

OTEL Collector:
├── Memory limit: 512 MB
├── Batch size: 1024 records
├── Batch timeout: 10 seconds
└── Spike limit: 128 MB
```

This architecture provides a solid foundation for observability and can be extended with additional exporters and features as needed!
