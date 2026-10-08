# PHASE 13 — MCP Diagnostic Gateway & Local Integration

Baseline: `v0.12.0-change-documentation-knowledge` (`c20c3ee`) · Rama: `phase/13-mcp-diagnostic-gateway` · Tag objetivo (NO creado por el agente): `v0.13.0-mcp-diagnostic-gateway`.

Este documento describe lo que Fase 13 **implementa y ejecuta**: un servidor MCP **local, real, por stdio** (`python -m mcp_gateway`) que ofrece a Claude Code cinco herramientas diagnósticas semánticas y estrictamente controladas, con datos **sintéticos de fixture** por defecto. Invariantes: READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY · EVIDENCE FIRST · AGENTS FOR DOMAINS, SKILLS FOR TASKS.

## 1. Estado real de las integraciones (sin sobrepromesas)

| Integración | Estado | Evidencia |
|---|---|---|
| Servidor MCP stdio (handshake, `tools/list`, `tools/call`, ciclo de vida, límites) | `VERIFIED_FIXTURE` | `tests/test_p13_mcp_protocol.sh` (subproceso real por stdin/stdout) |
| Adaptador `fixture` (datos sintéticos, único habilitado) | `VERIFIED_FIXTURE` | `tests/test_p13_tools_e2e.sh`, `..._sanitization.sh` |
| Adaptador `oracle_sql` (Oracle real vía SQL certificado) | `DISABLED` — no se importa ningún driver, no existe camino de conexión | `tests/test_p13_security.sh` |
| Adaptadores `oracle_diag_file`, `os_readonly` (alert log, OS/GI) | `CONTRACT_ONLY` | ídem |
| Puente Phase 11 (`rca_engine`) → Phase 12 (advisory, candidato KB) | `VERIFIED_FIXTURE` | `tests/test_p13_integration_phase11_12.sh` |
| Cualquier entorno real (Oracle/OS/red) | `NOT_INTEGRATION_TESTED` — no hay laboratorio aprobado ni credenciales dedicadas | §10 |
| Comandos `/healthcheck`, `/diagnose`, `/rca`, `/change`, `/document`, `/knowledge` con orquestación de agente vivo | `CONTRACT_ONLY` (Phase 13 no los habilita; las tools del gateway son insumo, no un runtime de agentes) | `mcp/tool-manifest.md` |

`producción` y `laboratorio` **no** se simulan: `collected_at_utc` es `null` y `provenance` es `{"kind":"FIXTURE","real_observation":false}` en toda respuesta de esta versión.

## 2. Matriz AS-IS → integración Phase 13

| Componente existente | Interfaz concreta | Reutilización en Phase 13 | Brecha cerrada | Prueba | Riesgo |
|---|---|---|---|---|---|
| `mcp/README.md`, `mcp/tool-manifest.md` | diseño Fase 1 (sin servidor) | se conserva como catálogo objetivo; se añade sección Fase 13 | no existía servidor MCP ejecutable | `test_p13_mcp_protocol` | bajo |
| `queries/**/Q-*.md` (Query Contract v2) | front matter + bloque SQL inmutable | el catálogo lee metadatos (R0, `READ_ONLY`, versiones, rol, licencia, límites) y `sha256` del SQL; nunca lo envía ni lo acepta de un cliente | ningún consumidor ejecutable de la metadata | `test_p13_security` (guard SQL) | medio: la ejecución real sigue `DISABLED` |
| `sanitizers/data-classification-policy.md` | KEEP/MASK/HASH/TOKENIZE/DROP | política por campo **ejecutable** (`mcp_gateway/evidence.py`), denegar por defecto | la política era declarativa | `test_p13_sanitization` | medio: heurística de secretos de Phase 11 |
| `rca_engine` (Phase 11) | `sanitize`, `tokenization`, `run_rca`, catálogo de reglas | firmas certificadas/tokens, tokens de target, RCA real | — | `test_p13_integration_phase11_12` | bajo |
| `change_documentation_knowledge` (Phase 12) | `adapt_rca_result`, `build_change_advisory`, `build_kb_candidate`, `safety.*` | advisory `NOT_EXECUTED_BY_ESTACK`, candidato KB sin publicar; lectura estricta y confinamiento de rutas | — | ídem | bajo |
| `config/allowed-targets.example.yaml`, política de identidad | alias sin credenciales | catálogo de destinos JSON por alias (`mcp_gateway/config/targets.fixture.json`) sin material de conexión | no había autorización por destino ejecutable | `test_p13_tools_e2e`, `..._security` | bajo |
| `config/capability-matrix.yaml` | dominios × versiones | nueva fila `mcp-gateway` (PARTIAL) | el gateway no figuraba | `test_capability_matrix_*` | bajo |
| Validador estático SQL (tests de Fase 3–8) | regex/AST sobre `queries/` | el catálogo re-aplica un guard de solo lectura sobre cada bloque cargado | defensa en profundidad | `test_p13_security` | bajo |
| Resolver de variantes (`docs/QUERY_VARIANTS.md`) | declarativo | **no** se reimplementa: el gateway usa `supported_oracle_versions` del front matter; la resolución por variante queda `CONTRACT_ONLY` | declarada como límite | — | medio (declarado) |

## 3. Arquitectura (`mcp_gateway/`, Python stdlib)

```text
stdin ─► server.py (framing, lifecycle, límites) ─► gateway.py (registry estático · schemas estrictos · autorización · presupuesto)
                                                        │
                    catalog.py (colectores certificados, destinos, capacidad) ─► adapters.py (fixture ✔ · reales ✘)
                                                        │ filas NO confiables
                                            evidence.py (validar → política por campo → minimizar → digest → ref opaca → auditoría final)
                                                        │
              bridge.py ─► rca_engine (Phase 11) ─► change_documentation_knowledge (Phase 12)      audit → stderr (sin argumentos)
```

| Módulo | Responsabilidad |
|---|---|
| `common.py` | límites, códigos de error con **mensaje fijo**, estados (`capability_status`, adaptador) |
| `schemas.py` | validador estricto (mismo esquema publicado en `tools/list` y aplicado en `tools/call`); rechaza objetos abiertos al registrar |
| `catalog.py` + `catalog/collectors.json` | allowlist de colectores con política por campo; metadatos y `sha256` de las queries certificadas; destinos; `evaluate_capability` |
| `adapters.py` | `fixture` (confinado, con tamaño y parseo estrictos), stubs `DISABLED/CONTRACT_ONLY`, plazo duro por operación |
| `evidence.py` | saneamiento por campo, sal por sesión, almacén de evidencia sólo saneada con TTL |
| `gateway.py` | tools estáticas, autorización por target/colector/versión/rol/licencia/adaptador/presupuesto, auditoría |
| `bridge.py` | evidencia saneada → RCA → advisory → estado del candidato KB |
| `server.py`, `cli.py`, `__main__.py` | MCP por stdio, entrypoint operador (`--targets`, `--fixtures-dir`, `--audit`) |

**Por qué una implementación de protocolo propia:** no hay SDK MCP instalado y esta fase no instala dependencias desde la red. El transporte es pequeño (JSON-RPC 2.0 por líneas), sin dependencias nuevas, y se prueba con un subproceso real. Versiones de protocolo soportadas: `2025-06-18` (preferida), `2025-03-26`, `2024-11-05`; un cliente con otra versión recibe `2025-06-18` y decide.

## 4. Transporte y protocolo

- `stdout` = sólo mensajes JSON-RPC (una línea, UTF-8 ASCII-escapado, `\n`); `stderr` = auditoría/log sanitizado. Sin listener TCP/HTTP, sin red, sin telemetría.
- Ciclo de vida: `initialize` → respuesta → `notifications/initialized` → `tools/*`. Antes de eso `tools/*` da `-32600`; `ping` funciona siempre; un segundo `initialize` se rechaza.
- Rechazados con texto fijo (sin reflejar la entrada): JSON inválido (`-32700`), lotes (arrays), tipos de `id` inválidos, claves duplicadas, `NaN/Infinity`, campos extra (única excepción: en `tools/call` se acepta la llave reservada MCP `_meta`, sólo como objeto; nunca se inspecciona, registra ni pasa al gateway — `CHG-ESTACK-MCP-META-001`), métodos desconocidos (`-32601`, incluidos `resources/*`, `prompts/*`), parámetros mal formados (`-32602`).
- Límites: 1 MiB por mensaje, profundidad 24, 2000 nodos, respuesta ≤ 256 KiB, ≤ 200 llamadas por sesión, ≤ 200 filas, plazo por operación (≤ 15 s; las llamadas a adaptadores corren con plazo duro y el bucle nunca se bloquea).
- Cierre limpio: EOF en stdin ⇒ exit 0; una línea parcial no cuelga el servidor.

## 5. Herramientas (catálogo v1)

Ninguna acepta SQL, comandos, rutas, URL ni parámetros de conexión; todos los objetos usan `additionalProperties: false`.

| Tool | Entrada | Devuelve |
|---|---|---|
| `diagnostics.list_capabilities` | ninguna | adaptadores y su estado, destinos (alias, habilitado, versión conocida/`UNKNOWN`, capacidad por colector), colectores |
| `diagnostics.describe_collector` | `collector_id` | metadatos certificados (riesgo, límites, versiones, rol/contenedor, licencia, privilegios mínimos, campos y su política) y `sha256` de la query; **nunca** el SQL |
| `diagnostics.collect` | `collector_id`, `target_alias`, `max_rows?` | evidencia saneada y minimizada + `evidence_refs` opacas |
| `diagnostics.get_evidence` | `evidence_ref`, `target_alias` | la misma evidencia saneada; misma sesión y target; nunca raw |
| `diagnostics.analyze_incident` | `target_alias`, `evidence_refs[≤10]` | RCA real (estado autoritativo), hipótesis con contradicciones, recomendaciones `NOT_EXECUTED`, advisory `NOT_EXECUTED_BY_ESTACK`, estado del candidato KB |

Sobre de respuesta común: `status` (`OK|DEGRADED|ERROR`), `tool_id`, `request_id` (aleatorio), `schema_version`, `collector_id`, `target_token` (`TGT-…`, por sesión), `collected_at_utc` (`null` en fixture), `capability_status`, `sanitization_status`, `evidence_refs`, `limitations`, `provenance`, `error{code,message}` fijo. `tools/call` devuelve `content` (texto JSON), `structuredContent` (igual) e `isError`.

Desde `CHG-ESTACK-VALIDATION-MATRIX-001`: `diagnostics.collect` y `diagnostics.get_evidence` agregan `field_validation` (`level` `FIELD_VALIDATED`/`FIELD_VALIDATED_OTHER_CONTEXT`/`DOCUMENTATION_ONLY`, `reason`, `validated_context`, `differences`, `not_compared`, `change_ids`, `evidence_refs`) para el target consultado. `diagnostics.describe_collector` lista los contextos validados y el nivel por target. `diagnostics.analyze_incident` agrega `field_validation.per_evidence`, `confidence_ceiling` (`PROBABLE_CAUSE` si alguna evidencia no está validada en campo para ese target) y una limitación `EVIDENCE_NOT_FIELD_VALIDATED:<collector>:<nivel>` por cada una. `provenance` dice de dónde vienen los datos; `field_validation` dice si la **query** se probó en Oracle real en un contexto como éste. Desde `CHG-ESTACK-DISC-ARCHITECTURE-001`/`CHG-ESTACK-VALIDATION-RU-001`: `collect` de `Q-DISC-ARCHITECTURE-001` agrega `architecture_check` y el de `Q-DISC-IDENTITY-001` agrega `release_update_check` (observado frente a declarado); con datos REAL, lo observado se usa para la validación en campo de la sesión. Ver [policies/field-validation-policy.md](../policies/field-validation-policy.md).

### 5.1 Matriz herramienta → colector → capacidad → versión → licencia → permisos → sanitizador → pruebas

| Colector (`collector_id`) | Origen | Versiones (front matter) | Rol / licencia | Permisos mínimos | Campos y política | Estado adaptadores |
|---|---|---|---|---|---|---|
| `Q-DISC-IDENTITY-001` | query certificada | 10g–23ai | ANY / none | `SELECT` sobre `V$INSTANCE`, `V$DATABASE` | `instance_name`,`db_name` MASK; `version`,`database_role`,`cdb`,`open_mode` KEEP | fixture ✔ · oracle_sql DISABLED |
| `Q-ORA-RESOURCE-LIMITS-001` | query certificada | 10g–23ai | ANY / none | `SELECT` sobre `V$RESOURCE_LIMIT` | enum + enteros acotados KEEP | ídem |
| `Q-ORA-PROCESSES-SUMMARY-001` | query certificada | 10g–23ai | ANY / none | `SELECT` sobre `V$PROCESS`, `V$PARAMETER` | enteros KEEP | ídem |
| `Q-ORA-DIAGNOSTICS-ALERTLOG-001` | colector de archivo certificado | 10g–23ai | ANY / none | lectura vía colector certificado | `event_time` KEEP (UTC); `signature` SIGNATURE (certificada o token `SIG-`); `message` **DROP** | fixture ✔ · oracle_diag_file CONTRACT_ONLY |
| `Q-DG-STATS-001` | query certificada | 10g–23ai | **STANDBY** / none | `SELECT` sobre `V$DATAGUARD_STATS` | enum + intervalo KEEP | fixture ✔ · oracle_sql DISABLED |
| `Q-CDB-TABLESPACES-001` | query certificada (CHG-ESTACK-ORA19C-LAB-003) | 12c–23ai, **`CDB_ROOT_ONLY`** | ANY / none | `SELECT` sobre `CDB_TABLESPACE_USAGE_METRICS`, `CDB_TABLESPACES`, `CDB_DATA_FILES` + `CONTAINER_DATA` | `tablespace_name` MASK; `con_id`, porcentaje, bloques, enums KEEP; `autoextend` no se expone | fixture ✔ (`fixture-cdb-root-19c`) · oracle_sql sólo en el lanzador lab |
| `Q-CDB-TEMP-001` | query certificada (CHG-ESTACK-ORA19C-LAB-003) | 12c–23ai, **`CDB_ROOT_ONLY`** | ANY / none | `SELECT` sobre `CDB_TEMP_FILES`, `CDB_TABLESPACES`, `GV$SORT_SEGMENT` | `tablespace_name` MASK; `con_id`, bytes KEEP | fixture ✔ · oracle_sql **no implementado** (en el lab, el uso llega vacío desde root; pendiente de `/change query`) |
| `Q-RMAN-FRA-USAGE-001` | query certificada (CHG-ESTACK-ORA19C-LAB-003) | 10g–23ai | ANY / none | `SELECT` sobre `V$FLASH_RECOVERY_AREA_USAGE`, `V$RECOVERY_FILE_DEST` | enum, porcentajes y bytes KEEP; `dest_name` (ruta) no se expone | fixture ✔ (`fixture-cdb-root-19c`) · oracle_sql sólo en el lanzador lab |
| `Q-RMAN-BACKUP-FRESHNESS-001` | query certificada (CHG-ESTACK-ORA19C-LAB-004) | 10g–23ai | ANY / none | `SELECT` sobre `V$BACKUP_DATAFILE`, `V$BACKUP_SET`, `V$BACKUP_SPFILE` | enum + horas calculadas en la base (sin fechas absolutas) KEEP | fixture ✔ · oracle_sql sólo en el lanzador lab |
| `Q-RMAN-JOB-SUMMARY-001` | query certificada (CHG-ESTACK-ORA19C-LAB-004) | 10g–23ai | ANY / none | `SELECT` sobre `V$RMAN_BACKUP_JOB_DETAILS` | enums + horas/contadores/segundos KEEP | ídem |
| `Q-DICT-VERIFY-001`, `Q-DICT-VERIFY-002`, `Q-DICT-VERIFY-003`, `Q-DICT-VERIFY-004`, `Q-DICT-VERIFY-005` | queries certificadas **generadas** desde `compatibility/oracle-dictionary/views.yaml` (CHG-ESTACK-ORA19C-LAB-006) | 19c | ANY / none | `SELECT` sobre `DBA_TAB_COLUMNS` y `DBA_SYNONYMS` (vía `SELECT_CATALOG_ROLE`) | enums acotados al diccionario + contador KEEP; sólo discrepancias | ídem |
| `Q-DISC-ARCHITECTURE-001` | query certificada (CHG-ESTACK-DISC-ARCHITECTURE-001) | 11g–23ai | ANY / none | `SELECT` sobre `GV$INSTANCE`, `V$PARAMETER`, `V$DATAFILE`, `V$ASM_DISKGROUP_STAT`, `V$DATABASE`, `V$ARCHIVE_DEST` | conteos + enums KEEP; el gateway agrega `architecture_check` (observado vs. declarado) | ídem |
| `Q-RMAN-BACKUP-DEVICE-001` | query certificada 2.0.0 (corregida en LAB-007; expuesta en CHG-ESTACK-LAB-REVALIDATE-007) | 10g–23ai | ANY / none | `SELECT` sobre `V$BACKUP_DEVICE` | enum KEEP, nombre de dispositivo MASK | ídem |
| `Q-SEC-PROXY-AUTHENTICATION-001` | query certificada 2.0.0 (ídem) | 10g–23ai (V2 con `FLAGS` desde 11.2) | ANY / none | `SELECT` sobre `PROXY_USERS` | usuarios MASK, `authentication`/`flags` enum KEEP | ídem |
| `Q-ASM-TOPOLOGY-001` | query certificada 2.0.0 (ídem) | 11g–23ai | ANY / none | `SELECT` sobre `V$ASM_CLIENT`, `V$ASM_DISKGROUP_STAT` | nombres MASK, estados enum, capacidades KEEP | ídem |
| `Q-DISC-INSTANCE-001`, `Q-ORA-INSTANCE-STATE-001`, `Q-ORA-DB-STATE-001`, `Q-ORA-COMPONENTS-001`, `Q-ORA-CONTROLFILE-001`, `Q-ORA-REDO-001`, `Q-ORA-SESSIONS-SUMMARY-001`, `Q-ORA-UNDO-001`, `Q-DBA-TBS-USAGE-001`, `Q-DBA-TBS-DATAFILES-001`, `Q-ORA-TEMP-001`, `Q-ORA-INVALID-OBJECTS-001`, `Q-ORA-OBJECTS-INVENTORY-001`, `Q-ORA-JOBS-SUMMARY-001`, `Q-ORA-DIAGNOSTICS-ADR-001`, `Q-ORA-ARCHIVE-001`, `Q-ORA-PARAMETERS-001`, `Q-ORA-SPFILE-001` | queries certificadas; collectors **generados** por la fábrica (lote B1, `CHG-ESTACK-COLLECTOR-FACTORY-B1`, [docs/COLLECTOR_FACTORY.md](COLLECTOR_FACTORY.md)) | según cada query (10g–23ai; ADR 11g+) | ANY / none | los `privileges_required` de cada query (`SELECT_CATALOG_ROLE` en el lab) | nombres de owner/objeto/tablespace/job/instancia/host MASK; estados enum, conteos, bytes y horas calculadas en la base KEEP; nombre de parámetro `parameter_name` KEEP y su valor sólo como número, TRUE/FALSE, versión o palabra clave cerrada; rutas, texto libre y fechas absolutas no se exponen | fixture ✔ (`fixture-primary-19c`) · oracle_sql sólo en el lanzador lab |
| `Q-PERF-WAIT-SYSTEM-001`, `Q-PERF-WAIT-CLASS-001`, `Q-PERF-DBTIME-CURRENT-001`, `Q-PERF-IO-001`, `Q-PERF-IO-FILESTAT-001`, `Q-PERF-LIBCACHE-001`, `Q-PERF-PGA-001`, `Q-PERF-SGA-001`, `Q-PERF-SHAREDPOOL-001`, `Q-PERF-REDO-001`, `Q-PERF-HARDPARSE-001`, `Q-PERF-TOPSQL-CURRENT-001`, `Q-PERF-BLOCKING-001`, `Q-PERF-TEMP-001`, `Q-PERF-PARALLEL-001`, `Q-ORA-REDO-SWITCH-24H-001` | queries certificadas; collectors **generados** por la fábrica (lote B2 de rendimiento, `CHG-ESTACK-COLLECTOR-FACTORY-B2`, [docs/COLLECTOR_FACTORY_B2.md](COLLECTOR_FACTORY_B2.md)) | según cada query (10g–23ai) | según cada query / none (sin Diagnostics Pack) | los `privileges_required` de cada query | nombres de evento y namespace `oracle_term` KEEP; `sql_id` KEEP (nunca texto SQL); clases de espera y estados enum; conteos, tiempos, bytes y ratios KEEP; tablespace MASK; rutas de archivo, direcciones de memoria y fechas no se exponen | fixture ✔ (`fixture-primary-19c`) · oracle_sql sólo en el lanzador lab |
| `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001`, `Q-SEC-NESTED-ROLE-GRANTS-001`, `Q-SEC-UNIFIED-AUDIT-TRAIL-001`, `Q-SEC-TRADITIONAL-AUDIT-001`, `Q-SEC-DIRECTORIES-001`, `Q-SEC-DEFAULT-ACCOUNTS-001` | queries de seguridad corregidas; collectors **generados** por la fábrica (lote B3, `CHG-ESTACK-SEC-QUERIES-001`, [docs/SEC_QUERIES.md](SEC_QUERIES.md)) | según cada query | ANY / none | `SELECT_CATALOG_ROLE`; `AUDIT_VIEWER` para la auditoría unificada; `SELECT` sobre `DBA_USERS_WITH_DEFPWD` | roles, usuarios, directorios y grantees MASK; privilegios y acciones `oracle_term` KEEP; estados y flags enum; conteos KEEP; rutas de directorio, texto SQL y filas crudas de auditoría no se exponen | fixture ✔ (`fixture-primary-19c`) · oracle_sql sólo en el lanzador lab |
| `Q-PERF-AWR-DBTIME-24H-001`, `Q-PERF-AWR-TOPSQL-24H-001`, `Q-PERF-AWR-WAITS-24H-001`, `Q-PERF-ASH-1H-001` | queries certificadas nuevas; collectors **generados** por la fábrica (lote B4, `CHG-ESTACK-AWR-LICENSED-001`, [docs/AWR_LICENSED.md](AWR_LICENSED.md)) | 10g–23ai | PRIMARY / **Diagnostics Pack** (sólo con `license_status.diagnostics_pack = CONFIRMED`) | `SELECT` sobre `DBA_HIST_*` y `V$ACTIVE_SESSION_HISTORY` (`SELECT_CATALOG_ROLE`) | eventos `oracle_term`, `sql_id` KEEP (nunca texto SQL), clases de espera enum, deltas de AWR, horas y conteos KEEP; sin sesiones ni usuarios | fixture ✔ (`fixture-licensed-19c`) · oracle_sql sólo en el lanzador lab |
| `Q-CDB-PDB-STATE-001`, `Q-CDB-SERVICES-001`, `Q-CDB-PLUGIN-VIOLATIONS-001`, `Q-SEC-UNIFIED-AUDIT-POLICIES-001`, `Q-SEC-PASSWORD-PROFILES-001`, `Q-SEC-ADMIN-PRIVILEGES-001`, `Q-RMAN-CONFIGURATION-001` | queries certificadas ya existentes, reescritas donde hacía falta; collectors **generados** por la fábrica (lote B5, `CHG-ESTACK-PDB-COVERAGE-001`, [docs/PDB_COVERAGE.md](PDB_COVERAGE.md)) | 10g–23ai (multitenant y políticas de auditoría unificada 12c+) | ANY / sin licencia | `SELECT_CATALOG_ROLE` + `SELECT ON SYS.PDB_PLUG_IN_VIOLATIONS` + `CONTAINER_DATA` | nombres de PDB, servicio, perfil y usuario MASK; políticas sólo `ORA_*` o `CUSTOM`; causa y nombre de configuración RMAN `oracle_term`; límites y valores RMAN clasificados (enum + número); sin texto libre, fechas absolutas ni rutas | fixture ✔ (`fixture-cdb-root-19c`) · oracle_sql sólo en el lanzador lab |
| `Q-DISC-CLOCK-001`, `Q-CDB-CONTAINER-DATA-001` | queries certificadas nuevas; collectors **generados** por la fábrica (lote B6, `CHG-ESTACK-ASSESSMENT-ACCURACY-001`, [docs/ASSESSMENT_ACCURACY.md](ASSESSMENT_ACCURACY.md)) | reloj 10g–23ai; `CONTAINER_DATA` 12c+ | ANY / sin licencia | `SELECT` sobre `DUAL` y `DBA_CONTAINER_DATA` (`SELECT_CATALOG_ROLE`) | hora UTC de la base como número; el gateway publica `clock_check` (desfase contra su reloj; `CLOCK_SKEW` > 300 s); tipo de contenedor y flags KEEP, nombre de PDB MASK, filtrado por `SESSION_USER` | fixture ✔ (`fixture-cdb-root-19c`) · oracle_sql sólo en el lanzador lab |
| `os.get_process_limits` | colector semántico OS (`docs/OS_READONLY_COLLECTOR_MODEL.md`) | todas | ANY / none | lectura de límites del usuario de diagnóstico | número acotado, enum KEEP | fixture ✔ · os_readonly CONTRACT_ONLY |
| `os.get_oracle_process_summary` | colector semántico OS | todas | ANY / none | lectura de estado de procesos | booleano, entero KEEP | ídem |

Autorización por llamada (todas fallan cerradas): destino registrado y habilitado → colector permitido para ese destino → adaptador realmente ejecutable → **versión** (`ENVIRONMENT_UNKNOWN` si el destino no la declara; `UNSUPPORTED` si la query no la cubre) → **contenedor** (`CDB_ROOT_ONLY` sólo con destino `CDB_ROOT`; si no, `NOT_APPLICABLE`/`ENVIRONMENT_UNKNOWN`) → **rol** (`NOT_APPLICABLE`/`ENVIRONMENT_UNKNOWN`) → **licencia** (`LICENSE_RESTRICTED` salvo `CONFIRMED` declarada) → presupuesto de llamadas/filas por destino y por sesión. Un alias registrado **no** es una autorización.

## 6. Modelo de amenazas y controles

**Activos:** integridad de los sistemas administrados (nada se escribe ni se ejecuta), confidencialidad de datos/identificadores, integridad de las conclusiones (RCA, advisory), disponibilidad del servidor local.
**Actores:** el modelo (puede ser manipulado por datos), datos no confiables (logs, filas, nombres, fixtures), un usuario local malicioso o un proceso hermano (stdio local **no** autentica a la persona), configuración alterada.
**Fronteras de confianza:** cliente MCP ⇄ servidor (JSON-RPC), servidor ⇄ adaptador (filas **no confiables**), servidor ⇄ archivos (catálogo/fixtures), servidor ⇄ motores Phase 11/12 (importación local).

| Amenaza | Control (y prueba) |
|---|---|
| SQL/shell/ruta/URL/DSN en `tools/call` | no existe parámetro que los admita; esquemas cerrados con patrones anclados y longitud máxima (`test_p13_tools_e2e`, `..._security`) |
| Colector/alias no registrado, traversal en ids | gramática estricta + allowlist + `confine()` (sin `..` ni enlaces) |
| Secretos en cualquier campo/subcampo/firma/clave | denegar por defecto por campo, tipos estrictos, `DROP` de texto libre, firmas certificadas o token, auditoría final estructurada (`test_p13_sanitization`) |
| Inyección de instrucciones en datos | los datos no cambian el catálogo ni la política; el texto libre no tiene camino al modelo; pruebas de inercia |
| Referencias adivinables/enumerables, cross-target/cross-sesión | `EVR-` + 96 bits aleatorios, atadas a (sesión, target), respuesta idéntica para «no existe/otro ámbito/expirado» |
| Adaptador lento/colgado, resultado malformado | plazo duro (`E_TIMEOUT`), forma validada (`E_RESULT_INVALID`), excepciones → código fijo |
| Mensajes enormes/profundos/anchos/basura, lifecycle roto | límites y rechazo sin procesar; el servidor sigue vivo |
| Habilitar un adaptador real por flag/env/archivo | no existe la opción; adaptadores reales sin código de conexión; `evaluate_capability` sólo admite `VERIFIED_FIXTURE/VERIFIED_LAB` |
| Filtración por errores, `stderr` o auditoría | mensajes fijos, sin trazas, auditoría con claves fijas y sin argumentos |
| Defensas desactivadas silenciosamente | 11 controles de mutation testing (`test_p13_mutation_controls`) |

**Riesgos residuales (no resueltos «mágicamente»):** stdio local no autentica a la persona; un equipo comprometido o credenciales externas quedan fuera de alcance; la sanitización de Phase 11 es heurística y sesgada a sobre-redactar; el SQL certificado no se ejecuta hoy (los adaptadores reales no existen); la resolución por variantes de query es `CONTRACT_ONLY`; una aprobación local de KB sigue siendo `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`.

## 7. Política de sanitización, privacidad y retención

- **Dato → modelo:** `filas no confiables → validación de forma → política por campo → minimización (filas) → digest → referencia opaca → auditoría estructurada final`. Un campo no declarado se descarta; sólo se informa un **conteo** (`FIELDS_DROPPED_BY_POLICY:N`), nunca su nombre ni valor.
- `MASK` → alias estable por sesión/destino (`inst-A1`); `HASH`/`TOKENIZE` → HMAC con **sal aleatoria por sesión** (no reversible, no correlaciona entre sesiones ni destinos); `SIGNATURE` → literal sólo si es un código certificado (gramática tipada o catálogo), si no `SIG-…`; identificadores con homoglifos o forma de secreto se descartan.
- Números/booleanos/fechas conservan tipo y valor dentro de rangos declarados; `NaN/Infinity`, booleanos como enteros, anidados y desbordes se descartan; las marcas de tiempo se normalizan a UTC.
- **Raw:** nunca se almacena ni se entrega por MCP (ni siquiera en fixture). **Retención:** sólo evidencia saneada, en memoria, TTL 1 h, máx. 300 entradas, se borra al cerrar la sesión; no hay persistencia en disco. Borrado temprano: cerrar el servidor.
- **Límite de inferencia:** «MCP local» **no** significa modelo local. La evidencia saneada que recibe Claude Code puede procesarse fuera del equipo según la configuración real del producto; por eso se minimiza antes de salir.

## 8. Ejemplos E2E (sintéticos y saneados)

```text
→ {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"demo","version":"0"}}}
← {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"oracle-diagnostic-estack-mcp-gateway","version":"1.0.1"},…}}
→ {"jsonrpc":"2.0","method":"notifications/initialized"}
→ {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"diagnostics.collect","arguments":{"collector_id":"Q-ORA-PROCESSES-SUMMARY-001","target_alias":"fixture-primary-19c"}}}
← …"structuredContent":{"status":"OK","capability_status":"SUPPORTED","collected_at_utc":null,"provenance":{"kind":"FIXTURE","real_observation":false},
   "evidence_refs":["EVR-<24 hex>"],"evidence":{"columns":["process_count","processes_limit"],"rows":[{"process_count":188,"processes_limit":200}],"row_count":1,"digest":"<sha256>"},…}
→ …"arguments":{"collector_id":"Q-DISC-IDENTITY-001","target_alias":"fixture-primary-19c","sql":"select 1 from dual"}
← …"isError":true,"structuredContent":{"status":"ERROR","error":{"code":"E_ARGS_INVALID","message":"arguments do not satisfy the tool schema"},…}   (la entrada no se refleja)
```

Cadena Phase 11/12: `collect` (`Q-ORA-DIAGNOSTICS-ALERTLOG-001`, `os.get_process_limits`, `os.get_oracle_process_summary`) → `analyze_incident` ⇒ `rca.completeness: CONFIRMED` (`rca_engine` decide), recomendación `execution_status: NOT_EXECUTED`, advisory `NOT_EXECUTED_BY_ESTACK` con `review_status: REVIEW_REQUIRED`, candidato KB `CANDIDATE` (no publicado). Con una sola fuente o con evidencia contradictoria el estado **no** llega a `CONFIRMED` y el candidato queda `REJECTED`.

## 9. Configuración de Claude Code, arranque/parada y diagnóstico

Ejemplo **sin credenciales** (`mcp/claude-code.mcp.example.json`, o `python -m mcp_gateway --print-claude-config`): comando `python -m mcp_gateway`, `cwd` = su checkout (marcador `<ABSOLUTE_PATH_TO_YOUR_CHECKOUT_OF_THE_REPOSITORY>`). **No se modifica ninguna configuración real**; cópielo usted mismo.

- Arranque manual de prueba: `python -m mcp_gateway --version` / `--print-claude-config`; el servidor real espera mensajes por stdin.
- Parada: cerrar stdin (el cliente lo hace al terminar) ⇒ exit 0.
- Diagnóstico: `stdout` sólo protocolo (si algo ilegible aparece, es un defecto); líneas `AUDIT {…}` y errores de arranque van a `stderr`; `--audit off` silencia la auditoría. Arranque rechazado ⇒ exit 2, `stdout` vacío y el texto fijo `startup refused` (revise `--targets`/`--fixtures-dir`).
- Plataformas: verificado en **Windows (Git Bash) con Python 3.13**; Linux/macOS **no probados** en este entorno (código sin dependencias de plataforma; codificación UTF-8 con salida ASCII-escapada y `\n`).

## 10. Habilitar un target real (procedimiento humano — NO ejecutado)

No hay laboratorio aprobado. Antes de cualquier integración real, un humano debe: (1) aprobar por escrito el destino y el alcance; (2) proveer una cuenta diagnóstica dedicada de mínimo privilegio y un mecanismo externo de secretos (nunca en `tools/call`, flags ni archivos del repo); (3) implementar y **revisar por `/change`** un adaptador que ejecute únicamente el SQL certificado inmutable con binds tipados, límites y timeout, verificando identidad/rol/CDB-PDB/versión de la sesión y abortando ante un contexto inesperado; (4) certificar el colector contra el resolver de variantes y las licencias; (5) probarlo en un laboratorio aprobado (`VERIFIED_LAB`) con evidencia; (6) sólo entonces cambiar el estado del adaptador por un cambio de código revisado. Hasta entonces: `NOT_INTEGRATION_TESTED`.

## 11. Rollback manual del gateway

No modifica sistemas administrados. Para retirarlo: quite la entrada `oracle-diagnostic-estack` de su configuración MCP de Claude Code; para revertir el código, revierta manualmente el merge de Phase 13 (o vuelva al tag `v0.12.0-change-documentation-knowledge`). No hay estado persistente que limpiar.

## 12. Pruebas

Siete suites `tests/test_p13_*.sh` (unit, protocolo MCP real, tools E2E, sanitización, seguridad, integración Phase 11/12, mutation controls) sobre fixtures sintéticos; sin Oracle, red ni acceso al host. Los conteos se toman del runner real (`tests/run-all.sh`) y se reportan en el informe de la fase.
