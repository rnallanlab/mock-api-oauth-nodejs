#!/bin/bash
set -e

echo "Building Lambda authorizer package..."

# Install dependencies
npm install --production

# Create deployment package
zip -r authorizer.zip index.js node_modules package.json

echo "✓ Authorizer package created: authorizer.zip"
