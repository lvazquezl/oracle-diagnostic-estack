#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 67.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/cpu-topology/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
for kw in logical_cpus physical_cores sockets numa_nodes; do
  grep -qi "$kw" "$S" && echo "[PASS] declara $kw" || { echo "[FAIL] falta $kw"; FAIL=1; }
done
grep -qi 'nunca cambia CPU affinity' "$S" && echo "[PASS] prohíbe cambiar CPU affinity" || { echo "[FAIL] falta la prohibición de CPU affinity"; FAIL=1; }
exit $FAIL
