#!/usr/bin/env bash
# lib/logging.sh - small logging helper shared by all the scripts.
#
# Usage (inside another script):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/logging.sh"
#   log INFO "something happened"
#
# Every line looks like:
#   2026-10-27 14:05:11 [INFO] [disk-check.sh] Disk usage for / is 41%

# logs go next to the scripts, not wherever the user ran them from
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
LOG_FILE="$LOG_DIR/toolkit.log"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    mkdir -p "$LOG_DIR" 2>/dev/null

    # if the log file can't be written we still want the script to work
    printf '%s [%s] [%s] %s\n' "$timestamp" "$level" "$(basename "$0")" "$message" \
        >> "$LOG_FILE" 2>/dev/null || true
}
