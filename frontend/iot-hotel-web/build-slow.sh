#!/bin/bash

# ==========================================
#   Smart Hotel Frontend Slow Build Script
#   Optimized for Low Memory/CPU Servers
# ==========================================

set -e

echo ">>> [1/4] Cleaning previous build..."
rm -rf dist
echo "Done."

echo ""
echo ">>> [2/4] Installing dependencies..."
# Use --no-audit and --no-fund to save some CPU/Network
npm install --no-audit --no-fund
echo "Done."

echo ""
echo ">>> [3/4] Running type check..."
# Limit memory for vue-tsc
node --max-old-space-size=1024 ./node_modules/vue-tsc/bin/vue-tsc.js -b
echo "Done."

echo ""
echo ">>> [4/4] Building frontend (Production)..."
# Limit memory for Vite build
NODE_OPTIONS="--max-old-space-size=1024" npm run build
echo "Done."

echo ""
echo "=========================================="
echo "   Build Successful!"
echo "   Location: frontend/iot-hotel-web/dist"
echo "=========================================="
