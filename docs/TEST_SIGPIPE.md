# CHG-ESTACK-TEST-SIGPIPE-001 — Tests sin tuberías hacia `grep -q` (SIGPIPE bajo `pipefail`)

**Tipo:** `/change documentation|compatibility` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/test-sigpipe` (desde `change/cdb-temp-usage`, `d565237`, PR #24)
**Estado:** aprobado (§11), integrado a `main` vía PR #25 (merge `00000b4`; integrada antes de terminar la CI de la PR, cubierta por la CI de `main` en verde en los tres sistemas). Release `0.22.0`, tag `v0.22.0-observed-context` (se crea sobre el merge de la rama del changelog).

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. Sólo cambian tests.

## 1. DETECT GAP

La PR #24 falló en macOS (CI) en `test_query_variant_resolver_no_match_returns_unsupported`, con `line 17: echo: write error: Broken pipe`.
- **Causa:** los tests usan `set -uo pipefail`, y `echo "$salida" | grep -q X` falla si `grep -q` encuentra la coincidencia y sale antes de que `echo` termine de escribir: `echo` recibe SIGPIPE y la tubería completa reporta fallo.
- **Frecuencia:** es una carrera; no se reprodujo localmente en 200 intentos, y apareció 1 vez en ~100 jobs de CI. Al re-ejecutar el job, pasó.
- **Alcance:** el patrón estaba en ~400 lugares de la suite.

## 2. CHANGE REQUEST — alcance

| Transformación | Casos | Por qué es equivalente |
|---|---|---|
| `echo "$v" \| grep -q… ARGS` → `grep -q… ARGS <<<"$v"` | 339 reemplazos en 251 archivos | El here-string agrega el mismo salto de línea final; sin tubería no hay SIGPIPE. Además `echo` ya no puede interpretar un valor que empiece con `-n`/`-e` |
| `PRODUCTOR \| grep -q… ARGS` → `PRODUCTOR \| grep -c… ARGS >/dev/null` | 57 reemplazos en 50 archivos | `grep -c` lee toda la entrada (no cierra la tubería antes) y sale con 0 si hubo coincidencias y 1 si no, igual que `-q`. No toca `a \|\| grep -q …` (no es tubería) |
| `tests/test_no_pipe_into_early_exit_grep.sh` (nuevo) | — | Falla si un test vuelve a canalizar hacia `grep -q`/`grep -m` |

La transformación se aplicó con un script que respeta comillas, paréntesis y continuaciones de línea (`\`). Termina el comando de `grep` en `&&`, `||`, `;`, `|`, `)` o `then`. El script **no** queda en el repositorio: el guard es lo que se mantiene.

## 3. GAP ANALYSIS

- Sólo importa cuando la tubería decide una condición (`if`, `&&`, `||`), porque los tests usan `pipefail` sin `-e`. Aun así se transformaron todas, por uniformidad y para que el guard sea simple.
- `grep -oE`, `-c`, `-E` sin `-q` leen toda la entrada y no causan el problema: no se tocan.
- **Hallazgo aparte:** `test_unified_audit_detection.sh:9` encadena `grep -q … | grep …` (el primero no imprime nada), pero la línea termina en `|| true` y la comprobación real está en la siguiente. Es código muerto inofensivo; no se toca.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Código del e-stack (gateway, lab, queries, skills) | Ninguno |
| Tests | 296 archivos reescritos; +1 guard |
| CI | Elimina una fuente de fallos aleatorios en cualquier PR |

## 5. TEST

- Sintaxis (`bash -n`) de los 296 archivos: correcta.
- **Equivalencia:** comparando línea por línea contra la corrida base (misma base de código), las **4943** líneas `[PASS]/[FAIL]/[SKIP]` son idénticas, normalizando rutas y temporales.
- Mutaciones sobre tests transformados, todas detectadas:
  - un collector con binario no permitido (`test_collectors_are_allowlisted`);
  - un `SELECT *` sobre `unified_audit_trail`, el caso con continuación de línea (`test_audit_query_budget`);
  - la query ASM que vuelve a `V$ASM_DISKGROUP`;
  - la matriz de capacidades con multitenant 10g soportado (un caso de `grep -c`);
  - la reintroducción del patrón (guard).
- Un primer intento del script puso el here-string **después** de una `\` de continuación. Se detectó en la revisión del diff, se revirtió y se corrigió antes de validar.

## 6. SECURITY VALIDATION

Sin cambios fuera de `tests/`. Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): 968/968 antes y **969/969** después. CI en los tres sistemas: pendiente (PR).

## 8. Validación en el lab

No aplica: no cambia nada que corra contra Oracle.

## 9–10. Registros relacionados

- Nace del fallo de la PR #24 (`CHG-ESTACK-CDB-TEMP-USAGE-001`), que al re-ejecutarse pasó.
- Pendiente menor: limpiar el código muerto de `test_unified_audit_detection.sh`.

## 11. HUMAN REVIEW — aprobado

`AUTH-TEST-SIGPIPE-001`, revisor `REV-DBAMANAGER` (distinto del proponente `REV-CLAUDEAGENT`), `2026-09-29T19:54:04Z`, contra el digest `a5306538…cc7124`. El motor informa `review_status: APPROVED_BY_HUMAN` con verificación `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`: comprueba la estructura y el digest, no la identidad del firmante. `PROMOTE` (merge, tag) sigue siendo acción humana.

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-29T17:56:38Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: a5306538c9e1c7519f26cb27e64fcdb4c2134e9a452bcc42b29de44b09cc7124`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-TEST-SIGPIPE-001/`.
