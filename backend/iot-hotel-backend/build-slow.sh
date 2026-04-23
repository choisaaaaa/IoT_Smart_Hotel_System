#!/bin/bash

# ==========================================
#   Smart Hotel Backend Slow Build Script
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
echo ">>> [3/3] Building backend (Production)..."
# Skip standalone type check and just build.
# Reduced memory limit to 512MB to be extremely safe.
# Using --incremental if possible, but tsc --build handles that.
node --max-old-space-size=512 ./node_modules/typescript/bin/tsc --build
echo "Done."

echo ""
echo "=========================================="
echo "   Build Successful!"
echo "   Location: backend/iot-hotel-backend/dist"
echo "=========================================="
