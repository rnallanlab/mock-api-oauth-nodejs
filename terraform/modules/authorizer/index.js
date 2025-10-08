const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// Configuration from environment variables
const PROVIDER_TYPE = process.env.PROVIDER_TYPE; // 'cognito' or 'azure'
const JWKS_URI = process.env.JWKS_URI;
const ISSUER = process.env.ISSUER;
const AUDIENCE = process.env.AUDIENCE;

console.log('Authorizer initialized:', { PROVIDER_TYPE, JWKS_URI, ISSUER });

const client = jwksClient({
  cache: true,
  rateLimit: true,
  jwksRequestsPerMinute: 10,
  jwksUri: JWKS_URI
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) {
      console.error('Error getting signing key:', err);
      callback(err);
    } else {
      const signingKey = key.getPublicKey();
      callback(null, signingKey);
    }
  });
}

exports.handler = async (event) => {
  console.log('Authorization request:', JSON.stringify(event, null, 2));

  // Extract token from Authorization header
  const authHeader = event.authorizationToken || event.headers?.Authorization || event.headers?.authorization;

  if (!authHeader) {
    console.error('No authorization header found');
    return generatePolicy('user', 'Deny', event.methodArn);
  }

  const token = authHeader.replace('Bearer ', '').replace('bearer ', '');

  try {
    // Verify JWT signature and standard claims
    const verifyOptions = {
      issuer: ISSUER,
      algorithms: ['RS256']
    };

    // Only validate audience for Azure AD (Cognito client credentials flow doesn't include aud)
    if (PROVIDER_TYPE === 'azure' && AUDIENCE) {
      verifyOptions.audience = AUDIENCE;
    }

    const decoded = await new Promise((resolve, reject) => {
      jwt.verify(token, getKey, verifyOptions, (err, decoded) => {
        if (err) {
          console.error('JWT verification failed:', err.message);
          reject(err);
        } else {
          resolve(decoded);
        }
      });
    });

    console.log('JWT decoded successfully:', { sub: decoded.sub, iss: decoded.iss });

    // Provider-specific validation
    if (PROVIDER_TYPE === 'cognito') {
      // Cognito-specific: validate token_use claim
      if (decoded.token_use !== 'access') {
        console.error('Invalid token_use:', decoded.token_use);
        throw new Error('Token must be an access token (token_use=access)');
      }

      // Validate client_id if needed
      if (decoded.client_id) {
        console.log('Cognito client_id:', decoded.client_id);
      }
    } else if (PROVIDER_TYPE === 'azure') {
      // Azure AD-specific: validate version and app ID
      if (!decoded.aud || decoded.aud !== AUDIENCE) {
        console.error('Invalid audience:', decoded.aud);
        throw new Error('Invalid audience claim');
      }

      // Check token version
      if (!decoded.ver || (decoded.ver !== '1.0' && decoded.ver !== '2.0')) {
        console.error('Invalid Azure AD token version:', decoded.ver);
        throw new Error('Invalid token version');
      }

      console.log('Azure AD token validated:', { ver: decoded.ver, tid: decoded.tid });
    }

    // Generate allow policy with user context
    // Use wildcard to allow all API methods (not just the specific methodArn)
    const apiGatewayArnTmp = event.methodArn.split('/');
    const awsAccountId = apiGatewayArnTmp[0].split(':')[4];
    const region = apiGatewayArnTmp[0].split(':')[3];
    const restApiId = apiGatewayArnTmp[0].split('/')[0].split(':')[5];
    const stage = apiGatewayArnTmp[1];
    const resourceArn = `arn:aws:execute-api:${region}:${awsAccountId}:${restApiId}/${stage}/*/*`;

    const policy = generatePolicy(
      decoded.sub,
      'Allow',
      resourceArn,
      {
        userId: decoded.sub || '',
        email: decoded.email || '',
        username: decoded.username || decoded.preferred_username || decoded.upn || '',
        clientId: decoded.client_id || decoded.azp || decoded.appid || '',
        scope: decoded.scope || '',
        provider: PROVIDER_TYPE
      }
    );

    console.log('Authorization successful for user:', decoded.sub);
    console.log('Generated policy:', JSON.stringify(policy, null, 2));
    return policy;

  } catch (err) {
    console.error('Authorization failed:', err.message);
    return generatePolicy('user', 'Deny', event.methodArn);
  }
};

function generatePolicy(principalId, effect, resource, context = {}) {
  const authResponse = {
    principalId: principalId
  };

  if (effect && resource) {
    authResponse.policyDocument = {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: resource
        }
      ]
    };
  }

  // Add context to pass user info to Lambda
  if (effect === 'Allow' && Object.keys(context).length > 0) {
    authResponse.context = {};
    // API Gateway only allows string values in context
    for (const [key, value] of Object.entries(context)) {
      authResponse.context[key] = String(value);
    }
  }

  return authResponse;
}
