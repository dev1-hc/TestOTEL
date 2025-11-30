# Node.js OpenTelemetry Integration Guide

## Quick Setup for Node.js Apps

This guide shows how to send **logs, metrics, and traces** from your Node.js applications to the OTEL Collector.

---

## 📦 Installation

```bash
npm install --save \
  @opentelemetry/api \
  @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http \
  @opentelemetry/exporter-metrics-otlp-http \
  @opentelemetry/exporter-logs-otlp-http \
  @opentelemetry/sdk-logs \
  @opentelemetry/instrumentation
```

---

## 🚀 Method 1: Global Setup (Recommended)

### Create `otel-setup.js` (Reusable across all Node.js apps)

```javascript
// otel-setup.js
// This file configures OpenTelemetry to send traces, metrics, and logs to OTEL Collector

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-http');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { BatchLogRecordProcessor } = require('@opentelemetry/sdk-logs');

// OTEL Collector endpoint (adjust if needed)
const OTEL_COLLECTOR_URL = process.env.OTEL_COLLECTOR_URL || 'http://localhost:4318';

// Service name (override with environment variable)
const SERVICE_NAME = process.env.SERVICE_NAME || 'nodejs-app';
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';
const ENVIRONMENT = process.env.NODE_ENV || 'development';

// Configure resource with service information
const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: SERVICE_NAME,
  [SemanticResourceAttributes.SERVICE_VERSION]: SERVICE_VERSION,
  [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: ENVIRONMENT,
});

// Initialize OpenTelemetry SDK
const sdk = new NodeSDK({
  resource: resource,
  
  // Trace Exporter (sends traces to OTEL Collector)
  traceExporter: new OTLPTraceExporter({
    url: `${OTEL_COLLECTOR_URL}/v1/traces`,
    headers: {},
  }),

  // Metric Reader (sends metrics to OTEL Collector)
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: `${OTEL_COLLECTOR_URL}/v1/metrics`,
      headers: {},
    }),
    exportIntervalMillis: 10000, // Export every 10 seconds
  }),

  // Log Processor (sends logs to OTEL Collector)
  logRecordProcessor: new BatchLogRecordProcessor(
    new OTLPLogExporter({
      url: `${OTEL_COLLECTOR_URL}/v1/logs`,
      headers: {},
    })
  ),

  // Auto-instrumentation for common Node.js frameworks
  instrumentations: [
    getNodeAutoInstrumentations({
      // Automatic instrumentation for:
      // - HTTP/HTTPS
      // - Express
      // - MongoDB
      // - MySQL
      // - PostgreSQL
      // - Redis
      // - And many more...
      '@opentelemetry/instrumentation-fs': {
        enabled: false, // Disable file system instrumentation (too verbose)
      },
    }),
  ],
});

// Start the SDK
sdk.start()
  .then(() => {
    console.log('✅ OpenTelemetry initialized');
    console.log(`📡 Sending telemetry to: ${OTEL_COLLECTOR_URL}`);
    console.log(`🏷️  Service: ${SERVICE_NAME} (${SERVICE_VERSION})`);
  })
  .catch((error) => {
    console.error('❌ Error initializing OpenTelemetry:', error);
  });

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('OpenTelemetry SDK shut down successfully'))
    .catch((error) => console.error('Error shutting down OpenTelemetry SDK', error))
    .finally(() => process.exit(0));
});

module.exports = sdk;
```

---

## 📝 Method 2: Use in Your App

### Option A: Require at the top of your main file

```javascript
// app.js or index.js
// IMPORTANT: This must be the FIRST require in your app
require('./otel-setup');

const express = require('express');
const app = express();

// Your application code...
app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

### Option B: Use Node.js --require flag (Global for all apps)

```bash
# Run any Node.js app with OTEL enabled
node --require ./otel-setup.js app.js

# Or add to package.json scripts
{
  "scripts": {
    "start": "node --require ./otel-setup.js app.js",
    "dev": "nodemon --require ./otel-setup.js app.js"
  }
}
```

### Option C: Set NODE_OPTIONS environment variable (System-wide)

```bash
# Linux/Mac
export NODE_OPTIONS="--require /path/to/otel-setup.js"

# Windows
set NODE_OPTIONS=--require C:\path\to\otel-setup.js

# Now all Node.js apps will automatically use OTEL
node app.js  # Automatically instrumented!
```

---

## 🎯 Manual Logging and Tracing

### Manual Logging Example

```javascript
// logger.js
const { logs } = require('@opentelemetry/api-logs');
const logger = logs.getLogger('my-app-logger', '1.0.0');

function logInfo(message, attributes = {}) {
  logger.emit({
    severityText: 'INFO',
    body: message,
    attributes: {
      'app.component': 'business-logic',
      ...attributes,
    },
  });
}

function logError(message, error, attributes = {}) {
  logger.emit({
    severityText: 'ERROR',
    body: message,
    attributes: {
      'error.type': error.name,
      'error.message': error.message,
      'error.stack': error.stack,
      ...attributes,
    },
  });
}

module.exports = { logInfo, logError };
```

Usage:

```javascript
const { logInfo, logError } = require('./logger');

// Log information
logInfo('User logged in', { userId: '12345', method: 'oauth' });

// Log errors
try {
  throw new Error('Something went wrong!');
} catch (error) {
  logError('Failed to process request', error, { requestId: 'req-123' });
}
```

### Manual Tracing Example

```javascript
// tracer.js
const { trace } = require('@opentelemetry/api');
const tracer = trace.getTracer('my-app-tracer', '1.0.0');

async function processOrder(orderId) {
  // Create a span for this operation
  const span = tracer.startSpan('processOrder', {
    attributes: {
      'order.id': orderId,
      'order.operation': 'process',
    },
  });

  try {
    // Simulate processing
    await fetchOrderDetails(orderId);
    await validateOrder(orderId);
    await chargePayment(orderId);
    
    span.setStatus({ code: 1 }); // OK
    return { success: true };
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message }); // ERROR
    throw error;
  } finally {
    span.end();
  }
}

async function fetchOrderDetails(orderId) {
  return tracer.startActiveSpan('fetchOrderDetails', async (span) => {
    try {
      // Your database call here
      const order = await db.orders.findOne({ id: orderId });
      span.setAttribute('order.status', order.status);
      return order;
    } finally {
      span.end();
    }
  });
}

module.exports = { processOrder };
```

---

## 🔧 Environment Variables

Create a `.env` file:

```bash
# .env
SERVICE_NAME=my-nodejs-app
SERVICE_VERSION=1.0.0
NODE_ENV=production
OTEL_COLLECTOR_URL=http://localhost:4318
```

Load in your app:

```javascript
require('dotenv').config();
require('./otel-setup');
// Rest of your app...
```

---

## 📊 Example: Express.js App with OTEL

```javascript
// app.js
require('./otel-setup'); // MUST be first!

const express = require('express');
const { trace, context } = require('@opentelemetry/api');
const { logInfo } = require('./logger');

const app = express();
const tracer = trace.getTracer('express-app');

app.use(express.json());

// Custom middleware to add trace context
app.use((req, res, next) => {
  const span = trace.getActiveSpan();
  if (span) {
    span.setAttribute('http.route', req.path);
    span.setAttribute('http.method', req.method);
  }
  next();
});

app.get('/', (req, res) => {
  logInfo('Home page accessed', { ip: req.ip });
  res.json({ message: 'Hello from OTEL-enabled app!' });
});

app.get('/api/users/:id', async (req, res) => {
  const span = tracer.startSpan('getUserById');
  
  try {
    const userId = req.params.id;
    span.setAttribute('user.id', userId);
    
    // Simulate database call
    const user = await fetchUser(userId);
    
    logInfo('User fetched successfully', { userId });
    res.json(user);
  } catch (error) {
    span.recordException(error);
    logError('Failed to fetch user', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    span.end();
  }
});

async function fetchUser(id) {
  return tracer.startActiveSpan('db.query', async (span) => {
    try {
      // Simulate DB call
      await new Promise(resolve => setTimeout(resolve, 100));
      return { id, name: 'John Doe', email: 'john@example.com' };
    } finally {
      span.end();
    }
  });
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  logInfo('Server started', { port: PORT });
});
```

---

## 🐳 Docker Setup

### Dockerfile

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

# Set OTEL environment variables
ENV OTEL_COLLECTOR_URL=http://otel-collector:4318
ENV SERVICE_NAME=my-nodejs-app
ENV SERVICE_VERSION=1.0.0

# Use --require to load OTEL automatically
CMD ["node", "--require", "./otel-setup.js", "app.js"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  otel-collector:
    image: otel/opentelemetry-collector:latest
    command: ["--config=/otel-config.yaml"]
    volumes:
      - /etc/otel-config.yaml:/otel-config.yaml:ro
    ports:
      - "4317:4317"  # gRPC
      - "4318:4318"  # HTTP
    networks:
      - app-network

  nodejs-app:
    build: .
    environment:
      - OTEL_COLLECTOR_URL=http://otel-collector:4318
      - SERVICE_NAME=my-nodejs-app
      - NODE_ENV=production
    depends_on:
      - otel-collector
    networks:
      - app-network

networks:
  app-network:
```

---

## ✅ Verification

After starting your app:

```bash
# Check OTEL Collector logs
podman logs -f otel-collector

# You should see:
# - Traces from HTTP requests
# - Metrics (request count, duration, etc.)
# - Custom logs from your app

# Test your app
curl http://localhost:3000/
curl http://localhost:3000/api/users/123

# View traces in OTEL logs
podman logs --tail 50 otel-collector | grep -A 10 "Traces"
```

---

## 📂 Project Structure

```
your-nodejs-app/
├── otel-setup.js          # ← OpenTelemetry configuration (reusable)
├── logger.js              # ← Custom logging utilities
├── tracer.js              # ← Custom tracing utilities
├── app.js                 # Your main application
├── package.json
└── .env                   # Environment variables
```

---

## 🎯 What Gets Automatically Instrumented?

When you use `getNodeAutoInstrumentations()`, you get automatic instrumentation for:

- ✅ **HTTP/HTTPS** - All incoming and outgoing requests
- ✅ **Express.js** - Routes, middleware, error handlers
- ✅ **MongoDB** - Database queries
- ✅ **MySQL/PostgreSQL** - SQL queries
- ✅ **Redis** - Cache operations
- ✅ **AWS SDK** - S3, DynamoDB, etc.
- ✅ **GraphQL** - Queries and mutations
- ✅ **gRPC** - RPC calls
- ✅ **And 50+ more libraries!**

---

## 🔍 Viewing Your Telemetry

```bash
# Monitor live telemetry
./monitor.sh

# Then press:
# 1 - View OTEL Collector logs (see incoming traces/logs)
# 8 - Analyze NGINX logs
# 9 - Show detailed OTEL output
```

---

## 🚨 Troubleshooting

### Telemetry not showing up?

```javascript
// Add debug logging to otel-setup.js
const { diag, DiagConsoleLogger, DiagLogLevel } = require('@opentelemetry/api');
diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.DEBUG);
```

### Check OTEL Collector is accessible

```bash
# From your Node.js container/host
curl -X POST http://localhost:4318/v1/traces -H "Content-Type: application/json" -d '{}'

# Should return 200 or similar
```

### Verify environment variables

```javascript
console.log('OTEL Config:', {
  url: process.env.OTEL_COLLECTOR_URL,
  service: process.env.SERVICE_NAME,
  version: process.env.SERVICE_VERSION,
});
```

---

## 📚 Additional Resources

- OpenTelemetry JS Docs: https://opentelemetry.io/docs/instrumentation/js/
- Auto-Instrumentation Guide: https://opentelemetry.io/docs/instrumentation/js/automatic/
- Manual Instrumentation: https://opentelemetry.io/docs/instrumentation/js/manual/

---

**Pro Tip**: Copy `otel-setup.js` to a shared location (like `/usr/local/lib/otel-setup.js`) and set `NODE_OPTIONS` globally to automatically instrument **all** Node.js apps on your system!
