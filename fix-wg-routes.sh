#!/usr/bin/env bash
: <<'DOC'
fix-wg-routes.sh

Purpose:
--------
Automatically fixes routing conflicts between WireGuard and Amnezia VPN on macOS.

Background:
-----------
Amnezia may inject highly specific host routes (/32) for IPs inside the WireGuard subnet
(e.g. 10.8.0.x) via the physical interface (typically en0).

macOS routing precedence prefers /32 over /24, so even though WireGuard installs:
    10.8.0.0/24 → utunX

these injected routes override it:
    10.8.0.1/32 → en0   ❌

Result:
-------
WireGuard shows "connected", but traffic never reaches the tunnel.

What this script does:
---------------------
1. Detects the WireGuard utun interface automatically from the subnet route
2. Finds and removes conflicting /32 routes pointing to the wrong interface
3. Reinstalls the correct subnet route via the WireGuard interface

Usage:
------
chmod +x fix-wg-routes.sh
sudo ./fix-wg-routes.sh

Optional variables:
-------------------
WG_SUBNET_PREFIX   (default: 10.8)
BAD_IFACE          (default: en0)

Example:
--------
sudo WG_SUBNET_PREFIX=10.9 ./fix-wg-routes.sh

Notes:
------
- This is a workaround. Amnezia may re-inject routes.
- Permanent fix: configure split tunneling in Amnezia and exclude the WG subnet.
DOC

set -euo pipefail

# macOS-only: BSD route(8) syntax is incompatible with Linux iproute2.
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ macOS-only. This script uses BSD route(8) syntax."
  exit 1
fi

# Must run as root — otherwise every sudo invocation below will either
# prompt repeatedly (interactive) or fail silently (non-interactive), and
# '|| true' would hide the failures.
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "❌ This script must run as root (use sudo)."
  exit 1
fi

# Prefix of WireGuard subnet (used to detect interface and filter routes)
WG_SUBNET_PREFIX="${WG_SUBNET_PREFIX:-10.8}"

# Canonical full CIDR, used for route add/delete operations
WG_SUBNET_CIDR="${WG_SUBNET_PREFIX}.0/24"

# BSD netstat collapses trailing zero octets in the Destination column
# (e.g. "10.8.0.0/24" is shown as "10.8/24"). Use this form for awk matching.
WG_NETSTAT_CIDR="${WG_SUBNET_PREFIX}/24"

# Split the prefix into octets for numeric comparison later. Assume /24, so
# the first three octets come from WG_SUBNET_PREFIX + ".0" (covers both
# "10.8" and "192.168.50" style prefixes).
IFS=. read -r WG_O1 WG_O2 WG_O3 _ <<< "${WG_SUBNET_PREFIX}.0.0"

# Interface that should NOT handle WireGuard traffic (usually Wi-Fi)
BAD_IFACE="${BAD_IFACE:-en0}"

# Detect WireGuard interface (utunX) by looking for the /24 route
WG_IFACE="$(netstat -rn -f inet | awk -v pfx="${WG_NETSTAT_CIDR}" '$1==pfx {print $4; exit}')"

if [[ -z "${WG_IFACE:-}" ]]; then
  echo "❌ Could not detect WireGuard interface for ${WG_SUBNET_CIDR}"
  echo "Make sure WireGuard is connected."
  exit 1
fi

# The /24 route we matched above might already belong to Amnezia (en0),
# not WireGuard. Refuse to "fix" by reinstalling via the wrong interface.
case "$WG_IFACE" in
  utun*) ;;
  *)
    echo "❌ Detected interface '$WG_IFACE' for ${WG_SUBNET_CIDR} is not a utun*."
    echo "   Amnezia (or something else) likely owns the route right now."
    echo "   Reconnect WireGuard first, then re-run this script."
    exit 1
    ;;
esac

if [[ "$WG_IFACE" == "$BAD_IFACE" ]]; then
  echo "❌ Detected WG interface equals BAD_IFACE ($BAD_IFACE). Aborting."
  exit 1
fi

echo "✅ Detected WireGuard interface: ${WG_IFACE}"
echo

echo "🔍 Scanning for conflicting routes..."
echo

# Parse routing table and remove conflicting host routes (/32 or bare UH).
# We compare octets numerically instead of matching a regex so that:
#   - non-default WG_SUBNET_PREFIX values (e.g. 192.168.50) work correctly
#   - BSD host routes printed without a /32 suffix (UH flag) are also caught
while read -r dest _ _ netif _; do
  [[ -z "${dest:-}" || "$netif" != "$BAD_IFACE" ]] && continue

  host="${dest%/32}"
  [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue

  IFS=. read -r o1 o2 o3 _ <<< "$host"
  if [[ "$o1" == "$WG_O1" && "$o2" == "$WG_O2" && "$o3" == "$WG_O3" ]]; then
    echo "⚠️  Removing conflicting route: $host via $BAD_IFACE"
    if ! sudo route -n delete "$host" >/dev/null 2>&1; then
      echo "   (note: route delete $host returned non-zero; continuing)"
    fi
  fi
done < <(netstat -rn -f inet | awk '$1 ~ /^[0-9]/ {print $1, $2, $3, $4, $5}')

echo
echo "🔧 Reinstalling subnet route via ${WG_IFACE}..."

# Ensure correct subnet route is installed via WireGuard.
# Pre-delete is best-effort — ENOENT is fine, anything else we still want to log.
if ! sudo route -n delete -net "${WG_SUBNET_CIDR}" >/dev/null 2>&1; then
  : # prior route may simply not exist; nothing to do
fi
sudo route -n add -net "${WG_SUBNET_CIDR}" -interface "${WG_IFACE}"

echo
echo "🧪 Verifying routing for ${WG_SUBNET_PREFIX}.0.1..."
verify_iface="$(route -n get "${WG_SUBNET_PREFIX}.0.1" 2>/dev/null | awk '/interface:/ {print $2}')"
if [[ "$verify_iface" != "$WG_IFACE" ]]; then
  echo "❌ Verification failed: ${WG_SUBNET_PREFIX}.0.1 still routes via '${verify_iface:-<none>}' (expected ${WG_IFACE})."
  echo "   Amnezia may have re-injected its routes between the fix and the check."
  exit 1
fi

echo "✅ Verified: ${WG_SUBNET_PREFIX}.0.0/24 now routes via ${WG_IFACE}."
