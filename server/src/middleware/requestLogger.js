/**
 * Request logging middleware
 * Logs incoming requests for /orders endpoints
 */
function requestLogger(req) {
  if (req.path && req.path.startsWith('/orders')) {
    console.log('=== Incoming Request ===');
    console.log(`Path: ${req.path}`);
    console.log(`Method: ${req.method}`);
    console.log('Headers:');
    Object.keys(req.headers || {}).forEach(headerName => {
      console.log(`  ${headerName}: ${req.headers[headerName]}`);
    });
  }
}

module.exports = requestLogger;
