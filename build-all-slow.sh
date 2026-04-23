#!/bin/bash

# ==========================================
#   Smart Hotel Project - Sequential Build All
#   Sequential execution to minimize resource usage
# ==========================================

# Exit on error
set -e

# Record current directory
ROOT_DIR=$(pwd)

echo "##########################################"
echo "#                                        #"
echo "#      Smart Hotel Build Sequential      #"
echo "#                                        #"
echo "##########################################"
echo ""

# Build Backend first
echo "--- Step 1: Building Backend ---"
cd "$ROOT_DIR/backend/iot-hotel-backend"
chmod +x build-slow.sh
./build-slow.sh

echo ""
echo "--- Step 2: Building Frontend ---"
cd "$ROOT_DIR/frontend/iot-hotel-web"
chmod +x build-slow.sh
./build-slow.sh

echo ""
echo "##########################################"
echo "#                                        #"
echo "#      Full Build Complete (Sequential)  #"
echo "#                                        #"
echo "##########################################"
