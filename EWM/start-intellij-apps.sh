#!/bin/bash

source ./config.sh

# Function to find and run configuration in any open IntelliJ instance
run_configuration_in_any_intellij() {
    local config_name=$1
    local max_attempts=3
    
    echo "Looking for '$config_name' configuration in any open IntelliJ instance..."
    
    for attempt in $(seq 1 $max_attempts); do
        echo "Attempt $attempt: Searching for '$config_name'..."
        
        osascript << EOF
tell application "System Events"
    set intellijProcesses to every process whose name contains "IntelliJ"
    repeat with intellijProcess in intellijProcesses
        try
            tell intellijProcess to set frontmost to true
            delay 1
            
            -- Try to open run configurations
            keystroke "r" using {control down, option down}
            delay 2
            
            -- Clear any existing text and type the configuration name
            keystroke "a" using {command down}
            delay 0.5
            key code 51  -- delete key
            delay 0.5
            type text "$config_name"
            delay 2
            
            -- Check if configuration is found by looking for the run button state
            -- If found, press Enter to run
            key code 36  -- Enter key
            delay 1
            
            -- If we get here, configuration was found and started
            return true
        on error
            -- This IntelliJ instance doesn't have the configuration, try next
        end try
    end repeat
    return false
end tell
EOF
        
        if [ $? -eq 0 ]; then
            echo "✓ Found and started '$config_name'"
            return 0
        fi
        
        echo "Configuration '$config_name' not found, trying again..."
        sleep 2
    done
    
    echo "✗ Failed to find '$config_name' configuration in any IntelliJ instance"
    return 1
}

# Function to wait for Spring Boot application startup
wait_for_spring_boot_startup() {
    local app_name=$1
    local log_path=$2
    local timeout_minutes=$3

    echo "Waiting for $app_name to start (up to $timeout_minutes minutes)..."

    local timeout=$((timeout_minutes * 60))
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        # Check if Spring Boot app has started by looking for Java process
        if pgrep -f "java.*$app_name" > /dev/null; then
            echo "$app_name started successfully!"
            return 0
        fi
        
        # Also check log files if they exist
        if [ -d "$log_path" ] && grep -q "Started.*Application" $log_path/*.log 2>/dev/null; then
            echo "$app_name started successfully (found in logs)!"
            return 0
        fi

        sleep 15
        elapsed=$((elapsed + 15))
        echo "Still waiting for $app_name... (${elapsed}s elapsed)"
    done

    echo "$app_name startup timed out after $timeout_minutes minutes!"
    return 1
}

echo "=== Starting IntelliJ Applications ==="

# Ensure both IntelliJ projects are open
open_intellij_project() {
    local project_path=$1
    local project_name=$2

    echo "Ensuring $project_name project is open in IntelliJ..."
    open -a "IntelliJ IDEA" "$project_path"
    sleep 5
}

open_intellij_project "$BE_PROJECT_PATH" "BE"
open_intellij_project "$RFBE_PROJECT_PATH" "RF-BE"

echo "=== Starting Debug Configurations ==="

# Start BE configuration (search in any IntelliJ)
echo "Starting BE debug configuration..."
if ! run_configuration_in_any_intellij "$BE_CONFIG_NAME"; then
    echo "Failed to start BE configuration"
    exit 1
fi

# Wait for BE to start
if ! wait_for_spring_boot_startup "BE" "$BE_LOG_PATH" 10; then
    echo "BE startup failed or timed out"
    exit 1
fi

# Start RF-BE configuration (search in any IntelliJ)
echo "Starting RF-BE debug configuration..."
if ! run_configuration_in_any_intellij "$RFBE_CONFIG_NAME"; then
    echo "Failed to start RF-BE configuration"
    exit 1
fi

# Wait for RF-BE to start
if ! wait_for_spring_boot_startup "RF-BE" "$RFBE_LOG_PATH" 5; then
    echo "RF-BE startup failed or timed out"
    exit 1
fi

echo "=== All Applications Started Successfully! ==="
echo "✓ BE: Running"
echo "✓ RF-BE: Running"