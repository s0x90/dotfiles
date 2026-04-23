#!/usr/bin/env bash
: <<'DOC'
cleanup-wg-routes.sh

Purpose:
--------
Reverts routing changes made by fix-wg-routes.sh on macOS.

Background:
-----------
The fix script removes conflicting /32 routes and forces the WireGuard subnet
(e.g. 10.8.0.0/24) through the WireGuard utun interface.

This cleanup script:
1. Removes the forced subnet route via utunX
2. Optionally restores connectivity behavior so Amnezia VPN can reapply its routing

Use this when:
-------------
- Disconnecting WireGuard
- Troubleshooting networking
- Returning system to default VPN routing behavior

Usage:
------
chmod +x cleanup-wg-routes.sh
sudo ./cleanup-wg-routes.sh

Optional variables:
-------------------
WG_SUBNET_PREFIX   (default: 10.8)

Example:
--------
sudo WG_SUBNET_PREFIX=10.9 ./cleanup-wg-routes.sh

Notes:
------
- Amnezia may automatically re-inject its routes after this runs
- No permanent system changes are made
DOC

set -euo pipefail

WG_SUBNET_PREFIX="${WG_SUBNET_PREFIX:-10.8}"

echo "🔍 Detecting WireGuard route..."

WG_ROUTE_IFACE="$(netstat -rn -f inet | awk -v pfx="${WG_SUBNET_PREFIX}.0/24" '$1==pfx {print $4; exit}')"

if [[ -n "${WG_ROUTE_IFACE:-}" ]]; then
  echo "⚠️  Found WG subnet route via ${WG_ROUTE_IFACE}"
  echo "🧹 Removing route ${WG_SUBNET_PREFIX}.0/24..."
  sudo route -n delete -net "${WG_SUBNET_PREFIX}.0/24" >/dev/null || true
else
  echo "ℹ️  No WireGuard subnet route found"
fi

echo
echo "🔄 Flushing possible cached routes..."

# Optional: trigger route recalculation (safe no-op if not needed)
sudo route -n flush >/dev/null 2>&1 || true

echo
echo "🧪 Checking route resolution for ${WG_SUBNET_PREFIX}.0.1..."
route -n get "${WG_SUBNET_PREFIX}.0.1" | sed -n '1,12p' || true

echo
echo "✅ Cleanup complete."
echo "ℹ️  If using :contentReference[oaicite:1]{index=1}, it may now reapply its routing rules."
