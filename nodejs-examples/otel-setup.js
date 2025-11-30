// otel-setup.js
// Global OpenTelemetry configuration for Node.js applications
// This file sends traces, metrics, and logs to the OTEL Collector

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-http');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { BatchLogRecordProcessor } = require('@opentelemetry/sdk-logs');

// OTEL Collector endpoint
const OTEL_COLLECTOR_URL = process.env.OTEL_COLLECTOR_URL || 'http://localhost:4318';

// Service identification
const SERVICE_NAME = process.env.SERVICE_NAME || 'nodejs-app';
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';
const ENVIRONMENT = process.env.NODE_ENV || 'development';

// Configure resource
const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: SERVICE_NAME,
  [SemanticResourceAttributes.SERVICE_VERSION]: SERVICE_VERSION,
  [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: ENVIRONMENT,
});

// Initialize OpenTelemetry SDK
const sdk = new NodeSDK({
  resource: resource,
  
  // Trace Exporter
  traceExporter: new OTLPTraceExporter({
    url: `${OTEL_COLLECTOR_URL}/v1/traces`,
    headers: {},
  }),

  // Metric Reader
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: `${OTEL_COLLECTOR_URL}/v1/metrics`,
      headers: {},
    }),
    exportIntervalMillis: 10000,
  }),

  // Log Processor
  logRecordProcessor: new BatchLogRecordProcessor(
    new OTLPLogExporter({
      url: `${OTEL_COLLECTOR_URL}/v1/logs`,
      headers: {},
    })
  ),

  // Auto-instrumentation
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': {
        enabled: false,
      },
    }),
  ],
});

// Start SDK
try {
  sdk.start();
  console.log('✅ OpenTelemetry initialized');
  console.log(`📡 Endpoint: ${OTEL_COLLECTOR_URL}`);
  console.log(`🏷️  Service: ${SERVICE_NAME} (${SERVICE_VERSION})`);
} catch (error) {
  console.error('❌ Error initializing OpenTelemetry:', error);
}

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('OpenTelemetry SDK shut down'))
    .catch((error) => console.error('Error shutting down SDK', error))
    .finally(() => process.exit(0));
});

module.exports = sdk;
