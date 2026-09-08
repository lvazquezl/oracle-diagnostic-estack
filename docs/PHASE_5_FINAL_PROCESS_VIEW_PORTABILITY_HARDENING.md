# Phase 5 — Data Guard Final Process-View & Portability Hardening

Cierra los últimos defectos detectados sobre `phase/5-dataguard` antes de aprobar `v0.5.0-dataguard`, sobre el estado ya corregido por PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING (`docs/PHASE_5_COMPATIBILITY_HARDENING.md`). No reconstruye Phase 5 — sólo corrige.

## V$DATAGUARD_PROCESS correction

El hardening anterior registró `V$DATAGUARD_PROCESS` con `min_version: "11.2"` y columnas `pid`/`name`/`status`/`client_process` — ninguno de esos dos datos es correcto. Verificado contra la documentación oficial de Oracle (Oracle Database 12c Release 2 Database Reference, `V-DATAGUARD_PROCESS.html`):

- **Versión real de introducción: 12.2.0.1** (Oracle Database 12c Release 2), no 11.2.
- **`STATUS` y `CLIENT_PROCESS` no son columnas de esta vista** — pertenecen a `V$MANAGED_STANDBY`. La confusión entre ambas vistas fue el defecto real.
- Columnas reales documentadas: `NAME`, `PID`, `TYPE`, `ROLE`, `PROC_TIME`, `TASK_TIME`, `TASK_DONE`, `ACTION`, `CLIENT_PID`, `CLIENT_ROLE`, `GROUP#`, `RESETLOG_ID`, `THREAD#`, `SEQUENCE#`, `BLOCK#`, `BLOCK_COUNT`, `DELAY_MINS`, `DEST_ID`, `DEST_MASK`, `DBID`, `DGID`, `INSTANCE`, `STOP_STATE`, `CON_ID`.
- Oracle recomienda explícitamente `V$DATAGUARD_PROCESS` en lugar de la deprecada `V$MANAGED_STANDBY`.

`compatibility/oracle-dictionary/views.yaml` corregido: `min_version: "12.2"`, columnas reales registradas (subconjunto usado por la query: `name`, `pid`, `type`, `role`, `action`, `client_pid`, `client_role`, `thread#`, `sequence#`, `block#`, `block_count`), con un bloque `validation:` (`source_type: ORACLE_DOCUMENTATION`, `status: DOCUMENTATION_VALIDATED`) trazando la verificación documental independiente (no circular — ver "No auto-validation circular" abajo).

También se corrigió `V$MANAGED_STANDBY` en el mismo esfuerzo: verificado contra Oracle Database Reference, sus columnas reales incluyen `THREAD#` y `CLIENT_PID` (ausentes en el registro anterior), y está **oficialmente deprecada desde 12.2.0.1** — el registro ahora lo documenta explícitamente.

## Legacy/modern boundary

El hardening anterior trataba la variante legacy como *default* en todo el rango 10.2–23.0, con la variante moderna como *on-demand* opcional desde 11.2. Corregido a una partición real, sin solapamiento, alineada con el ciclo de vida real de ambas vistas:

- **Legacy (`V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY`), 10.2–12.1** — única variante certificada en ese rango (`V$DATAGUARD_PROCESS` todavía no existe).
- **Modern (`V$DATAGUARD_PROCESS`/`GV$DATAGUARD_PROCESS`), 12.2–23.0** — única variante certificada en ese rango (`V$MANAGED_STANDBY` ya está deprecada).

El resolver nunca elige entre dos candidatas para la misma versión — resuelve la única aplicable. Verificado explícitamente en los límites exactos (12.1 → legacy, 12.2 → modern) y en 11g/19c/23ai.

## Semantic normalization

Modelo lógico corregido (antes: `process_type`/`status`/`client_process`/`thread`/`sequence`/`source_view`; ahora: `process_name`/`process_role`/`process_action`/`client_pid`/`thread`/`sequence`/`source_view`/`source_variant`):

```yaml
dataguard_process:
  process_name: string          # PROCESS (legacy) | NAME (modern)
  process_role: string|NOT_AVAILABLE   # NOT_AVAILABLE en legacy — V$MANAGED_STANDBY no tiene columna ROLE
  process_action: string        # STATUS (legacy) | ACTION (modern) — vocabulario de estado solapado
  client_pid: string|null
  thread: int|null              # soportado en AMBAS variantes (corrección: V$DATAGUARD_PROCESS sí lo expone)
  sequence: int|null            # soportado en ambas variantes
  source_view: string
  source_variant: legacy|modern
```

Único campo sin equivalente real: `process_role` en la variante legacy (`V$MANAGED_STANDBY` no tiene columna `ROLE`). El hardening anterior marcaba `thread`/`sequence` como `PARTIALLY_SUPPORTED` en la variante moderna por una suposición incorrecta sobre las columnas de `V$DATAGUARD_PROCESS` — corregido: ambas están totalmente soportadas ahí.

## Future-version policy correction

`config/capability-matrix.yaml` (fila `dataguard`) tenía `latest: SUPPORTED` con una nota aclaratoria — el hardening anterior lo *reinterpretó por comentario* en vez de corregirlo estructuralmente. Corregido: la clave `latest:` fue **eliminada** de `versions: {...}`, reemplazada por un campo explícito `future_status: COMPATIBILITY_VALIDATION_REQUIRED`, sibling de `versions`/`notes`. `docs/CAPABILITY_MATRIX.md` refleja el mismo cambio (columna "latest" de la fila Data Guard pasa de `SUPPORTED` a `COMPATIBILITY_VALIDATION_REQUIRED`). Una única interpretación ahora atraviesa Agent Contract (`UNKNOWN_FUTURE`), Query Compatibility Matrix (`max` explícito, nunca `latest`), Capability Matrix (`future_status`) y documentación — verificado por `test_dataguard_capability_matrix_matches_agent_future_policy.sh`.

## Capability Matrix correction

Ver arriba — cambio estructural, no cosmético. `test_capability_matrix_schema.sh` (genérico, Foundation) sigue pasando porque su chequeo de presencia de la columna `latest` es a nivel de archivo completo, no por dominio — otros dominios conservan `latest: SUPPORTED` intencionalmente (fuera de alcance de este hardening).

## CRLF regression

`compatibility/oracle-dictionary/views.yaml` tenía terminadores de línea CRLF en todo el archivo (confirmado con `file`: "with CRLF line terminators") pese a que `.gitattributes` ya declara `*.yaml text eol=lf` — la normalización de Git sólo se aplica en operaciones de checkout/add, no retroactivamente sobre contenido de working tree ya escrito. Normalizado a LF (466 secuencias `\r\n` → `\n`, contenido sin cambios semánticos, verificado byte a byte). Barrido completo del repositorio (`os.walk` sobre `*.sh`/`*.bash`/`*.py`/`*.yaml`/`*.yml`/`*.json`/`*.md`, 911 archivos) confirmó que este era el único archivo afectado.

## EOL test

`tests/test_repository_text_files_are_lf.sh` (nuevo) — escanea el repositorio completo (no sólo `git ls-files`, para cubrir también contenido de Fase 5 aún no comiteado) en busca de CRLF en las 7 extensiones críticas, implementado en Python stdlib (más portable que depender de comportamiento de shell/grep entre Windows Git Bash/WSL/Linux CI). `tests/test_gitattributes_lf_policy.sh` (nuevo) confirma que `.gitattributes` declara `eol=lf` para las 7 extensiones — ya las declaraba correctamente antes de este hardening, sin cambios necesarios ahí.

## No auto-validation circular

El defecto de `V$DATAGUARD_PROCESS` en el hardening anterior es un ejemplo real de "wrong SQL + wrong compatibility metadata = PASS": la metadata del dictionary y la SQL de la query se escribieron a la vez, sin una fuente de validación documental independiente — ambas estaban mal de forma consistente entre sí, así que ningún test las contradecía. Para este hardening se usó una fuente externa genuina (Oracle Database Reference, vía WebFetch/WebSearch) antes de escribir cualquier metadata o SQL — no se copió el ejemplo conceptual del prompt sin verificar. El bloque `validation:` en `views.yaml` deja trazabilidad explícita de esa fuente (`source_type: ORACLE_DOCUMENTATION`) para futuras revisiones.

## Tests

10 tests nuevos: `test_dataguard_process_modern_does_not_use_legacy_default.sh`,
`test_v_dataguard_process_columns_match_dictionary_model.sh` (delega en
`test_dataguard_process_modern_uses_supported_columns.sh`),
`test_dataguard_process_variant_resolution_121.sh`,
`test_dataguard_process_variant_resolution_122.sh`,
`test_capability_matrix_has_no_latest_supported.sh`,
`test_query_resolver_rejects_unknown_future.sh` (delega en
`test_dataguard_24_or_future_not_auto_supported.sh`),
`test_dataguard_capability_matrix_matches_agent_future_policy.sh`,
`test_repository_text_files_are_lf.sh`, `test_gitattributes_lf_policy.sh`.

6 tests corregidos (metadata/rango real, no sólo cosmético):
`test_dataguard_process_legacy_variant.sh`, `test_dataguard_process_modern_variant.sh`,
`test_dataguard_process_modern_uses_supported_columns.sh` (ya no prohíbe thread#/sequence#/block#
— corrección respecto al hardening anterior),
`test_dataguard_process_variant_resolution_{11g,19c,23ai}.sh` (partición estricta, ya no
"ambas variantes resuelven"), `test_dataguard_latest_not_automatically_supported.sh`.

## Known limitations

- `GV$DATAGUARD_PROCESS` se registra con base en la regla arquitectónica general y documentada de Oracle para vistas GV$ (toda vista fija V$ tiene una contraparte GV$ con `INST_ID` — Oracle Database Reference, "GV$ Views") — no se encontró una página de referencia dedicada específicamente a `GV$DATAGUARD_PROCESS` durante la verificación. Documentado explícitamente en `views.yaml` como tal, no presentado como una página confirmada.
- `V$DATAGUARD_PROCESS` tiene más columnas documentadas (`PROC_TIME`, `TASK_TIME`, `TASK_DONE`, `GROUP#`, `RESETLOG_ID`, `DELAY_MINS`, `DEST_ID`, `DEST_MASK`, `DBID`, `DGID`, `INSTANCE`, `STOP_STATE`, `CON_ID`) que no se registraron en el dictionary por no ser usadas por la query actual — ampliar sólo vía `/change query` cuando exista una necesidad diagnóstica real, nunca "por si acaso".
- El chequeo de existencia de columna del SQL Static Validator (Fase 5 Compatibility Hardening) sigue limitado a las vistas marcadas `columns_exhaustive: true` — sin cambios en su alcance en este hardening.
