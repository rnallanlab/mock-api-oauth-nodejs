const { handleRequest } = require('./app');

/**
 * AWS Lambda handler for API Gateway proxy integration
 */
exports.handler = async (event, context) => {
  console.log('Lambda invoked:', JSON.stringify({ path: event.path, method: event.httpMethod }));

  try {
    const response = await handleRequest(event);
    return response;
  } catch (err) {
    console.error('Unhandled error:', err);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'InternalServerError',
        message: 'An unexpected error occurred',
        timestamp: new Date().toISOString()
      })
    };
  }
};
