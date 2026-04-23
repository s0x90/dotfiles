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

# Prefix of WireGuard subnet (used to detect interface and filter routes)
WG_SUBNET_PREFIX="${WG_SUBNET_PREFIX:-10.8}"

# Canonical full CIDR, used for route add/delete operations
WG_SUBNET_CIDR="${WG_SUBNET_PREFIX}.0/24"

# BSD netstat collapses trailing zero octets in the Destination column
# (e.g. "10.8.0.0/24" is shown as "10.8/24"). Use this form for awk matching.
WG_NETSTAT_CIDR="${WG_SUBNET_PREFIX}/24"

# Interface that should NOT handle WireGuard traffic (usually Wi-Fi)
BAD_IFACE="${BAD_IFACE:-en0}"

# Detect WireGuard interface (utunX) by looking for the /24 route
WG_IFACE="$(netstat -rn -f inet | awk -v pfx="${WG_NETSTAT_CIDR}" '$1==pfx {print $4; exit}')"

if [[ -z "${WG_IFACE:-}" ]]; then
  echo "❌ Could not detect WireGuard interface for ${WG_SUBNET_CIDR}"
  echo "Make sure WireGuard is connected."
  exit 1
fi

echo "✅ Detected WireGuard interface: ${WG_IFACE}"
echo

echo "🔍 Scanning for conflicting routes..."
echo

# Parse routing table and remove conflicting /32 routes
while read -r dest gateway flags netif rest; do
  [[ -z "${dest:-}" ]] && continue

  # Match host routes inside the WG subnet going through BAD_IFACE
  if [[ "$dest" =~ ^${WG_SUBNET_PREFIX//./\\.}\.0\.[0-9]+/32$ && "$netif" == "$BAD_IFACE" ]]; then
    host="${dest%/32}"
    echo "⚠️  Removing conflicting route: $host via $BAD_IFACE"
    sudo route -n delete "$host" >/dev/null || true
  fi
done < <(netstat -rn -f inet | awk 'NR>4 {print $1, $2, $3, $4, $5}')

echo
echo "🔧 Reinstalling subnet route via ${WG_IFACE}..."

# Ensure correct subnet route is installed via WireGuard
sudo route -n delete -net "${WG_SUBNET_CIDR}" >/dev/null 2>&1 || true
sudo route -n add -net "${WG_SUBNET_CIDR}" -interface "${WG_IFACE}"

echo
echo "🧪 Verifying routing for ${WG_SUBNET_PREFIX}.0.1..."
route -n get "${WG_SUBNET_PREFIX}.0.1" | sed -n '1,12p'

echo
echo "✅ Done. If interface shows ${WG_IFACE}, routing is fixed."
