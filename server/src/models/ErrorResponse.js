/**
 * Standard error response model
 */
class ErrorResponse {
  constructor(error, message, timestamp = new Date().toISOString()) {
    this.error = error;
    this.message = message;
    this.timestamp = timestamp;
  }
}

module.exports = ErrorResponse;
