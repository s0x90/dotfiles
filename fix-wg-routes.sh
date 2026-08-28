#!/usr/bin/env bash
: <<'DOC'
fix-wg-routes.sh

Purpose:
--------
Automatically fixes routing conflicts between WireGuard and Amnezia VPN on macOS.

Background:
-----------
Amnezia may inject highly specific host routes (/32) for IPs inside the WireGuard
subnet (10.8.0.x) via the physical interface (typically en0).

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
2. Finds and removes conflicting host routes (/32 or bare UH) going through BAD_IFACE
3. Reinstalls the correct subnet route via the WireGuard interface
4. Verifies the final routing actually goes through utunX

Usage:
------
chmod +x fix-wg-routes.sh
sudo ./fix-wg-routes.sh

Scope:
------
- Hardcoded to the 10.8.0.0/24 WireGuard subnet.
- macOS only (BSD route(8) syntax).
- IPv4 only.

Optional variables:
-------------------
BAD_IFACE   Physical interface that should NOT own the WG subnet (default: en0).

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
# prompt repeatedly (interactive) or fail silently (non-interactive).
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "❌ This script must run as root (use sudo)."
  exit 1
fi

# ─── Subnet constants ────────────────────────────────────────────────────────
# Hardcoded: this WG install uses 10.8.0.0/24.
WG_SUBNET_CIDR="10.8.0.0/24"    # form used by route(8) add/delete
WG_NETSTAT_CIDR="10.8/24"       # BSD netstat prints "10.8.0.0/24" as "10.8/24"
WG_O1=10; WG_O2=8; WG_O3=0      # first three octets for host-route matching
WG_PROBE_HOST="10.8.0.1"        # address used for the final route-get probe

# Interface that should NOT handle WireGuard traffic (usually Wi-Fi)
BAD_IFACE="${BAD_IFACE:-en0}"

# ─── Detect the interface currently owning the /24 ───────────────────────────
WG_IFACE="$(netstat -rn -f inet | awk -v pfx="${WG_NETSTAT_CIDR}" '$1==pfx {print $4; exit}')"

if [[ -z "${WG_IFACE:-}" ]]; then
  echo "❌ Could not detect WireGuard interface for ${WG_SUBNET_CIDR}"
  echo "Make sure WireGuard is connected."
  exit 1
fi

# The /24 route we matched might already belong to Amnezia (en0), not WireGuard.
# Refuse to "fix" by reinstalling via the wrong interface.
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
# We compare octets numerically so both "10.8.0.3/32" and bare "10.8.0.2" (UH)
# forms get caught.
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

# Pre-delete is best-effort: on first run the route often doesn't exist yet,
# which route(8) reports as an error. We silently tolerate any failure here —
# if the subsequent 'route add' fails, that will surface loudly on its own.
sudo route -n delete -net "${WG_SUBNET_CIDR}" >/dev/null 2>&1 || true
sudo route -n add -net "${WG_SUBNET_CIDR}" -interface "${WG_IFACE}"

echo
echo "🧪 Verifying routing for ${WG_PROBE_HOST}..."
verify_iface="$(route -n get "${WG_PROBE_HOST}" 2>/dev/null | awk '/interface:/ {print $2}')"
if [[ "$verify_iface" != "$WG_IFACE" ]]; then
  echo "❌ Verification failed: ${WG_PROBE_HOST} still routes via '${verify_iface:-<none>}' (expected ${WG_IFACE})."
  echo "   Amnezia may have re-injected its routes between the fix and the check."
  exit 1
fi

echo "✅ Verified: ${WG_SUBNET_CIDR} now routes via ${WG_IFACE}."
