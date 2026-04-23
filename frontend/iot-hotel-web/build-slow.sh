#!/bin/bash

# ==========================================
#   Smart Hotel Frontend Slow Build Script
#   Optimized for Low Memory/CPU Servers
# ==========================================

set -e

echo ">>> [1/3] Cleaning previous build..."
rm -rf dist
echo "Done."

echo ""
echo ">>> [2/3] Installing dependencies..."
# Use --no-audit and --no-fund to save some CPU/Network
npm install --no-audit --no-fund --prefer-offline
echo "Done."

echo ""
echo ">>> [3/3] Building frontend (Production)..."
# Skip vue-tsc type checking as it's too heavy for low-spec servers.
# Use only Vite build which handles compilation.
NODE_OPTIONS="--max-old-space-size=512" npm run build
echo "Done."

echo ""
echo "=========================================="
echo "   Build Successful!"
echo "   Location: frontend/iot-hotel-web/dist"
echo "=========================================="
