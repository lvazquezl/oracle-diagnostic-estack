#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 74.
# Nombre domain-prefixed porque test_collectors_read_only.sh ya existe (Fase 4, GI-scoped) y
# test_collectors_allowlisted genérico no existía — se prefija por consistencia y para dejar
# claro el alcance (docs/OS_READONLY_COLLECTOR_MODEL.md), mismo patrón que RMAN en Fase 7.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

grep -q 'allowlist: \[string\]' "$DOC" \
  && echo "[PASS] Collector Contract declara campo allowlist" \
  || { echo "[FAIL] falta el campo allowlist en el contrato"; FAIL=1; }

for c in get_os_identity get_cpu_topology get_memory_summary get_hugepages_status get_ipc_limits get_aio_limits get_multipath_summary; do
  grep -q "\`$c\`" "$DOC" \
    && echo "[PASS] $c documentado en el catálogo de collectors" \
    || { echo "[FAIL] falta $c en el catálogo"; FAIL=1; }
done

exit $FAIL
