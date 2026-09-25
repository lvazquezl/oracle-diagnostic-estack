# CHG-ESTACK-PORTABILITY-001 — Portabilidad Windows/macOS/Linux de la suite y del lanzador lab

**Tipo:** `/change compatibility|documentation` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/portability-001` (desde `main` `a00ea2c`, `v0.17.0-oracle19c-lab-rman`)
**Estado:** aprobado por revisión humana (§11), validado en Windows (§8) e integrado a `main` vía PR #10 (merge `20c817a`). Release `0.18.0`, tag `v0.18.0-portability` (se crea sobre el merge de la rama del changelog). `PROMOTE`, commit, merge, tag y push son acciones humanas.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. Ninguna política cambia y no se agregan queries, collectors ni herramientas.

## 1. DETECT GAP

El e-stack se desarrolló en Windows (Git Bash). El trabajo lab (v0.15.0–v0.17.0) se validó sólo en macOS. Al correr `tests/run-all.sh` en Windows sobre `v0.17.0` se obtuvo **955/962**:

| Fallo en Windows | Causa |
|---|---|
| `test_sql_static_validator` + 3 dependientes | Falsos positivos `SYSDATE`, `KEEP`, `DENSE_RANK`, `LAST` en las queries de LAB-004: el validador los tomaba por columnas |
| `test_p15_oracle_lab_adapter` / `_security` | `os.getuid` no existe en Windows: traceback en `mcp_gateway_lab/profile.py` |
| `test_p14_mutation_controls` | Interrupción (exit 130); aislado pasa 18/18 |

A su vez, los "13 fallos preexistentes" que declaraban los registros de LAB-002…005 **eran exclusivos de macOS**, no preexistentes en el stack:

| Fallo en macOS | Causa |
|---|---|
| `*_no_delegation_loop` ×5, `test_pdb_{resource_usage,saved_state}_columns_valid` | `\s` en `sed -E`/`grep -E`: en BSD es una `s` literal |
| `test_rman_*_variant_*` ×5 | `grep '…$\|…'` (BRE con alternancia GNU): en BSD el `$` queda literal |
| `test_collectors_are_allowlisted` | `` \` `` en el patrón. En GNU grep es el ancla de inicio de buffer, así que el test **no revisaba ninguna fila** en Windows/Linux (**confirmado** en Windows, §8). En BSD sí revisaba y fallaba por `lectura de /etc/hostname` y `` `ss` `` |

Además, un defecto silencioso: `/bin/bash` 3.2 de macOS no tiene `declare -A`. `test_sql_static_validator` y `test_fixture_query_variant_resolution` **pasaban sin validar nada**. Por eso los PASS del validador en macOS que citan los registros de LAB-002…005 no tienen valor probatorio. Los falsos positivos de LAB-004 sólo se vieron en Windows por esa razón.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `tests/test_sql_static_validator.sh` | Guard bash ≥ 4 (FAIL explícito); `sysdate\|systimestamp\|keep\|dense_rank\|first\|last` como palabras reservadas |
| `tests/test_fixture_query_variant_resolution.sh` | Guard bash ≥ 4 |
| 7 tests (`*_no_delegation_loop` ×5, `test_pdb_*_columns_valid` ×2) | `\s` → `[[:space:]]` |
| `tests/test_rman_*_variant_*` ×5 | `grep -qi '…\|…'` → `grep -qiE '…|…'` |
| `tests/test_hugepages_calculation.sh` | `\s` → `[[:space:]]` |
| `tests/test_collectors_are_allowlisted.sh` | Patrón portable `` [`] ``; allowlist ampliada a `` `ss` `` y `` lectura de `/etc/hostname` `` (ya documentados en `docs/GI_READONLY_COLLECTORS.md`) |
| `mcp_gateway_lab/profile.py` | Fuera de POSIX: `ProfileError` con texto fijo, en vez de traceback |
| `mcp_gateway_lab/cli.py` | `macos_keychain` fuera de darwin: `ProfileError` con texto fijo al arrancar |
| `tests/p15/harness.py` y `check_lab_{adapter,security}.py` | `posix_test`: los casos que construyen el gateway lab o dependen de permisos POSIX salen como `[SKIP]` explícito fuera de POSIX. 4 casos independientes de plataforma siguen corriendo siempre. 2 casos nuevos |

## 3. GAP ANALYSIS

1. **No hay IDs nuevos** de query, skill, agente ni collector. `mcp_gateway_lab` no cambia de versión funcional: sólo rechaza antes y con texto fijo lo que antes ya fallaba con traceback.
2. **Lab en Windows:** sigue sin soporte, y ahora lo dice explícitamente. Un proveedor de credenciales para Windows/Linux (DPAPI, libsecret) queda en `CHG-REQ-LAB-CRED-PROVIDERS`. No se implementa aquí.
3. **Bash en macOS:** no se reescribe el validador para bash 3.2. Se exige bash ≥ 4 (`brew install bash`), con un FAIL visible en lugar de un PASS vacío.
4. **Allowlist de collectors:** la fila `get_host_identity` de `docs/GI_READONLY_COLLECTORS.md` dice "o equivalente". Esa redacción abierta queda para HUMAN REVIEW (`CHG-REQ-DOC-GI-HOSTNAME`). El test sólo acepta lo que la fila nombra.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries / diccionario / capability matrix | Ninguno |
| Gateway por defecto (fixture) | Ninguno |
| Gateway lab | Sólo el rechazo temprano fuera de POSIX/macOS; en macOS, comportamiento idéntico (P15 en verde) |
| Suite | Portable a GNU y BSD; en macOS con bash 3.2 hay 5 FAIL explícitos (validador y dependientes) donde antes había PASS vacíos |
| Seguridad | Ninguna superficie nueva (§6) |

## 5. TEST

- Mutaciones sobre los guards del lanzador: quitar el guard POSIX → FAIL `non_posix_hosts_are_refused_with_fixed_text_instead_of_a_traceback`; quitar el guard del Keychain → FAIL `the_keychain_provider_is_refused_at_startup_off_macos_when_no_test_runner_is_injected`.
- Simulación no POSIX de P15 security (`POSIX_HOST=False`): 34/34 con `[SKIP]` explícitos en los casos POSIX y en verde los 4 independientes más los 2 nuevos.
- Control negativo del allowlist: una fila con `curl` → FAIL.
- Windows (§8): palabras reservadas del validador en verde con bash 5.3; P15 con `[SKIP]` reales.

## 6. SECURITY VALIDATION

- No se relaja ningún control: los checks de dueño/permisos del perfil siguen iguales en POSIX. Fuera de POSIX **se rechaza**, no se omite.
- El allowlist de collectors se hace **más estricto** en la práctica, porque en GNU grep antes no revisaba ninguna fila.
- Las palabras reservadas del validador son funciones y palabras clave de Oracle, no columnas. No abren acceso a vistas nuevas.
- Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

| Plataforma | Antes (`v0.17.0`) | Después |
|---|---|---|
| macOS (bash 3.2, BSD) | 949/962 (13 exclusivos de macOS; validador vacío) | **957/962**: 5 FAIL explícitos del guard bash ≥ 4 (`test_sql_static_validator`, `test_fixture_query_variant_resolution`, `test_no_variant_references_unknown_column`, `test_static_validator_checks_aliased_columns`, `test_static_validator_validates_non_v_dollar_dictionary_objects`) |
| Windows (Git Bash 5.3, GNU) | 955/962 | **961/962**: el único FAIL es `test_p14_mutation_controls` dentro de `run-all.sh`, que aislado pasa 18/18 (igual que en la línea base; fuera de alcance, `CHG-REQ-TEST-P14-WINDOWS-SUITE`) |
| Linux | sin medición | sin medición: propuesta `CHG-REQ-CI-MATRIX` |

## 8. Validación en Windows (ejecutada por el usuario, 2026-09-24, commit `476fe03`)

| Comprobación | Resultado |
|---|---|
| `bash --version` | GNU bash 5.3.15 (cygwin) |
| Patrón viejo `` ^\| \`get_ `` vs. nuevo `` ^\| [`]get_ `` sobre `docs/GI_READONLY_COLLECTORS.md` | **0** vs. **16** filas: en GNU grep el test de collectors no revisaba nada |
| `test_sql_static_validator` | PASS (los falsos positivos `SYSDATE`/`KEEP`/`DENSE_RANK`/`LAST` desaparecen) |
| `test_p15_oracle_lab_security` | 28 `[SKIP]` explícitos (los 28 casos POSIX-only); los 4 independientes y los 2 nuevos corren y pasan |
| `test_p15_oracle_lab_adapter` | "23/23 checks OK": los 23 casos son POSIX-only y salen `[SKIP]`; el harness P13 cuenta SKIP como OK en ese resumen |
| `test_collectors_are_allowlisted` | PASS (ahora revisando las 16 filas) |
| `tests/run-all.sh` | 961/962; `test_p14_mutation_controls` aislado 18/18 |

## 9–10. Registros relacionados

- Cierra `CHG-REQ-TEST-BSD-GREP`.
- Corrige lo que declaraban los registros de LAB-002…005 sobre los "13 fallos preexistentes" y los PASS del validador en macOS. Los CHANGELOG ya publicados no se reescriben; esta entrada es la fe de erratas.
- Propuestas nuevas:
  - `CHG-REQ-TEST-P14-WINDOWS-SUITE`: `test_p14_mutation_controls` falla dentro de `run-all.sh` en Windows (en la línea base, exit 130) y pasa aislado; posible límite de tiempo (`timeout_seconds=120` en `tests/p14/check_mutation.py`) bajo carga.
  - `CHG-REQ-P13-SKIP-SUMMARY`: el resumen "N/M checks OK" del harness P13 debería contar los SKIP aparte.
  - `CHG-REQ-CI-MATRIX`: GitHub Actions con `windows-latest`, `ubuntu-latest` y `macos-latest`, con bash ≥ 4.
  - `CHG-REQ-DOC-GI-HOSTNAME`.
- `CHG-ESTACK-ORA19C-LAB-005` (en pausa) se rebasa sobre esta rama cuando se integre, y su guard nuevo también se valida en Windows.

## 11. HUMAN REVIEW — aprobado

`AUTH-PORTABILITY-001`, revisor `REV-DBAMANAGER` (distinto del proponente `REV-CLAUDEAGENT`), `2026-09-24T22:13:34Z`, contra el digest `435b2511…71b691`. El motor informa `review_status: APPROVED_BY_HUMAN` con verificación `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`: comprueba la estructura y el digest, no la identidad del firmante. `PROMOTE` (merge, tag) sigue siendo acción humana.

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-24T22:07:58Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 435b25115ffe63de988af91914bd9537a666b11385f7622549ba5e86b471b691`. El motor sólo admite `PASS|FAIL|UNKNOWN` en compatibilidad; `version_coverage`, `query_contract`, `dictionary_columns` y `cost_and_license` se declaran `PASS` por no cambiar (no se tocan queries, diccionario ni costo). La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-PORTABILITY-001/`.
