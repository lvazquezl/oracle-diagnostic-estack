#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 46/15.
#
# PHASE 7 — RMAN SECURITY TEST ROBUSTNESS MICRO-HARDENING: corrige un falso negativo. El test
# original clasificaba la mera presencia textual de execute_rman()/run_rman()/rman_shell() como
# capacidad insegura, sin distinguir una declaración de PROHIBICIÓN (bloque forbidden_capabilities:)
# de una capacidad real permitida/ejecutable (allowed_tools:/allowed_capabilities:/collectors:/
# tools:/execution:/runtime:/actions:) — fallaba sobre
# agents/oracle-backup-recovery-analyst/manifest.yaml:91 pese a vivir dentro de
# forbidden_capabilities: (línea 78), por dos causas combinadas: (1) la ventana de sólo 3 líneas
# hacia atrás no alcanza a ver la clave YAML envolvente 13 líneas arriba, y (2) el wildcard
# 'ning.n' no empareja los 2 bytes UTF-8 de "ningún" en este entorno (el punto no cruza
# secuencias multibyte aquí). Ver docs/PHASE_7_RMAN_SECURITY_TEST_ROBUSTNESS_HARDENING.md.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-backup-recovery-analyst/manifest.yaml"

grep -qi 'execute_rman(command) / run_rman(command) / rman_shell(command)' "$MANIFEST" && echo "[PASS] manifest prohíbe explícitamente execute_rman/run_rman/rman_shell" || { echo "[FAIL] falta la prohibición explícita de wrappers de ejecución arbitraria"; FAIL=1; }

PATTERN='execute_rman\(|run_rman\(|rman_shell\('

# Lenguaje de prohibición explícito — SIN wildcard sobre bytes multibyte (# 13 del prompt de este
# hardening: "no depender de regex frágil sobre caracteres multibyte"). 'ningún'/'ningun' se listan
# literalmente en vez de 'ning.n' (que no empareja los 2 bytes UTF-8 de 'ú' en este entorno).
PROHIBITION_WORDS='nunca|never|prohibid|forbidden|no existe|not implement|ningún|ningun'

# Claves YAML top-level (# 7/# 9 del prompt) bajo las que la mera presencia del patrón es
# documentación de una prohibición — PASS estructural, sin depender de lenguaje natural cercano.
FORBIDDEN_SECTION_KEYS='^(forbidden_capabilities|blocked_capabilities|prohibited_capabilities|prohibited)$'
# Claves YAML top-level (# 10 del prompt) bajo las que la presencia del patrón es una capacidad
# real ejecutable — FAIL duro, sin excepción de lenguaje cercano.
ALLOWED_SECTION_KEYS='^(allowed_tools|allowed_capabilities|collectors|tools|execution|runtime|actions)$'

# classify_yaml_section: imprime la última clave YAML top-level (sin indentación) que aparece en
# las líneas 1..$2 del archivo $1. NO es un parser YAML completo (# 8 del prompt: "no inventar un
# parser YAML complejo si no es necesario") — sólo localiza la sección declarativa envolvente más
# cercana, que es todo lo que este chequeo necesita.
classify_yaml_section() {
  awk -v target="$2" '
    NR > target { exit }
    /^[A-Za-z_][A-Za-z0-9_-]*:/ { key=$0; sub(/:.*/, "", key); last_key=key }
    END { print last_key }
  ' "$1"
}

# check_match: clasifica una ocurrencia del patrón peligroso en $1:$2 como PASS (documentación de
# prohibición) o FAIL (capacidad real / sin contexto reconocible). Structure-aware para YAML
# (# 7 del prompt); fallback a ventana de lenguaje de prohibición para el resto (.md/.py/etc, o
# YAML sin sección declarativa reconocida) — el mismo fallback que ya existía, con el wildcard
# UTF-8 corregido.
check_match() {
  local f="$1" lineno="$2"
  case "$f" in
    *.yaml|*.yml)
      local section
      section=$(classify_yaml_section "$f" "$lineno")
      if echo "$section" | grep -qiE "$FORBIDDEN_SECTION_KEYS"; then
        echo "PASS"; return
      fi
      if echo "$section" | grep -qiE "$ALLOWED_SECTION_KEYS"; then
        echo "FAIL"; return
      fi
      ;;
  esac
  local window
  window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
  if echo "$window" | grep -qiE "$PROHIBITION_WORDS"; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}

for f in $(find "$ROOT/agents/oracle-backup-recovery-analyst" "$ROOT/skills/rman" "$ROOT/queries/rman" "$ROOT/parsers/rman" -type f -not -path '*__pycache__*' 2>/dev/null); do
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    result=$(check_match "$f" "$lineno")
    if [ "$result" != "PASS" ]; then
      echo "[FAIL] $f:$lineno contiene un wrapper de ejecución arbitraria de RMAN sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -nE "$PATTERN" "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún wrapper de ejecución arbitraria de RMAN en todo el dominio (sin contar declaraciones explícitas de prohibición)"

# --- Fixtures controladas (# 11, # 12, # 21 del prompt) ----------------------------------------
# Demuestran, contra los 3 nombres peligrosos, que el mismo texto se clasifica según su sección
# YAML envolvente: allowed_tools -> FAIL siempre; forbidden_capabilities -> PASS siempre.
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

cat > "$TMPD/negative.yaml" <<'EOF'
id: fixture-negative
allowed_tools:
  - execute_rman(command)
  - run_rman(command)
  - rman_shell(command)
EOF
neg_fail=0
for pair in "3:execute_rman" "4:run_rman" "5:rman_shell"; do
  ln="${pair%%:*}"; name="${pair##*:}"
  result=$(check_match "$TMPD/negative.yaml" "$ln")
  if [ "$result" = "FAIL" ]; then
    echo "[PASS] fixture negativa: allowed_tools + ${name}(command) -> FAIL (correcto)"
  else
    echo "[FAIL] fixture negativa: allowed_tools + ${name}(command) debió fallar y no falló"
    neg_fail=1
  fi
done
[ "$neg_fail" -ne 0 ] && FAIL=1

cat > "$TMPD/positive.yaml" <<'EOF'
id: fixture-positive
forbidden_capabilities:
  - execute_rman(command)
  - run_rman(command)
  - rman_shell(command)
EOF
pos_fail=0
for pair in "3:execute_rman" "4:run_rman" "5:rman_shell"; do
  ln="${pair%%:*}"; name="${pair##*:}"
  result=$(check_match "$TMPD/positive.yaml" "$ln")
  if [ "$result" = "PASS" ]; then
    echo "[PASS] fixture positiva: forbidden_capabilities + ${name}(command) -> PASS (correcto)"
  else
    echo "[FAIL] fixture positiva: forbidden_capabilities + ${name}(command) debió pasar y falló"
    pos_fail=1
  fi
done
[ "$pos_fail" -ne 0 ] && FAIL=1

# UTF-8 robustness (# 13 del prompt) — lenguaje de prohibición con tilde debe reconocerse sin
# depender de un wildcard sobre bytes multibyte.
cat > "$TMPD/utf8.md" <<'EOF'
línea 1
línea 2
línea 3
No existe execute_rman(command) — ningún wrapper de ejecución arbitraria.
EOF
utf8_result=$(check_match "$TMPD/utf8.md" 4)
if [ "$utf8_result" = "PASS" ]; then
  echo "[PASS] UTF-8: 'ningún' (con tilde) reconocido como lenguaje de prohibición sin wildcard multibyte"
else
  echo "[FAIL] UTF-8: 'ningún' (con tilde) no reconocido como lenguaje de prohibición"
  FAIL=1
fi

exit $FAIL
