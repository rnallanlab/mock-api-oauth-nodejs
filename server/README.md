# Orders API Server

Node.js 22 serverless application for AWS Lambda.

## Structure

```
server/
├── src/
│   ├── config/
│   │   └── jwtConfig.js          # JWT validation configuration
│   ├── controllers/
│   │   ├── healthController.js   # Health check endpoint
│   │   └── ordersController.js   # Orders endpoints
│   ├── middleware/
│   │   ├── errorHandler.js       # Global error handler
│   │   └── requestLogger.js      # Request logging
│   ├── models/
│   │   ├── ErrorResponse.js      # Error response model
│   │   ├── Order.js              # Order model
│   │   ├── OrderItem.js          # Order item model
│   │   ├── OrdersResponse.js     # Paginated response model
│   │   └── OrderStatus.js        # Order status enum
│   ├── services/
│   │   ├── ClientMetricsService.js # CloudWatch metrics
│   │   └── MockOrderService.js   # Mock order data
│   ├── app.js                    # Main application logic
│   └── lambda.js                 # Lambda handler (entry point)
├── build.sh                      # Build script
└── package.json                  # Dependencies
```

## Building

```bash
# Install dependencies
npm install

# Build deployment package
npm run build

# Output: dist/function.zip
```

Or use the project build script:
```bash
# From project root
./scripts/build.sh
```

## Dependencies

- **jsonwebtoken**: JWT token validation
- **jwks-rsa**: JWKS client for fetching Cognito public keys
- **@aws-sdk/client-cloudwatch**: CloudWatch metrics

## Environment Variables

- `COGNITO_USER_POOL_ID`: Cognito User Pool ID
- `COGNITO_REGION`: AWS region (default: us-east-1)
- `COGNITO_APP_CLIENT_ID`: Cognito App Client ID
- `LOG_LEVEL`: Logging level (default: INFO)

## Lambda Handler

The Lambda handler is defined as `src/lambda.handler` and processes API Gateway proxy events.

**Handler function:** `exports.handler` in `src/lambda.js`

## API Endpoints

- `GET /health` - Health check (no authentication)
- `GET /orders?customerId={id}` - List customer orders (requires JWT + API key)
- `GET /orders/{orderId}` - Get order by ID (requires JWT + API key)

## Local Testing

For local testing, you can invoke the handler directly:

```javascript
const { handler } = require('./src/lambda');

const event = {
  path: '/health',
  httpMethod: 'GET',
  headers: {}
};

handler(event, {}).then(console.log);
```

## Deployment

The function is deployed via Terraform. See `../terraform/` for infrastructure configuration.

```bash
# From project root
./scripts/deploy.sh lambda us-east-1 dev
```

## Development

```bash
# Install dependencies
npm install

# Run local tests (if configured)
npm test

# Lint code
npm run lint
```

## Package Structure

The deployment package (`dist/function.zip`) includes:
- All source code (`src/`)
- All production dependencies (`node_modules/`)
- `package.json` and `package-lock.json`

**Note:** Dev dependencies are excluded from the deployment package.
