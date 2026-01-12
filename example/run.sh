#!/bin/bash

# Nexus Studio Launch Script
# Starts the relay server in the background and launches the Flutter app.

# Function to cleanup background processes on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down Nexus Studio..."
    kill $(jobs -p) 2>/dev/null
    exit
}

trap cleanup INT TERM EXIT

echo "--------------------------------------------"
echo "🚀 NEXUS STUDIO: Starting Collaborative Environment"
echo "--------------------------------------------"

# 1. Start Server
echo "📦 [1/2] Launching Relay Server..."
cd server
dart pub get > /dev/null
dart run bin/server.dart &
SERVER_PID=$!
cd ..

# 2. Start App
echo "📱 [2/2] Launching Flutter App ..."
cd app
flutter pub get > /dev/null

# Default to chrome (use -d <device> to change)
DEVICE="chrome"
if [[ "$*" == *"-d"* ]]; then
    # Pass through device arguments if provided
    flutter run "$@"
else
    flutter run -d $DEVICE
fi

# Wait for all background processes
wait
