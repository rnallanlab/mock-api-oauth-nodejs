#!/bin/bash
set -e

echo "================================"
echo "Building Mock Orders API (Node.js)"
echo "================================"

# Check Node.js version
echo "Checking Node.js version..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 22 ]; then
    echo "❌ Node.js 22 or higher is required"
    exit 1
fi
echo "✓ Node.js version: $(node -v)"

# Check npm
echo "Checking npm..."
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed"
    exit 1
fi
echo "✓ npm version: $(npm -v)"

# Build server project
echo ""
echo "Building server project..."
cd server

# Install dependencies
echo "Installing dependencies..."
npm install

# Build package
echo "Creating deployment package..."
npm run build

if [ $? -eq 0 ]; then
    echo "✓ Server project built successfully"
    ls -lh dist/function.zip
else
    echo "❌ Build failed"
    exit 1
fi

cd ..

# Package authorizer (if source changed)
echo ""
echo "Packaging Lambda Authorizer..."
cd terraform/modules/authorizer
if [ ! -f "authorizer.zip" ] || [ "index.js" -nt "authorizer.zip" ]; then
    npm install
    zip -r authorizer.zip index.js node_modules/ package.json
    echo "✓ Authorizer packaged"
else
    echo "✓ Authorizer package is up to date"
fi
cd ../../..

echo ""
echo "================================"
echo "✓ Build completed successfully!"
echo "================================"
echo ""
echo "Artifacts:"
echo "  - Lambda ZIP: server/dist/function.zip"
echo "  - Authorizer ZIP: terraform/modules/authorizer/authorizer.zip"
echo ""
