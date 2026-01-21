#!/bin/bash

source ./config.sh

echo "=== Starting Services ==="

# Start Hazelcast
echo "Starting Hazelcast..."
nohup "$HAZELCAST_SCRIPT" > hazelcast.log 2>&1 &
echo $! > .hazelcast.pid
echo "Hazelcast started with PID $(cat .hazelcast.pid)"

# Start uscs_auth
echo "Starting uscs_auth..."
nohup "$USCS_AUTH_SCRIPT" > uscs_auth.log 2>&1 &
echo $! > .uscs_auth.pid
echo "uscs_auth started with PID $(cat .uscs_auth.pid)"

# Wait a moment for services to initialize
sleep 5

echo "=== Services Started ==="
echo "✓ Hazelcast: PID $(cat .hazelcast.pid)"
echo "✓ uscs_auth: PID $(cat .uscs_auth.pid)"
echo ""
echo "Check logs: hazelcast.log, uscs_auth.log"
echo "To start IntelliJ applications: ./start-intellij-apps.sh"