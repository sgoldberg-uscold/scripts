#!/bin/bash

# Service script paths
export HAZELCAST_SCRIPT="/Users/sgoldberg/Documents/Projects/scripts/start_hazelcast.sh"
export USCS_AUTH_SCRIPT="/Users/sgoldberg/Documents/Projects/scripts/start_uscs_auth.sh"
# Configuration file for startup scripts
export BE_PROJECT_PATH="$HOME/Documents/Projects/USCS-BE"
export RFBE_PROJECT_PATH="$HOME/Documents/Projects/USCS-RF-BE"
# Log paths - Spring Boot typically logs to these locations
export BE_LOG_PATH="$BE_PROJECT_PATH/logs"
export RFBE_LOG_PATH="$RFBE_PROJECT_PATH/logs"
# IntelliJ console log files (these capture the Run window output)
export BE_CONSOLE_LOG="$HOME/.IntelliJ*/system/log/idea.log"
export RFBE_CONSOLE_LOG="$HOME/.IntelliJ*/system/log/idea.log"

# Run configuration names (adjust these to match your actual configuration names)
export BE_CONFIG_NAME="BE"
export RFBE_CONFIG_NAME="RF-BE"