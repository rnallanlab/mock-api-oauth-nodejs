const ErrorResponse = require('../models/ErrorResponse');

/**
 * Global error handler
 */
function errorHandler(err) {
  console.error('Error:', err);

  // Handle specific error types
  if (err.name === 'UnauthorizedError' || err.message?.includes('jwt')) {
    return {
      statusCode: 401,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(new ErrorResponse('Unauthorized', err.message))
    };
  }

  if (err.name === 'ValidationError') {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(new ErrorResponse('ValidationError', err.message))
    };
  }

  // Default error response
  const errorResponse = new ErrorResponse(
    err.name || 'InternalServerError',
    err.message || 'An unexpected error occurred'
  );

  return {
    statusCode: err.status || 500,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(errorResponse)
  };
}

module.exports = errorHandler;
