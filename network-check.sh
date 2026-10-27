#!/usr/bin/env bash
# network-check.sh - basic network checks for a host.
#
# Usage: ./network-check.sh <hostname-or-ip> [port]
#
# Exit codes:
#   0  all checks passed
#   1  a network check failed (host did not resolve, not reachable, port closed)
#   2  invalid input

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

usage() {
    echo "Usage: $(basename "$0") <hostname-or-ip> [port]" >&2
    echo "Example: $(basename "$0") google.com 443" >&2
}

invalid_input() {
    echo "Error: $1" >&2
    usage
    log ERROR "Invalid input: $1"
    exit 2
}

# ---- check the arguments ----
# everything is validated before any network command runs

if [[ $# -lt 1 || $# -gt 2 ]]; then
    invalid_input "expected 1 or 2 arguments, got $#"
fi

host="$1"
port="${2:-}"

if [[ -z "$host" ]]; then
    invalid_input "host cannot be empty"
fi

# max length of a hostname is 253 characters
if (( ${#host} > 253 )); then
    invalid_input "host name is too long"
fi

# letters, numbers, dots, hyphens (hostnames/IPv4) and colons (IPv6) only.
# this also stops things like spaces, ; or $( ) getting into later commands
if ! [[ "$host" =~ ^[A-Za-z0-9.:-]+$ ]] || [[ "$host" == -* ]]; then
    invalid_input "'$host' is not a valid hostname or IP address"
fi

if [[ -n "$port" ]]; then
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        invalid_input "port must be a number, got '$port'"
    fi
    # leading zeros like 0080 are fine, read it as base 10
    port=$((10#$port))
    if (( port < 1 || port > 65535 )); then
        invalid_input "port must be between 1 and 65535, got $port"
    fi
fi

log INFO "Starting network check for host=$host port=${port:-none}"

# ---- resolve the host ----

echo "=============================="
echo "        Network Check"
echo "=============================="
echo "Host: $host"
echo

echo "--- DNS resolution ---"
addresses=$(getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u)

if [[ -z "$addresses" ]]; then
    echo "FAIL: could not resolve '$host'"
    log ERROR "Could not resolve $host"
    exit 1
fi

echo "Resolved addresses:"
echo "$addresses" | sed 's/^/  /'
log INFO "Resolved $host to $(echo "$addresses" | tr '\n' ' ')"
exit 0
