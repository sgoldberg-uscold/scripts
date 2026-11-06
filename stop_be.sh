#!/usr/bin/env bash

set -u

server_name="BE"
wlp_home="${WLP_HOME:-$HOME/Documents/Projects/ALL_CONFIGS/wlp}"
server_command="$wlp_home/bin/server"
lock_file="$wlp_home/usr/servers/$server_name/workarea/.sLock"
stop_timeout_secs="${STOP_TIMEOUT_SECS:-90}"

if [[ ! -x "$server_command" ]]; then
    echo "Liberty server command is not executable: $server_command" >&2
    exit 1
fi

run_with_timeout() {
    local timeout_secs="$1"
    shift

    "$@" &
    local cmd_pid=$!
    local waited=0

    while kill -0 "$cmd_pid" 2>/dev/null; do
        if (( waited >= timeout_secs )); then
            kill -9 "$cmd_pid" 2>/dev/null
            wait "$cmd_pid" 2>/dev/null
            return 124
        fi
        sleep 1
        ((waited++))
    done

    wait "$cmd_pid"
}

force_kill_server() {
    local server_pids
    server_pids="$(pgrep -f "ws-server\.jar $server_name( |\$)" | while read -r pid; do
        ps -p "$pid" -o command= 2>/dev/null | grep -q -- '--stop' || echo "$pid"
    done)"

    if [[ -z "$server_pids" ]]; then
        echo "Could not find a running process for server $server_name to force-kill." >&2
        return 1
    fi

    echo "Force-killing server $server_name (PID(s): $(echo "$server_pids" | tr '\n' ' '))..."
    echo "$server_pids" | xargs kill -9 2>/dev/null
    sleep 1
}

status_output="$("$server_command" status "$server_name" 2>&1)"
status_code=$?

if [[ $status_code -eq 0 ]]; then
    echo "$status_output"
    echo "Stopping Liberty server $server_name..."

    run_with_timeout "$stop_timeout_secs" "$server_command" stop "$server_name" "$@"
    stop_exit=$?

    if [[ $stop_exit -ne 0 ]]; then
        if [[ $stop_exit -eq 124 ]]; then
            echo "Liberty did not stop server $server_name within ${stop_timeout_secs}s; forcing shutdown..." >&2
            force_kill_server
        else
            echo "Liberty could not stop server $server_name." >&2
            exit 1
        fi
    fi

    status_output="$("$server_command" status "$server_name" 2>&1)"
    status_code=$?
fi

if [[ $status_code -eq 0 ]]; then
    echo "Server $server_name is still running after the stop command." >&2
    exit 1
fi

if [[ "$status_output" != *"Server $server_name is not running."* ]]; then
    echo "$status_output" >&2
    echo "Unable to confirm that server $server_name stopped; the lock file was not removed." >&2
    exit 1
fi

if [[ -e "$lock_file" ]]; then
    if command -v lsof >/dev/null 2>&1 && lsof "$lock_file" >/dev/null 2>&1; then
        echo "The server lock is still held by a process: $lock_file" >&2
        exit 1
    fi

    rm "$lock_file"
    echo "Removed stale Liberty lock: $lock_file"
fi

echo "Liberty server $server_name is stopped."
