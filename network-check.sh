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
echo

# from here on we keep going even if one check fails, and report at the end
failed=0

# try to open a TCP connection, gives up after 3 seconds
# $1 = host, $2 = port. Uses bash's built in /dev/tcp so no extra tools needed
tcp_check() {
    timeout 3 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$1" "$2" 2>/dev/null
}

# ---- basic connectivity ----

echo "--- Connectivity ---"
if command -v ping >/dev/null 2>&1; then
    if ping -c 2 -W 2 "$host" >/dev/null 2>&1; then
        echo "OK: $host replied to ping"
        log INFO "Ping to $host succeeded"
    else
        echo "FAIL: $host did not reply to ping (it may be down or blocking ICMP)"
        log WARN "Ping to $host failed"
        failed=1
    fi
elif [[ -n "$port" ]]; then
    # no ping, but the TCP port check below already tells us if the host is reachable
    echo "ping is not installed, the TCP port check below will be used instead"
    log INFO "ping not installed, relying on TCP port $port check"
else
    # some minimal systems/containers don't have ping, so try common web ports instead
    echo "ping is not installed, trying a TCP connection on port 80/443 instead"
    if tcp_check "$host" 80 || tcp_check "$host" 443; then
        echo "OK: $host accepted a TCP connection on port 80 or 443"
        log INFO "TCP fallback connectivity to $host succeeded"
    else
        echo "FAIL: could not connect to $host on port 80 or 443"
        log WARN "TCP fallback connectivity to $host failed"
        failed=1
    fi
fi
echo

# ---- network interfaces ----

echo "--- Network interfaces ---"
if command -v ip >/dev/null 2>&1; then
    ip -brief address show
elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig -a
else
    # last option: read the interface list straight from /sys
    for iface in /sys/class/net/*; do
        name=$(basename "$iface")
        state=$(cat "$iface/operstate" 2>/dev/null || echo unknown)
        mac=$(cat "$iface/address" 2>/dev/null || echo unknown)
        printf '%-12s %-8s %s\n' "$name" "$state" "$mac"
    done
fi
log INFO "Displayed network interface information"
echo

# ---- TCP port (only if a port was given) ----

if [[ -n "$port" ]]; then
    echo "--- TCP port $port ---"
    if tcp_check "$host" "$port"; then
        echo "OK: port $port on $host is open"
        log INFO "TCP port $port on $host is open"
    else
        echo "FAIL: port $port on $host is closed or not reachable"
        log WARN "TCP port $port on $host is closed or unreachable"
        failed=1
    fi
    echo
fi

# ---- summary ----

if (( failed == 0 )); then
    echo "Result: all checks passed for $host"
    log INFO "Network check for $host finished - all checks passed"
    exit 0
fi

echo "Result: one or more checks failed for $host"
log WARN "Network check for $host finished - some checks failed"
exit 1
