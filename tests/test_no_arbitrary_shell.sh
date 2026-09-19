#!/usr/bin/env bash
# Valida que ningún artefacto certificado exponga shell arbitrario (# 21, # 78 del prompt de Fase 4).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='execute_shell|run_command|shell_exec|os\.system\(|subprocess\.(run|call|Popen|check_output)\('

for f in $(find "$ROOT/parsers" "$ROOT/mcp" "$ROOT/collectors" "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT/docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md" "$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md" "$ROOT/agents/os-platform-analyst" "$ROOT/skills/os" \( -name '*.py' -o -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  # Ventana de 3 líneas antes de cada match: si "nunca/never/prohibid/forbidden/NUNCA expone"
  # aparece en esa ventana (encabezado de sección o misma línea), es prosa documentando la
  # prohibición, no una declaración real de la capacidad.
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|forbidden|not exposed|no expone'; then
      echo "[FAIL] $f:$lineno contiene un patrón de shell arbitrario sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -nE "$PATTERN" "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto certificado expone shell arbitrario"

# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 81 (# 60 del prompt: NO ARBITRARY SHELL).
M="$ROOT/agents/capacity-analyst/manifest.yaml"
[ -f "$M" ] || { echo "[FAIL] falta $M"; FAIL=1; }
if [ -f "$M" ]; then
  grep -q 'shell arbitrario' "$M" && echo "[PASS] capacity-analyst declara la prohibición de shell arbitrario" || { echo "[FAIL] falta la prohibición de shell arbitrario en capacity-analyst"; FAIL=1; }
fi

# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION (NO ARBITRARY SHELL).
MI="$ROOT/agents/incident-root-cause-analyst/manifest.yaml"
[ -f "$MI" ] || { echo "[FAIL] falta $MI"; FAIL=1; }
if [ -f "$MI" ]; then
  grep -q 'shell arbitrario' "$MI" && echo "[PASS] incident-root-cause-analyst declara la prohibición de shell arbitrario" || { echo "[FAIL] falta la prohibición de shell arbitrario en incident-root-cause-analyst"; FAIL=1; }
fi

exit $FAIL
