#!/usr/bin/env bash
# PHASE 12 — CHANGE ADVISORY, DOCUMENTATION & KNOWLEDGE LIFECYCLE: consistencia declarativa de los 3 agentes
# especializados (estructura Phase 11), los 18 skills nuevos, los registros, el workflow/comando /knowledge
# y la ausencia de agentes duplicados o ciclos de delegación. Complementa (no sustituye) los tests
# funcionales tests/test_p12_*.sh, que ejecutan el motor real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ok()   { echo "[PASS] $1"; }
bad()  { echo "[FAIL] $1"; FAIL=1; }

AGENTS="change-advisor technical-documentation-manager knowledge-curator"
FILES="AGENT.md manifest.yaml routing.yaml context-policy.yaml collaboration.yaml output-schema.yaml CHANGELOG.md tests/README.md"

# 1) estructura completa y planos eliminados
for a in $AGENTS; do
  for f in $FILES; do
    [ -f "$ROOT/agents/$a/$f" ] && ok "agents/$a/$f existe" || bad "falta agents/$a/$f"
  done
  [ ! -f "$ROOT/agents/$a.md" ] && ok "el manifest plano agents/$a.md fue reemplazado" || bad "agents/$a.md plano coexiste con la carpeta"
  grep -q "^id: $a\$" "$ROOT/agents/$a/manifest.yaml" && ok "manifest.yaml de $a declara su id" || bad "manifest.yaml de $a sin id correcto"
  grep -q '^version: 2.0.0' "$ROOT/agents/$a/manifest.yaml" && ok "$a en v2.0.0" || bad "$a no está en v2.0.0"
  grep -q "agents/$a/AGENT.md" "$ROOT/agents/REGISTRY.md" && ok "REGISTRY apunta a agents/$a/AGENT.md" || bad "REGISTRY no apunta a agents/$a/AGENT.md"
  grep -q 'READ_ONLY_ALWAYS' "$ROOT/agents/$a/manifest.yaml" && ok "$a declara security_mode READ_ONLY_ALWAYS" || bad "$a sin security_mode READ_ONLY_ALWAYS"
  grep -qi 'sudo/root' "$ROOT/agents/$a/manifest.yaml" && ok "$a prohíbe explícitamente sudo/root" || bad "$a no prohíbe sudo/root"
  grep -qi 'simular identidad' "$ROOT/agents/$a/manifest.yaml" && ok "$a prohíbe simular identidad/aprobación" || bad "$a no prohíbe simular aprobación"
  # tabs no válidos en YAML
  if grep -nP '\t' "$ROOT/agents/$a"/*.yaml >/dev/null 2>&1; then bad "$a contiene tabuladores en YAML"; else ok "$a: YAML sin tabuladores"; fi
done

# 2) 18 agentes canónicos, sin duplicados
COUNT=$(grep -cE '^\| `[a-z-]+` \|' "$ROOT/agents/REGISTRY.md")
[ "$COUNT" -eq 18 ] && ok "agents/REGISTRY.md lista exactamente 18 agentes" || bad "agents/REGISTRY.md lista $COUNT agentes (esperado 18)"
DUP=$(grep -oE '^\| `[a-z-]+` \|' "$ROOT/agents/REGISTRY.md" | sort | uniq -d | wc -l)
[ "$DUP" -eq 0 ] && ok "sin agentes duplicados en el registro" || bad "agentes duplicados en el registro"
for extra in change-advisory-analyst knowledge-manager documentation-analyst change-manager; do
  [ ! -e "$ROOT/agents/$extra" ] && [ ! -e "$ROOT/agents/$extra.md" ] || bad "agente duplicado/no canónico agents/$extra"
done
ok "sin agentes duplicados fuera del registro"

# 3) allowed_skills existen en el registro de skills
for a in $AGENTS; do
  while IFS= read -r sid; do
    [ -z "$sid" ] && continue
    if grep -q "\`$sid\`" "$ROOT/skills/REGISTRY.md"; then ok "$a: skill $sid está en skills/REGISTRY.md"; else bad "$a: skill $sid no está en skills/REGISTRY.md"; fi
  done < <(awk '/^allowed_skills:/{f=1;next} /^[a-z_]+:/{f=0} f && /^  - /{sub(/^  - /,""); print}' "$ROOT/agents/$a/manifest.yaml")
done

# 4) los 18 skills nuevos
SKILLS="change/operational-advisory change/impact-and-risk change/compatibility-and-license-gates change/manual-execution-plan change/rollback-and-validation change/stack-evolution-handoff documentation/incident-rca-report documentation/assessment-report documentation/change-advisory-report documentation/executive-summary documentation/evidence-traceability knowledge/candidate-extraction knowledge/quality-gate knowledge/duplicate-and-conflict-review knowledge/version-and-provenance knowledge/review-and-approval knowledge/deprecation-and-retirement knowledge/retrieval"
N=0
for s in $SKILLS; do
  N=$((N+1))
  f="$ROOT/skills/$s/SKILL.md"; m="$ROOT/skills/$s/manifest.yaml"
  [ -f "$f" ] && [ -f "$m" ] && ok "skill $s materializado (SKILL.md + manifest.yaml)" || { bad "skill $s no materializado"; continue; }
  grep -q "^id: $s\$" "$f" && grep -q '^status: active' "$f" && ok "skill $s: id y status active" || bad "skill $s: id/status incorrectos"
  grep -q "^id: $s\$" "$m" && ok "skill $s: manifest.yaml con id" || bad "skill $s: manifest.yaml sin id"
  for sec in '# Inputs' '# Outputs' '# Gates' '# Decision logic' '# Forbidden operations' '# Tests' '# Deactivation' '# Implementation'; do
    grep -q "^$sec" "$f" || bad "skill $s sin sección '$sec'"
  done
  # los tests referenciados existen
  while IFS= read -r t; do
    [ -f "$ROOT/$t" ] || bad "skill $s referencia un test inexistente: $t"
  done < <(sed -n '/^# Tests/,/^# Documentation/p' "$f" | grep -oE 'tests/test_[a-z0-9_]+\.sh')
  grep -q "skills/$s/SKILL.md" "$ROOT/skills/REGISTRY.md" || grep -q "$s/SKILL.md" "$ROOT/skills/REGISTRY.md" && ok "skill $s en REGISTRY.md como active" || bad "skill $s no figura como active en REGISTRY.md"
done
[ "$N" -eq 18 ] && ok "18 skills de Fase 12 verificados" || bad "conteo de skills $N != 18"

# 5) workflow y comando /knowledge (sólo si no existían) y contrato de workflow
[ -f "$ROOT/workflows/knowledge.md" ] && grep -q '^# Gates' "$ROOT/workflows/knowledge.md" && grep -A10 '^# Gates' "$ROOT/workflows/knowledge.md" | grep -q 'gates:' && ok "workflows/knowledge.md con bloque # Gates" || bad "workflows/knowledge.md sin contrato de gates"
[ -f "$ROOT/.claude/commands/knowledge.md" ] && ok ".claude/commands/knowledge.md existe" || bad "falta .claude/commands/knowledge.md"
for c in change document incident rca recommend; do [ -f "$ROOT/.claude/commands/$c.md" ] && ok "comando /$c conservado" || bad "comando /$c eliminado"; done
grep -qi 'PROMOTE' "$ROOT/workflows/change.md" && grep -q 'PENDING_HUMAN_REVIEW' "$ROOT/workflows/change.md" && ok "workflows/change.md documenta los dos planos y PENDING_HUMAN_REVIEW" || bad "workflows/change.md sin sección de Fase 12"

# 6) sin ciclos de delegación (grafo acíclico)
d() { awk '/^delegates_to:/{f=1;next} /^[a-z_]+:/{f=0} f && /agent:/{sub(/.*agent: */,""); print}' "$ROOT/agents/$1/routing.yaml" | tr -d '"'; }
d change-advisor | grep -qx 'incident-root-cause-analyst' && bad "change-advisor delega de vuelta a incident-root-cause-analyst (ciclo)" || ok "change-advisor no delega hacia atrás"
d technical-documentation-manager | grep -qE 'change-advisor|incident-root-cause-analyst' && bad "technical-documentation-manager delega hacia atrás" || ok "technical-documentation-manager no delega hacia atrás"
d knowledge-curator | grep -qE 'change-advisor|technical-documentation-manager|incident-root-cause-analyst' && bad "knowledge-curator delega hacia atrás" || ok "knowledge-curator no delega hacia atrás"

# 7) documentación, CLI y contratos
[ -f "$ROOT/docs/PHASE_12_CHANGE_ADVISORY_DOCUMENTATION_KNOWLEDGE_LIFECYCLE.md" ] && ok "documento de fase presente" || bad "falta docs/PHASE_12_*.md"
grep -q 'NOT_EXECUTED_BY_ESTACK' "$ROOT/agents/change-advisor/AGENT.md" && ok "change-advisor declara NOT_EXECUTED_BY_ESTACK" || bad "change-advisor sin NOT_EXECUTED_BY_ESTACK"
grep -q 'Un candidato NO es' "$ROOT/agents/knowledge-curator/manifest.yaml" && ok "knowledge-curator: candidato != publicado" || bad "knowledge-curator sin la regla candidato != publicado"
( cd "$ROOT" && PYTHONDONTWRITEBYTECODE=1 python3 -m change_documentation_knowledge.cli --help ) > /dev/null 2>&1 && ok "CLI --help responde con exit 0" || bad "CLI --help falla"

exit $FAIL
