#!/usr/bin/env bash
# disk-check.sh - checks how full a filesystem is against a threshold.
#
# Usage: ./disk-check.sh <threshold> [path]
#   threshold  whole number from 1 to 100 (percent)
#   path       file or folder on the filesystem to check (default: /)
#
# Exit codes:
#   0  usage is below the threshold
#   1  usage is at or above the threshold (or df could not read the disk)
#   2  invalid input

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

usage() {
    echo "Usage: $(basename "$0") <threshold 1-100> [path]" >&2
    echo "Example: $(basename "$0") 80 /home" >&2
}

# ---- check the arguments ----

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Error: expected 1 or 2 arguments, got $#" >&2
    usage
    log ERROR "Invalid number of arguments: $#"
    exit 2
fi

threshold="$1"
path="${2:-/}"

# only digits allowed, so things like "abc", "-5" or "50.5" are rejected
if ! [[ "$threshold" =~ ^[0-9]+$ ]]; then
    echo "Error: threshold must be a whole number, got '$threshold'" >&2
    usage
    log ERROR "Non-numeric threshold: '$threshold'"
    exit 2
fi

# 10# makes bash read it as base 10 (so "08" doesn't break)
threshold=$((10#$threshold))

if (( threshold < 1 || threshold > 100 )); then
    echo "Error: threshold must be between 1 and 100, got $threshold" >&2
    usage
    log ERROR "Threshold out of range: $threshold"
    exit 2
fi

if [[ ! -e "$path" ]]; then
    echo "Error: path '$path' does not exist" >&2
    log ERROR "Path does not exist: $path"
    exit 2
fi

# ---- read the disk usage ----

# -P keeps each filesystem on one line so awk can read column 5 safely
df_line=$(df -P "$path" 2>/dev/null | awk 'NR == 2')

if [[ -z "$df_line" ]]; then
    echo "Error: could not read disk usage for '$path'" >&2
    log ERROR "df failed for path: $path"
    exit 1
fi

filesystem=$(echo "$df_line" | awk '{print $1}')
mount_point=$(echo "$df_line" | awk '{print $6}')
used_percent=$(echo "$df_line" | awk '{gsub("%", "", $5); print $5}')

echo "=============================="
echo "         Disk Check"
echo "=============================="
echo "Path:        $path"
echo "Filesystem:  $filesystem"
echo "Mounted on:  $mount_point"
echo "Disk usage:  ${used_percent}%"
echo "Threshold:   ${threshold}%"
echo
df -h "$path"
echo

if (( used_percent >= threshold )); then
    echo "WARNING: disk usage ${used_percent}% has reached the ${threshold}% threshold"
    log WARN "Disk usage for $path is ${used_percent}% (threshold ${threshold}%) - ALERT"
    exit 1
fi

echo "OK: disk usage ${used_percent}% is below the ${threshold}% threshold"
log INFO "Disk usage for $path is ${used_percent}% (threshold ${threshold}%) - OK"
exit 0
