#!/usr/bin/env bash
# PHASE 8 — ORACLE SECURITY & COMPLIANCE, sección 66/11.
# El catálogo de privilegios sensibles debe estar documentado y la severidad debe ser contextual
# (nunca uniforme) — verificado por presencia explícita de la palabra "contexto"/"nunca uniforme".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/security/powerful-privileges/SKILL.md"

for priv in DBA SYSDBA SYSOPER SYSASM SYSBACKUP SYSDG SYSKM "CREATE ANY" "GRANT ANY PRIVILEGE" "ALTER SYSTEM"; do
  grep -qF "$priv" "$S" && echo "[PASS] catálogo incluye $priv" || { echo "[FAIL] catálogo no incluye $priv"; FAIL=1; }
done

grep -qi "nunca.*uniforme\|nunca marca todos con igual severidad" "$S" \
  && echo "[PASS] severidad contextual declarada explícitamente" \
  || { echo "[FAIL] falta la declaración de severidad contextual"; FAIL=1; }

exit $FAIL
