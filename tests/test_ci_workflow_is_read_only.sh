#!/usr/bin/env bash
# CHG-REQ-CI-MATRIX: the CI workflow must stay read-only and synthetic — no secrets, no write permissions, no lab
# launcher, no privileged triggers, third-party actions pinned to a full commit SHA, and all three OS families.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_DIR="$ROOT/.github/workflows"
FAIL=0
fail() { echo "[FAIL] $1"; FAIL=1; }

[ -d "$WF_DIR" ] || { echo "[FAIL] falta $WF_DIR"; exit 1; }
shopt -s nullglob
files=("$WF_DIR"/*.yml "$WF_DIR"/*.yaml)
[ "${#files[@]}" -gt 0 ] || { echo "[FAIL] no hay workflows en $WF_DIR"; exit 1; }

for f in "${files[@]}"; do
  n="$(basename "$f")"
  body="$(grep -vE '^[[:space:]]*#' "$f")"          # YAML efectivo: los comentarios pueden nombrar lo prohibido
  grep -qE '^permissions:[[:space:]]*$' <<<"$body" && grep -qE '^[[:space:]]+contents:[[:space:]]*read[[:space:]]*$' <<<"$body" \
    || fail "$n: debe declarar permissions: contents: read a nivel de workflow"
  grep -nE '^[[:space:]]+[a-z-]+:[[:space:]]*write' <<<"$body" && fail "$n: declara un permiso de escritura"
  grep -nE 'permissions:[[:space:]]*write-all' <<<"$body" && fail "$n: permissions write-all"
  grep -nE 'secrets\.|GITHUB_TOKEN|github\.token' <<<"$body" && fail "$n: usa secretos o el token"
  grep -nE 'pull_request_target|workflow_run' <<<"$body" && fail "$n: trigger privilegiado"
  grep -nE 'mcp_gateway_lab|lab-profile|targets\.lab|security (find|add)-generic-password|oracledb|sqlplus' <<<"$body" && fail "$n: toca el lab, credenciales u Oracle"
  grep -nE 'git (push|tag|commit)|gh (pr|release)' <<<"$body" && fail "$n: operación de escritura sobre el repositorio"
  while IFS= read -r line; do
    ref="${line#*@}"; ref="${ref%%[[:space:]]*}"
    [[ "$ref" =~ ^[0-9a-f]{40}$ ]] || fail "$n: acción no fijada a un SHA completo: $line"
  done < <(grep -E '^[[:space:]]*-?[[:space:]]*uses:' <<<"$body")
  grep -qE 'persist-credentials:[[:space:]]*false' <<<"$body" || fail "$n: checkout debe usar persist-credentials: false"
done

WF="$WF_DIR/tests.yml"
WFB="$(grep -vE '^[[:space:]]*#' "$WF")"
for os in ubuntu-latest windows-latest macos-latest; do
  grep -qE "os:.*\b$os\b" <<<"$WFB" || fail "tests.yml: la matriz no incluye $os"
done
grep -qE 'fail-fast:[[:space:]]*false' <<<"$WFB" || fail "tests.yml: fail-fast debe ser false (un SO no oculta a otro)"
grep -qE 'bash tests/run-all\.sh' <<<"$WFB" || fail "tests.yml: no corre tests/run-all.sh"
grep -qE 'brew install bash' <<<"$WFB" || fail "tests.yml: macOS necesita bash >= 4"
grep -nE 'brew --prefix\)/bin"?[[:space:]]*>>[[:space:]]*"?\$GITHUB_PATH' <<<"$WFB" \
  && fail "tests.yml: anteponer todo el bin de Homebrew al PATH tapa el python3 de setup-python"
grep -qE "sys\.version_info\[:2\] == \(3, 13\)" <<<"$WFB" || fail "tests.yml: debe verificar que python3 es el de setup-python (3.13)"

[ "$FAIL" -eq 0 ] && echo "[PASS] los workflows de CI son de solo lectura, sintéticos y fijados por SHA en ubuntu/windows/macos"
exit "$FAIL"
