#!/usr/bin/env bash
# system-info.sh - shows basic information about the Linux machine it runs on.
# Everything is read from the system when the script runs, nothing is hardcoded.
#
# Usage: ./system-info.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

# print one "label: value" line with the labels lined up
show() {
    printf '%-20s %s\n' "$1:" "$2"
}

get_os_name() {
    if [[ -r /etc/os-release ]]; then
        # run in a subshell so the variables from os-release don't leak out
        ( . /etc/os-release; echo "${PRETTY_NAME:-${NAME:-unknown}}" )
    else
        uname -o
    fi
}

get_uptime() {
    # "uptime -p" gives "up 3 hours, 12 minutes" but not every system has -p
    if uptime -p >/dev/null 2>&1; then
        uptime -p
    else
        local seconds
        seconds=$(cut -d. -f1 /proc/uptime)
        printf 'up %d days, %d hours, %d minutes\n' \
            $((seconds / 86400)) $((seconds % 86400 / 3600)) $((seconds % 3600 / 60))
    fi
}

get_cpu_model() {
    local model=""
    if command -v lscpu >/dev/null 2>&1; then
        model=$(lscpu | awk -F: '/^Model name/ {sub(/^[ \t]+/, "", $2); print $2; exit}')
    fi
    if [[ -z "$model" && -r /proc/cpuinfo ]]; then
        model=$(awk -F: '/model name/ {sub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo)
    fi
    echo "${model:-unknown}"
}

get_memory() {
    if command -v free >/dev/null 2>&1; then
        free -h | awk '/^Mem:/ {print $3 " used / " $2 " total (" $7 " available)"}'
    else
        awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2}
             END {printf "%.1f GiB total, %.1f GiB available\n", t/1048576, a/1048576}' /proc/meminfo
    fi
}

log INFO "Collecting system information"

echo "=============================="
echo "      System Information"
echo "=============================="
show "Hostname"          "$(hostname)"
show "Current user"      "$(id -un)"
show "Date/time"         "$(date '+%Y-%m-%d %H:%M:%S %Z')"
show "Operating system"  "$(get_os_name)"
show "Kernel version"    "$(uname -r)"
show "Architecture"      "$(uname -m)"
show "Uptime"            "$(get_uptime)"
show "CPU model"         "$(get_cpu_model)"
show "CPU cores"         "$(nproc)"
show "Memory"            "$(get_memory)"
show "Working directory" "$(pwd)"
echo "=============================="

log INFO "System information displayed for host $(hostname)"
exit 0
