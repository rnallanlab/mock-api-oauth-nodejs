#!/bin/bash
set -e

echo "Building Node.js Lambda function..."

# Navigate to server-nodejs directory
cd "$(dirname "$0")"

# Install dependencies
echo "Installing dependencies..."
npm install --production

# Clean and create dist directory
echo "Creating deployment package..."
npm run clean
npm run package

echo "Build complete! Package: dist/function.zip"
