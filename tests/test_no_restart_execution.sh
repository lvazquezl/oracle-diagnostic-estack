#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: ningún artefacto del dominio incident
# reinicia servicios/listener/instancia/base de datos, ni relocaliza un servicio RAC.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='srvctl (start|stop|restart|relocate)|systemctl (start|stop|restart)|lsnrctl (stop|start|reload)|SHUTDOWN\s+(IMMEDIATE|ABORT|TRANSACTIONAL)|STARTUP\b'

for f in $(find "$ROOT/skills/incident" "$ROOT/agents/incident-root-cause-analyst" -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|bloquead|NOT_EXECUTED'; then
      echo "[FAIL] $f:$lineno contiene un patrón de restart/relocate sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -nE "$PATTERN" "$f")
done

grep -qi 'reiniciar servicios/listener/instancia/base de datos, o relocate de servicio RAC' \
  "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] incident-root-cause-analyst declara explícitamente la prohibición de reiniciar/relocalizar" \
  || { echo "[FAIL] falta la prohibición explícita de restart/relocate"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto de incident ejecuta restart/relocate de servicio"
exit $FAIL
