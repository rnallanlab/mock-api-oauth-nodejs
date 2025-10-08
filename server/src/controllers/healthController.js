/**
 * Health check controller
 */
function health() {
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      status: 'healthy',
      timestamp: new Date().toISOString()
    })
  };
}

module.exports = { health };
