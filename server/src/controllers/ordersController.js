const MockOrderService = require('../services/MockOrderService');
const ClientMetricsService = require('../services/ClientMetricsService');
const OrdersResponse = require('../models/OrdersResponse');

const orderService = new MockOrderService();
const metricsService = new ClientMetricsService();

/**
 * Extract client ID from JWT or API key
 */
function extractClientId(event, user) {
  // Prefer JWT 'sub' claim (client ID from Cognito)
  if (user && user.sub) {
    return user.sub;
  }

  // Fallback: API key hash
  const apiKey = event.headers?.['x-api-key'] || event.headers?.['X-Api-Key'];
  if (apiKey) {
    return 'api-key-' + Math.abs(hashCode(apiKey)).toString(16);
  }

  return 'unknown';
}

function hashCode(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return hash;
}

/**
 * Parse query parameters from event
 */
function getQueryParams(event) {
  return event.queryStringParameters || {};
}

/**
 * Handle orders requests
 */
async function handleRequest(event, user) {
  const path = event.path || event.rawPath || '';
  const method = event.httpMethod || event.requestContext?.http?.method || 'GET';

  // GET /orders?customerId=xxx
  if (path === '/orders' && method === 'GET') {
    return await listOrders(event, user);
  }

  // GET /orders/{orderId}
  const orderIdMatch = path.match(/^\/orders\/([^/]+)$/);
  if (orderIdMatch && method === 'GET') {
    return await getOrderById(event, user, orderIdMatch[1]);
  }

  return {
    statusCode: 404,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      error: 'NotFound',
      message: `Path ${path} not found`,
      timestamp: new Date().toISOString()
    })
  };
}

/**
 * List orders for a customer with optional date range filtering and pagination
 */
async function listOrders(event, user) {
  try {
    const params = getQueryParams(event);
    const { customerId, startDate, endDate, limit, offset } = params;
    const clientId = extractClientId(event, user);

    if (!customerId) {
      await metricsService.recordError(clientId, 'list_orders', 'ValidationError');
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'ValidationError',
          message: 'customerId parameter is required',
          timestamp: new Date().toISOString()
        })
      };
    }

    // Validate and apply defaults
    const limitValue = limit ? parseInt(limit) : 20;
    if (limitValue < 1 || limitValue > 100) {
      await metricsService.recordError(clientId, 'list_orders', 'ValidationError');
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'ValidationError',
          message: 'Limit must be between 1 and 100',
          timestamp: new Date().toISOString()
        })
      };
    }

    const offsetValue = offset ? parseInt(offset) : 0;
    if (offsetValue < 0) {
      await metricsService.recordError(clientId, 'list_orders', 'ValidationError');
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'ValidationError',
          message: 'Offset must be non-negative',
          timestamp: new Date().toISOString()
        })
      };
    }

    console.log(`Listing orders for customerId=${customerId}, startDate=${startDate}, endDate=${endDate}, limit=${limitValue}, offset=${offsetValue}, clientId=${clientId}`);

    // Record API usage metrics
    await metricsService.recordRequest(clientId, 'list_orders', customerId);

    // Fetch orders
    const orders = orderService.findOrdersByCustomerId(
      customerId,
      startDate,
      endDate,
      limitValue,
      offsetValue
    );

    const totalCount = orderService.countOrdersByCustomerId(
      customerId,
      startDate,
      endDate
    );

    console.log(`Found ${orders.length} orders out of ${totalCount} total for customerId=${customerId}, clientId=${clientId}`);

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(new OrdersResponse(orders, totalCount, limitValue, offsetValue))
    };

  } catch (err) {
    const clientId = extractClientId(event, user);
    await metricsService.recordError(clientId, 'list_orders', 'InternalError');
    throw err;
  }
}

/**
 * Get a specific order by ID
 */
async function getOrderById(event, user, orderId) {
  try {
    const clientId = extractClientId(event, user);

    console.log(`Getting order by orderId=${orderId}, clientId=${clientId}`);

    // Record API usage metrics
    await metricsService.recordRequest(clientId, 'get_order', orderId);

    const order = orderService.findOrderById(orderId);

    if (!order) {
      console.log(`Order not found: orderId=${orderId}, clientId=${clientId}`);
      await metricsService.recordError(clientId, 'get_order', 'NotFound');
      return {
        statusCode: 404,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'NotFound',
          message: `Order ${orderId} not found`,
          timestamp: new Date().toISOString()
        })
      };
    }

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(order)
    };

  } catch (err) {
    const clientId = extractClientId(event, user);
    await metricsService.recordError(clientId, 'get_order', 'InternalError');
    throw err;
  }
}

module.exports = { handleRequest };
