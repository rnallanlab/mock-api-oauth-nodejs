const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

/**
 * JWT validation for Cognito tokens
 */
class JwtConfig {
  constructor() {
    this.cognitoRegion = process.env.COGNITO_REGION || 'us-east-1';
    this.userPoolId = process.env.COGNITO_USER_POOL_ID || 'YOUR_USER_POOL_ID';

    // JWKS client for fetching Cognito public keys
    this.jwksUri = `https://cognito-idp.${this.cognitoRegion}.amazonaws.com/${this.userPoolId}/.well-known/jwks.json`;

    this.client = jwksClient({
      jwksUri: this.jwksUri,
      cache: true,
      cacheMaxAge: 600000, // 10 minutes
      rateLimit: true,
      jwksRequestsPerMinute: 10
    });
  }

  /**
   * Get signing key for JWT verification
   */
  getKey(header, callback) {
    this.client.getSigningKey(header.kid, (err, key) => {
      if (err) {
        return callback(err);
      }
      const signingKey = key.getPublicKey();
      callback(null, signingKey);
    });
  }

  /**
   * Verify JWT token from API Gateway event
   */
  async verifyTokenFromEvent(event) {
    const authHeader = event.headers?.Authorization || event.headers?.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return {
        statusCode: 401,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'Unauthorized',
          message: 'Missing or invalid Authorization header',
          timestamp: new Date().toISOString()
        }),
        error: true
      };
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    try {
      const decoded = await new Promise((resolve, reject) => {
        jwt.verify(
          token,
          (header, callback) => this.getKey(header, callback),
          {
            algorithms: ['RS256'],
            issuer: `https://cognito-idp.${this.cognitoRegion}.amazonaws.com/${this.userPoolId}`
          },
          (err, decoded) => {
            if (err) {
              reject(err);
            } else {
              resolve(decoded);
            }
          }
        );
      });

      return { user: decoded, error: false };

    } catch (err) {
      console.error('JWT verification failed:', err.message);
      return {
        statusCode: 401,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'Unauthorized',
          message: 'Invalid or expired token',
          timestamp: new Date().toISOString()
        }),
        error: true
      };
    }
  }
}

module.exports = JwtConfig;
