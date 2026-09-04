#!/usr/bin/env bash
# Valida que ningún *.sh/*.bash del repositorio contenga CRLF, y que todo *.sh tenga un shebang
# válido (# 37 PORTABILITY TEST, # 55 PORTABILITY QUALITY GATE).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

# -U (--binary): en Git Bash/MSYS, grep normalmente abre archivos en modo texto y descarta CR al
# final de línea antes de matchear (ver `grep --help` -> "-U, --binary  do not strip CR characters
# at EOL (MSDOS/Windows)") — sin -U este test nunca detectaría un CRLF real en este entorno,
# aunque el archivo sí lo tuviera. -P '\r' (en vez de $'\r' de bash) porque el byte CR literal
# dentro del propio script de test puede normalizarse al escribir el archivo — \r como patrón PCRE
# lo interpreta el motor de grep en tiempo de ejecución, nunca depende de un byte CR real guardado
# en este archivo.
CRLF_FILES=$(grep -rlUP '\r' --include='*.sh' --include='*.bash' "$ROOT" 2>/dev/null || true)
if [ -n "$CRLF_FILES" ]; then
  echo "[FAIL] Los siguientes scripts contienen CRLF:"
  echo "$CRLF_FILES"
  FAIL=1
else
  echo "[PASS] Ningún *.sh/*.bash contiene CRLF"
fi

BAD_SHEBANG=0
for f in $(find "$ROOT" -name '*.sh'); do
  first_line=$(head -c 64 "$f")
  case "$first_line" in
    "#!/usr/bin/env bash"*|"#!/bin/bash"*) : ;;
    *)
      echo "[FAIL] $f no tiene un shebang bash válido (primera línea: $first_line)"
      BAD_SHEBANG=1
      ;;
  esac
done
[ "$BAD_SHEBANG" -eq 0 ] && echo "[PASS] Todo *.sh tiene un shebang bash válido" || FAIL=1

[ -f "$ROOT/.gitattributes" ] && echo "[PASS] .gitattributes existe" || { echo "[FAIL] falta .gitattributes"; FAIL=1; }
grep -q '\*\.sh.*eol=lf' "$ROOT/.gitattributes" 2>/dev/null && echo "[PASS] .gitattributes fuerza eol=lf para *.sh" || { echo "[FAIL] .gitattributes no fuerza eol=lf para *.sh"; FAIL=1; }

exit $FAIL
