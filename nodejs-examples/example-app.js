// example-app.js
// Example Express.js app with OpenTelemetry

require('./otel-setup'); // MUST be first!

const express = require('express');
const { trace } = require('@opentelemetry/api');
const { logs } = require('@opentelemetry/api-logs');

const app = express();
const tracer = trace.getTracer('example-app');
const logger = logs.getLogger('example-logger', '1.0.0');

app.use(express.json());

// Helper function for logging
function logInfo(message, attributes = {}) {
  logger.emit({
    severityText: 'INFO',
    body: message,
    attributes,
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

// Routes
app.get('/', (req, res) => {
  logInfo('Home page accessed', { path: req.path, method: req.method });
  res.json({
    message: 'Hello from OTEL-enabled Node.js app!',
    service: process.env.SERVICE_NAME || 'nodejs-app',
    telemetry: 'enabled',
  });
});

app.get('/api/users/:id', async (req, res) => {
  const span = tracer.startSpan('getUserById');
  
  try {
    const userId = req.params.id;
    span.setAttribute('user.id', userId);
    
    logInfo('Fetching user', { userId });
    
    // Simulate database call with nested span
    const user = await tracer.startActiveSpan('db.query.users', async (dbSpan) => {
      try {
        dbSpan.setAttribute('db.operation', 'SELECT');
        dbSpan.setAttribute('db.table', 'users');
        
        // Simulate delay
        await new Promise(resolve => setTimeout(resolve, Math.random() * 100));
        
        return {
          id: userId,
          name: `User ${userId}`,
          email: `user${userId}@example.com`,
          createdAt: new Date().toISOString(),
        };
      } finally {
        dbSpan.end();
      }
    });
    
    logInfo('User fetched successfully', { userId, email: user.email });
    res.json(user);
  } catch (error) {
    span.recordException(error);
    logError('Failed to fetch user', error, { userId: req.params.id });
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    span.end();
  }
});

app.post('/api/orders', async (req, res) => {
  return tracer.startActiveSpan('createOrder', async (span) => {
    try {
      const order = req.body;
      span.setAttribute('order.items', order.items?.length || 0);
      span.setAttribute('order.total', order.total || 0);
      
      logInfo('Creating new order', { itemCount: order.items?.length });
      
      // Simulate processing
      await new Promise(resolve => setTimeout(resolve, 150));
      
      const orderId = `ORD-${Date.now()}`;
      logInfo('Order created successfully', { orderId });
      
      res.status(201).json({
        orderId,
        status: 'created',
        message: 'Order processed successfully',
      });
    } catch (error) {
      span.recordException(error);
      logError('Failed to create order', error);
      res.status(500).json({ error: 'Failed to process order' });
    } finally {
      span.end();
    }
  });
});

app.get('/api/slow', async (req, res) => {
  return tracer.startActiveSpan('slowOperation', async (span) => {
    try {
      logInfo('Starting slow operation');
      
      // Simulate slow operation
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      res.json({ message: 'Slow operation completed', duration: '2s' });
    } finally {
      span.end();
    }
  });
});

app.get('/api/error', (req, res) => {
  const span = tracer.startSpan('errorRoute');
  
  try {
    logInfo('Error route accessed - will throw error');
    throw new Error('Intentional error for testing');
  } catch (error) {
    span.recordException(error);
    logError('Error occurred', error, { route: '/api/error' });
    res.status(500).json({ error: error.message });
  } finally {
    span.end();
  }
});

// 404 handler
app.use((req, res) => {
  logInfo('Route not found', { path: req.path, method: req.method });
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  const span = trace.getActiveSpan();
  if (span) {
    span.recordException(err);
  }
  logError('Unhandled error', err, { path: req.path });
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  logInfo('Server started', { port: PORT });
});
