const JwtConfig = require('./config/jwtConfig');
const healthController = require('./controllers/healthController');
const ordersController = require('./controllers/ordersController');
const requestLogger = require('./middleware/requestLogger');
const errorHandler = require('./middleware/errorHandler');

const jwtConfig = new JwtConfig();

/**
 * Main application handler for API Gateway events
 */
async function handleRequest(event) {
  try {
    const path = event.path || event.rawPath || '';
    const method = event.httpMethod || event.requestContext?.http?.method || 'GET';
    const headers = event.headers || {};

    // Log request
    requestLogger({ path, method, headers });

    // Health check endpoint (no auth required)
    if (path === '/health' && method === 'GET') {
      return healthController.health();
    }

    // All other endpoints require JWT authentication
    const authResult = await jwtConfig.verifyTokenFromEvent(event);
    if (authResult.error) {
      return authResult;
    }

    // Route to controllers
    if (path.startsWith('/orders')) {
      return await ordersController.handleRequest(event, authResult.user);
    }

    // 404 Not Found
    return {
      statusCode: 404,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'NotFound',
        message: `Path ${path} not found`,
        timestamp: new Date().toISOString()
      })
    };

  } catch (err) {
    return errorHandler(err);
  }
}

module.exports = { handleRequest };
