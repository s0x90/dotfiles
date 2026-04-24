#!/usr/bin/env bash
: <<'DOC'
cleanup-wg-routes.sh

Purpose:
--------
Reverts the /24 route installed by fix-wg-routes.sh on macOS.

Background:
-----------
fix-wg-routes.sh forces the WireGuard subnet (10.8.0.0/24) through the
WireGuard utun interface. This cleanup script removes that /24 route.

Caveats:
--------
- This is NOT a full revert. fix-wg-routes.sh also deletes Amnezia's /32
  routes; this script does not restore them. Those routes only come back
  when Amnezia itself reapplies its config (reconnect, policy refresh, etc.).
- By default, the /24 is only deleted if it currently goes via utun*. If
  another interface (e.g. Amnezia on en0) has taken ownership of the route
  in the meantime, the delete is skipped to avoid disrupting that VPN.
  Override with FORCE_DELETE=1 if you explicitly want to clear it anyway.
- macOS only (uses BSD route(8) syntax).
- IPv4 only. IPv6 routes are not touched.

Use this when:
-------------
- Disconnecting WireGuard
- Troubleshooting networking
- Returning system to default VPN routing behavior

Usage:
------
chmod +x cleanup-wg-routes.sh
sudo ./cleanup-wg-routes.sh

Scope:
------
- Hardcoded to the 10.8.0.0/24 WireGuard subnet.

Optional variables:
-------------------
FORCE_DELETE       (default: 0) — if set to 1, delete the /24 even when it is
                   not currently owned by a utun* interface. Risky: may
                   disrupt other VPNs (Amnezia, etc.) that have taken over
                   the route.
FLUSH_ALL          (default: 0) — if set to 1, flushes the entire IPv4
                   routing table. DESTRUCTIVE: drops default/LAN/VPN routes
                   system-wide. Only use for deep troubleshooting.

Notes:
------
- Amnezia may automatically re-inject its routes after this runs
- No permanent system changes are made
DOC

set -euo pipefail

# macOS-only guard.
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ macOS-only. This script uses BSD route(8) syntax."
  exit 1
fi

# Must run as root.
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "❌ This script must run as root (use sudo)."
  exit 1
fi

# ─── Subnet constants ────────────────────────────────────────────────────────
# Hardcoded: this WG install uses 10.8.0.0/24.
WG_SUBNET_CIDR="10.8.0.0/24"    # form used by route(8) add/delete
WG_NETSTAT_CIDR="10.8/24"       # BSD netstat prints "10.8.0.0/24" as "10.8/24"
WG_PROBE_HOST="10.8.0.1"        # address used for the final route-get probe

echo "🔍 Detecting WireGuard route..."

WG_ROUTE_IFACE="$(netstat -rn -f inet | awk -v pfx="${WG_NETSTAT_CIDR}" '$1==pfx {print $4; exit}')"

if [[ -z "${WG_ROUTE_IFACE:-}" ]]; then
  echo "ℹ️  No ${WG_SUBNET_CIDR} route found"
else
  echo "⚠️  Found WG subnet route via ${WG_ROUTE_IFACE}"

  # Only delete if the route currently goes via utun* (i.e. it's ours),
  # unless the user explicitly overrides with FORCE_DELETE=1.
  case "$WG_ROUTE_IFACE" in
    utun*)
      delete_ok=1
      ;;
    *)
      if [[ "${FORCE_DELETE:-0}" == "1" ]]; then
        echo "⚠️  FORCE_DELETE=1 set — deleting route despite non-utun* owner."
        delete_ok=1
      else
        echo "ℹ️  Route is owned by '${WG_ROUTE_IFACE}', not a utun*."
        echo "   Not our /24 to clean up — leaving it alone."
        echo "   Set FORCE_DELETE=1 to override."
        delete_ok=0
      fi
      ;;
  esac

  if [[ "$delete_ok" == "1" ]]; then
    echo "🧹 Removing route ${WG_SUBNET_CIDR}..."
    if ! sudo route -n delete -net "${WG_SUBNET_CIDR}" >/dev/null 2>&1; then
      echo "   (note: route delete ${WG_SUBNET_CIDR} returned non-zero; continuing)"
    fi
  fi
fi

# Full-table route flush is destructive (wipes default route, LAN, other VPNs).
# Opt-in only via FLUSH_ALL=1 for users who really want it.
if [[ "${FLUSH_ALL:-0}" == "1" ]]; then
  echo
  echo "⚠️  FLUSH_ALL=1 set — flushing the entire IPv4 routing table."
  echo "    This will drop default/LAN/VPN routes system-wide."
  sudo route -n flush >/dev/null 2>&1 || true
fi

echo
echo "🧪 Checking route resolution for ${WG_PROBE_HOST}..."
route -n get "${WG_PROBE_HOST}" | sed -n '1,12p' || true

echo
echo "✅ Cleanup complete."
echo "ℹ️  If using Amnezia VPN, it may now reapply its routing rules."
