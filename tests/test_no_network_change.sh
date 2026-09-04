#!/usr/bin/env bash
# Ningún collector/parser modifica bonding/VLAN/route/MTU/firewall/sysctl (# 34, # 79).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='ip (link set|addr add|route add|route del)|sysctl -w|iptables -[AI]|firewall-cmd --add|nmcli.*modify'

for f in "$ROOT"/parsers/rac/*.py "$ROOT/docs/GI_READONLY_COLLECTORS.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq "$PATTERN" "$f"; then
    echo "[FAIL] $f contiene un comando de cambio de red"
    FAIL=1
  fi
done

grep -qi 'nunca cambian bonding, vlan, route, mtu, firewall ni sysctl' "$ROOT/docs/GI_READONLY_COLLECTORS.md" \
  && echo "[PASS] docs/GI_READONLY_COLLECTORS.md prohíbe explícitamente cambios de red" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto modifica configuración de red"
exit $FAIL
