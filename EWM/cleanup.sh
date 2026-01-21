#!/bin/bash

echo "=== Shutting down applications (keeping IntelliJ open) ==="

# Stop Hazelcast
if [ -f .hazelcast.pid ]; then
    HAZELCAST_PID=$(cat .hazelcast.pid)
    kill $HAZELCAST_PID 2>/dev/null
    rm .hazelcast.pid
    echo "Hazelcast stopped"
fi

# Stop uscs_auth
if [ -f .uscs_auth.pid ]; then
    USCS_AUTH_PID=$(cat .uscs_auth.pid)
    kill $USCS_AUTH_PID 2>/dev/null
    rm .uscs_auth.pid
    echo "uscs_auth stopped"
fi

# Stop BE debug application (but not IntelliJ)
echo "Stopping BE debug application..."
osascript -e 'tell application "IntelliJ IDEA" to activate' \
          -e 'delay 1' \
          -e 'tell application "System Events" to keystroke "F2" using {command down}' # Stop debug session

# Stop RF-BE debug application (but not IntelliJ)
echo "Stopping RF-BE debug application..."
# Switch to RF-BE IntelliJ window and stop
osascript -e 'tell application "System Events" to keystroke "`" using {command down}' \
          -e 'delay 1' \
          -e 'tell application "System Events" to keystroke "F2" using {command down}' # Stop debug session

# Clean up PID files but don't kill IntelliJ processes
if [ -f .be_intellij.pid ]; then
    rm .be_intellij.pid
    echo "BE IntelliJ PID file cleaned up (IntelliJ left running)"
fi

if [ -f .rfbe_intellij.pid ]; then
    rm .rfbe_intellij.pid  
    echo "RF-BE IntelliJ PID file cleaned up (IntelliJ left running)"
fi

# Alternative: Kill specific Java processes for BE and RF-BE applications
echo "Stopping Java application processes..."
pkill -f "java.*BE.*debug"
pkill -f "java.*RF-BE.*debug" 
pkill -f "java.*ewms-rfear"

echo "=== Application cleanup complete! ==="
echo "Hazelcast: stopped"
echo "uscs_auth: stopped" 
echo "BE debug: stopped"
echo "RF-BE debug: stopped"
echo "IntelliJ instances: still running for faster restart"
echo ""
echo "To restart applications, run: ./start-intellij-apps.sh"
echo "To stop IntelliJ completely, run: pkill -f 'IntelliJ IDEA'"