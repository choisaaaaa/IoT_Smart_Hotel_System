#!/bin/bash

# ==========================================
#   Smart Hotel Backend Slow Build Script
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
# Limit memory for tsc
node --max-old-space-size=1024 ./node_modules/typescript/bin/tsc --noEmit
echo "Done."

echo ""
echo ">>> [4/4] Building backend (Production)..."
# Limit memory for tsc build
node --max-old-space-size=1024 ./node_modules/typescript/bin/tsc --build
echo "Done."

echo ""
echo "=========================================="
echo "   Build Successful!"
echo "   Location: backend/iot-hotel-backend/dist"
echo "=========================================="
