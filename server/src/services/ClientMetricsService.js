const { CloudWatchClient, PutMetricDataCommand } = require('@aws-sdk/client-cloudwatch');

/**
 * Service for tracking client usage metrics and API analytics using CloudWatch
 */
class ClientMetricsService {
  constructor() {
    this.cloudwatch = new CloudWatchClient({ region: process.env.COGNITO_REGION || 'us-east-1' });
    this.namespace = 'OrdersAPI';
  }

  /**
   * Record an API request with client and endpoint information
   */
  async recordRequest(clientId, endpoint, customerId) {
    const safeClientId = this.sanitize(clientId);
    const safeEndpoint = this.sanitize(endpoint);
    const safeCustomerId = this.sanitize(customerId);

    // Log for detailed analytics (CloudWatch Logs)
    console.log(`API_REQUEST client=${safeClientId} endpoint=${safeEndpoint} customer=${safeCustomerId}`);

    // Send metric to CloudWatch
    await this.putMetric('api.requests.total', 1, [
      { Name: 'client', Value: safeClientId },
      { Name: 'endpoint', Value: safeEndpoint },
      { Name: 'customer', Value: safeCustomerId }
    ]);
  }

  /**
   * Record an API request error
   */
  async recordError(clientId, endpoint, errorType) {
    const safeClientId = this.sanitize(clientId);
    const safeEndpoint = this.sanitize(endpoint);
    const safeErrorType = this.sanitize(errorType);

    console.warn(`API_ERROR client=${safeClientId} endpoint=${safeEndpoint} error_type=${safeErrorType}`);

    await this.putMetric('api.errors.total', 1, [
      { Name: 'client', Value: safeClientId },
      { Name: 'endpoint', Value: safeEndpoint },
      { Name: 'error_type', Value: safeErrorType }
    ]);
  }

  /**
   * Record response duration
   */
  async recordResponseDuration(clientId, endpoint, durationMs) {
    const safeClientId = this.sanitize(clientId);
    const safeEndpoint = this.sanitize(endpoint);

    await this.putMetric('api.response.duration', durationMs, [
      { Name: 'client', Value: safeClientId },
      { Name: 'endpoint', Value: safeEndpoint }
    ], 'Milliseconds');
  }

  /**
   * Record quota usage for a client
   */
  async recordQuotaUsage(clientId, requestsUsed) {
    const safeClientId = this.sanitize(clientId);

    console.log(`QUOTA_USAGE client=${safeClientId} requests_used=${requestsUsed}`);

    await this.putMetric('api.quota.used', requestsUsed, [
      { Name: 'client', Value: safeClientId }
    ]);
  }

  /**
   * Put metric to CloudWatch (async, non-blocking)
   */
  async putMetric(metricName, value, dimensions = [], unit = 'Count') {
    try {
      const command = new PutMetricDataCommand({
        Namespace: this.namespace,
        MetricData: [
          {
            MetricName: metricName,
            Value: value,
            Unit: unit,
            Timestamp: new Date(),
            Dimensions: dimensions
          }
        ]
      });

      // Fire and forget - don't await to avoid blocking request
      this.cloudwatch.send(command).catch(err => {
        console.error('Failed to send metric to CloudWatch:', err.message);
      });
    } catch (err) {
      console.error('Error creating CloudWatch metric:', err.message);
    }
  }

  /**
   * Sanitize tag values to prevent metric explosion
   */
  sanitize(value) {
    if (!value || value.trim().length === 0) {
      return 'unknown';
    }
    // Limit length and remove special characters
    return value
      .replace(/[^a-zA-Z0-9_-]/g, '_')
      .substring(0, Math.min(value.length, 50))
      .toLowerCase();
  }
}

module.exports = ClientMetricsService;
