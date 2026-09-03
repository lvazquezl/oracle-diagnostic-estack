#!/usr/bin/env bash
# Valida que ninguna query/tool certificada invoque verbos de cambio de srvctl/crsctl/systemctl.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='srvctl (start|stop|modify|add|remove|relocate)|crsctl (start|stop|modify|add|delete|relocate)|systemctl (start|stop|restart|enable|disable)'

for f in $(find "$ROOT/queries" -name 'Q-*.md') "$ROOT/mcp/tool-manifest.md" "$ROOT/collectors/README.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq "$PATTERN" "$f"; then
    echo "[FAIL] $f contiene un verbo de cambio de srvctl/crsctl/systemctl"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto certificado invoca srvctl/crsctl/systemctl de escritura"

exit $FAIL
