# CHANGELOG

Versionado semántico del e-stack. Cambios por artefacto individual (agente/skill/query/workflow/policy) se versionan por separado según `EVOLUTION.md`; este changelog cubre el repositorio en su conjunto.

## [Unreleased] — 2026-09-08 — Fase 6: Oracle Multitenant / CDB / PDB

Sexta capa funcional del e-stack, sobre baseline `v0.5.0-dataguard`. Ver `docs/PHASE_6_ORACLE_MULTITENANT.md` para el reporte de cierre completo.

### Added

- `agents/oracle-multitenant-analyst/` (`v2.0.0`) — reestructurado de manifest plano a contrato estructurado completo, mismo patrón que Fase 4/5.
- 26 skills `multitenant/*` completamente materializadas — `skills/REGISTRY.md` pasa de 141 a 166 skills `active`.
- `queries/multitenant/` — 15 queries certificadas (`Q-CDB-PDB-STATE-001`, `Q-CDB-CONTAINERS-001`, `Q-CDB-PDB-SAVED-STATE-001`, `Q-CDB-SERVICES-001`, `Q-CDB-SESSION-DIST-001`, `Q-CDB-TABLESPACES-001`, `Q-CDB-TEMP-001`, `Q-CDB-PARAMETERS-001`, `Q-CDB-USERS-001`, `Q-CDB-ROLES-001`, `Q-CDB-COMPONENTS-001`, `Q-CDB-PLUGIN-VIOLATIONS-001`, `Q-CDB-RESOURCE-USAGE-001`, `Q-CDB-RESOURCE-MANAGER-001`, `Q-CDB-LOCKDOWN-001`).
- `compatibility/oracle-dictionary/views.yaml` — 15 vistas Multitenant nuevas, 7 con `columns_exhaustive: true` (`V$PDBS`, `V$CONTAINERS`, `DBA_PDB_SAVED_STATES`, `PDB_PLUG_IN_VIOLATIONS`, `V$RSRCPDBMETRIC`, `DBA_CDB_RSRC_PLAN_DIRECTIVES`, `CDB_LOCKDOWN_PROFILES` — nombre/rango de las primeras 3 corregido en el hardening posterior, ver entrada `[Unreleased] Fase 6: Query Compatibility & Dictionary Certification Hardening` abajo).
- `docs/PHASE_6_ORACLE_MULTITENANT.md` (incluye el Manual Action Contract), `docs/MULTITENANT_DIAGNOSTIC_MODEL.md`, `docs/CDB_PDB_QUERY_MODEL.md`, `docs/MULTITENANT_READONLY_PRIVILEGES.md`, `docs/PDB_HEALTHCHECK_MODEL.md`.
- 14 fixtures de escenario (11g NON-CDB, 12.1/12.2/19c/21c/23ai CDB, RAC PDB placement, PDB mounted/restricted, plug-in violations, temp/resource pressure, contexto Data Guard, Application Container, versión futura desconocida).
- 53 tests nuevos: 14 query/inventario, 7 versión, 4 RAC, 5 plug-in violations, 4 recursos, 15 seguridad específicos de Fase 6 (`# 62`: no create/drop/clone/unplug/plug PDB, no open/close/save-state execution, no alter session container si prohibido, no common/local user create, no lockdown/resource-manager/parameter change, queries SELECT-only), 4 contrato de agente.

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — Multitenant `PARTIAL → SUPPORTED` (12.1–23ai); columna `latest` reemplazada por `future_status: COMPATIBILITY_VALIDATION_REQUIRED` (mismo criterio que Data Guard Fase 5).
- `queries/REGISTRY.md` — corregido un gap pre-existente: `Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001` (Foundation) nunca tuvieron archivo real ni `container_scope` correcto pese a figurar "materializadas"; ahora genuinamente construidas bajo `queries/multitenant/`.
- `docs/TARGET_PROFILE.md` — schema `2.2.0 → 2.3.0` (aditivo): bloque `multitenant`.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — nota apuntando a `docs/MULTITENANT_READONLY_PRIVILEGES.md` (documento nuevo, no consolidado aquí).
- `ARCHITECTURE.md` — 2 principios nuevos (26: Container Scope Contract; 27: `MESSAGE`/`ACTION` como DATA + Health Model sin score único).
- `SECURITY.md` — caso concreto `PDB_PLUG_IN_VIOLATIONS.MESSAGE`/`.ACTION` como vector de inyección interno a la base de datos (distinto de los casos previos de salida de comando externo).

### Known limitations

Ver `docs/PHASE_6_ORACLE_MULTITENANT.md#known-limitations`. En resumen: Application Containers/Proxy PDB reconocidos por topología sin análisis profundo de lifecycle (`PARTIALLY_SUPPORTED`); 8 vistas `CDB_*` mirror estándar registradas sin `columns_exhaustive: true`; sin errores ORA-650xx/651xx específicos en `knowledge/errors/` (opcional, no inventado).

### Fixed — PHASE 6 — Multitenant Query Compatibility & Dictionary Certification Hardening

Cierre de 3 defectos de certificación detectados antes de aprobar `v0.6.0-multitenant`. Ver `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md` para el detalle completo.

- **`Q-CDB-PDB-SAVED-STATE-001` (bug real)**: seleccionaba `FROM cdb_pdb_saved_states` — esa vista no existe (WebFetch: 404 en docs.oracle.com). Corregida a v2.0.0, usa `DBA_PDB_SAVED_STATES` (7 columnas reales). Además, la feature requiere patch level 12.1.0.2 — no existe en 12.1.0.0/12.1.0.1; `config/query-compatibility-matrix.yaml` y el dictionary ahora declaran `min: "12.1.0.2"` (patch-level), con una extensión aditiva del comparador de versión (`vernum3`) acotada a este caso.
- **`Q-CDB-RESOURCE-USAGE-001` (rango de versión incorrecto)**: `V$RSRCPDBMETRIC` declarada disponible desde 12.1 sin verificación independiente — en realidad se introduce en 12.2.0.1 (WebFetch confirmado). Corregida a `min: "12.2"`; 12.1 degrada explícitamente a `capability_status: PARTIALLY_SUPPORTED` (sin fuente alternativa inventada) en `skills/multitenant/resource-usage/SKILL.md`.
- **`Q-CDB-PLUGIN-VIOLATIONS-001` (rango de versión incorrecto)**: `CON_ID` seleccionado incondicionalmente desde 12.1 — esa columna no existe en la referencia 12.1 (9 columnas), se agrega en 12.2 (10 columnas, WebFetch confirmado en ambas versiones). Corregida a v2.0.0 con dos variantes reales (legacy 12.1 sin `CON_ID` / modern 12.2+ con `CON_ID`); `skills/multitenant/plugin-violations/SKILL.md` normaliza `container_id: NOT_AVAILABLE` en la variante legacy, nunca inventado.
- **SQL Static Validator (causa raíz)**: sólo validaba existencia de columna en la vista, nunca si esa columna/vista ya existía en el `min_version` declarado del bloque SQL — por eso las 3 metadata incorrectas certificaron SQL incorrecto sin que ningún test lo detectara. Añadido un tercer chequeo (view-level y column-level `min_version` cross-check contra el rango declarado, patch-level-aware vía `vernum3`) sobre las 7 vistas Multitenant `columns_exhaustive: true`. Corregido de paso un efecto colateral: la derivación de `min` del bucle `implicit_full_range` (por etiqueta descriptiva "12c"→12.1) producía falsos positivos contra `Q-CDB-LOCKDOWN-001`/`Q-CDB-RESOURCE-USAGE-001` (ambas 12.2+-only) — sustituido por el `min` preciso de `config/query-compatibility-matrix.yaml` sólo para este chequeo nuevo, sin alterar el chequeo de version-gating original.
- Dictionary certification: `CDB_PDB_SAVED_STATES` eliminada (no era una vista real); `V$CONTAINERS` completada con bloque `validation:` (ya estaba verificada, faltaba la trazabilidad declarada); 2 tests negativos (`FAKE_MULTITENANT_VIEW`/`fake_column`) confirman que un nombre fabricado nunca certifica.
- 21 tests nuevos de regresión específicos de este hardening.

### Fixed — PHASE 6 — Final PDB Identity & Patch-Level Resolver Hardening

Cierre de los 2 últimos defectos antes de aprobar `v0.6.0-multitenant`. Ver `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md` para el detalle completo.

- **`PDB_PLUG_IN_VIOLATIONS.NAME` semantics (interpretación incorrecta)**: la construcción base y el hardening de compatibilidad asumían que `NAME` identifica "la violación/componente", no la PDB — verificado vía WebFetch (Oracle Database Reference 12.1 y 19c, ambas coinciden): *"The name of an existing PDB or a PDB intended to be created"*. `NAME` es identidad de PDB, disponible en todo el rango 12.1–23ai. Corregido: `Q-CDB-PLUGIN-VIOLATIONS-001.md` (v3.0.0) y `skills/multitenant/plugin-violations/SKILL.md` (v3.0.0) — en 12.1, `container_name`/`pdb_token` ahora se derivan de `NAME` (sanitizado, `container_id` sigue `NOT_AVAILABLE`); en 12.2+ se correlacionan `CON_ID`+`NAME`, publicando `IDENTITY_MISMATCH` si no coinciden. `name` corregido de sanitización `KEEP` a `MASK` (tokenizado, mismo criterio que `Q-CDB-PDB-STATE-001.name`). `ACTION`/`MESSAGE` mantienen su protección "siempre DATA" sin cambios.
- **Query Variant Resolver sin implementación compartida (causa raíz)**: el "resolver" nunca fue un componente único — era un algoritmo documentado reimplementado ad-hoc como `vernum()`/`vernum3()` local en ~22 archivos de test, sólo uno de ellos (el Static Validator) con soporte patch-level real. Anti-patrón: un test podía declarar cobertura patch-level sin que ninguna implementación real la tuviera. Fix: `scripts/lib/version.sh` — librería única compartida (`normalize_oracle_version`, `compare_oracle_versions`, `version_gte`, `version_lte`, `version_in_range`; modelo de 5-tupla, patch-level-aware, preserva los alias de marketing y el sentinel `latest` ya usados por ~40 queries de fases anteriores). `tests/test_sql_static_validator.sh` y `tests/test_query_variant_resolver_{10g,11g}.sh` refactorizados para consumirla — sin cambio de comportamiento, verificado explícitamente contra el resultado previo al refactor.
- 13 tests nuevos (identidad de PDB + librería de versión compartida + integración resolver) y 4 tests refactorizados sin cambio de comportamiento.
- ~~Conocido: la librería compartida no se propagó a los ~17 archivos de test de resolución de variantes fuera de alcance...~~ — **resuelto**, ver subsección siguiente.

### Fixed — PHASE 6 — Version Resolver Consolidation Finalization

Cierra el último bloqueo antes de aprobar `v0.6.0-multitenant`. Ver `docs/PHASE_6_VERSION_RESOLVER_CONSOLIDATION_FINALIZATION.md` para el detalle completo.

- **Migración completa**: los 17 archivos de test restantes que reimplementaban `vernum()`/`vernum3()` localmente (`test_query_variant_resolver_{12c,18c,19c,21c,23ai}.sh`, `test_dataguard_process_variant_resolution_{11g,121,122,19c,23ai}.sh`, `test_dataguard_{23ai_supported_when_certified,24_or_future_not_auto_supported}.sh`, `test_fixture_query_variant_resolution.sh`, `test_query_variant_ranges_do_not_overlap_invalidly.sh`, `test_version_resolver_{12101,12102}.sh`, `test_plugin_violation_variant_resolution.sh`) migrados a `scripts/lib/version.sh` — sin cambio de comportamiento verificado explícitamente, salvo un hallazgo real: `test_query_variant_resolver_12c.sh` detectó que `Q-CDB-PDB-SAVED-STATE-001` (min real `12.1.0.2`) resolvía incorrectamente como compatible para "12c" con el comparador 2-tier antiguo (patch level ignorado) — el comparador patch-level-aware corrige esto correctamente (no una regresión).
- **Enforcement global endurecido**: `tests/test_query_variant_resolver_uses_shared_version_library.sh` reescrito de un allowlist fijo de 7 archivos a una verificación dinámica — delega la comprobación negativa a un nuevo test global (`tests/test_no_local_version_resolvers_in_tests.sh`, recorre `tests/**/*.sh`+`scripts/**/*.sh` excepto la librería canónica) y comprueba positivamente que todo test que invoque una función de la librería la sourcee, sin exigir el import a tests que no comparan versiones.
- 2 tests nuevos (`test_no_local_version_resolvers_in_tests.sh`, `test_shared_version_library_exists.sh`).
- Documentación obsoleta corregida: `queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md` y la cabecera de `compatibility/oracle-dictionary/views.yaml` ya no describen "el resolver genérico compara sólo major.minor" como limitación vigente — declaran `scripts/lib/version.sh` como la única implementación de comparación de versión autorizada en todo el repositorio.

## [0.5.0-dataguard] — 2026-09-07 — Fase 5: Oracle Data Guard

Quinta capa funcional del e-stack, sobre baseline `v0.4.0-rac-gi-asm-network`. Ver `docs/PHASE_5_ORACLE_DATAGUARD.md` para el reporte de cierre completo.

### Added

- `agents/oracle-dataguard-analyst/` (`v2.0.0`) — reestructurado de manifest plano a contrato estructurado completo, mismo patrón que Fase 4.
- 21 skills `dataguard/*` completamente materializadas — `skills/REGISTRY.md` pasa de 120 a 141 skills `active`.
- `queries/dataguard/` — 7 queries certificadas (`Q-DG-ROLE-001`, `Q-DG-STATS-001`, `Q-DG-DEST-001`, `Q-DG-ARCHIVED-LOG-001`, `Q-DG-ARCHIVE-GAP-001`, `Q-DG-MANAGED-PROCESS-001`, `Q-DG-SRL-001`).
- `parsers/dataguard/` (nuevo, Python 3 stdlib-only) — `broker_parser.py` (4 funciones DGMGRL `SHOW`), `alertlog_filter.py` (filtro local de alert.log), mismo envelope/disciplina de seguridad que `parsers/rac/` de Fase 4.
- `docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md` — Collector Contract Broker (reutiliza Fase 4), `docs/DATAGUARD_DIAGNOSTIC_MODEL.md`, `docs/DATAGUARD_READONLY_QUERIES.md`, `docs/DATAGUARD_SWITCHOVER_READINESS.md`, `docs/DATAGUARD_FAILOVER_READINESS.md`, `docs/PHASE_5_ORACLE_DATAGUARD.md` (incluye el Manual Action Contract).
- 17 fixtures de escenario (11gR2/19c/23ai, RAC primary+standby, transport/apply lag, archive gap, MRP stopped, destination error, SRL insuficiente, degradación de protección, Broker healthy/warning, FSFO enabled, switchover ready/not-ready, failover exposure) + 6 fixtures de salida DGMGRL Broker (`tests/fixtures/broker/`, incl. prueba de prompt-injection).
- ~80 tests nuevos: 10 query, 11 Broker, 6 transporte, 7 apply, 4 gap, 6 SRL, 7 readiness, 3 licensing, ~17 seguridad específicos de Fase 5, 4 contrato de agente.

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — Data Guard `PARTIAL → SUPPORTED` (10g–23ai para Physical Standby).
- `queries/REGISTRY.md` — corregido un gap pre-existente: `Q-DG-STATS-001`/`Q-DG-ARCHIVE-GAP-001` (Foundation) nunca tuvieron archivo real pese a figurar "materializadas"; ahora genuinamente construidas bajo `queries/dataguard/`.
- `docs/TARGET_PROFILE.md` — schema `2.1.0 → 2.2.0` (aditivo): bloque `dataguard`.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — grants Data Guard, cuarta identidad separada (Broker diagnóstica).
- `mcp/tool-manifest.md` — 9 tools nuevas; corregida referencia stale de `get_dataguard_status`.

### Known limitations

Ver `docs/PHASE_5_ORACLE_DATAGUARD.md#known-limitations`. En resumen: Logical/Snapshot Standby/Far Sync reconocidos sin análisis profundo; `broker_parser.py` primera versión funcional; leak real de `db_unique_name` sin tokenizar detectado y corregido durante la construcción (campo `observer_state` eliminado del parser).

### Fixed — PHASE 5 — Data Guard Compatibility & Query Certification Hardening

Cierre de 3 defectos de certificación detectados antes de aprobar `v0.5.0-dataguard`. Ver `docs/PHASE_5_COMPATIBILITY_HARDENING.md` para el detalle completo.

- **`Q-DG-ROLE-001` (bug real)**: seleccionaba `LOG_ARCHIVE_CONFIG` de `V$DATABASE` — esa columna no existe ahí (es un parámetro, vía `V$PARAMETER`). Corregida a v2.0.0; fuente correcta documentada vía `Q-ORA-PARAMETERS-001`.
- **SQL Static Validator (causa raíz)**: sólo validaba version-gating de 4 columnas conocidas, nunca existencia real de columna — por eso el bug de `Q-DG-ROLE-001` pasó todos los tests. Añadido un segundo chequeo de existencia de columna (alias-aware, JOIN/comma-join-aware, abstención ante subqueries) sobre vistas marcadas `columns_exhaustive: true` en `compatibility/oracle-dictionary/views.yaml` (9 vistas Data Guard auditadas en este hardening). Halló, de paso, el mismo patrón de defecto en `V$ASM_DISK` (Fase 4, fuera de alcance — documentado, no corregido aquí).
- **Future version policy**: `config/query-compatibility-matrix.yaml` declaraba `max: latest` en las 7 queries `Q-DG-*`, que el resolver interpreta como techo sin límite (`vernum("latest") = 99999`) — contradiciendo la propia declaración `UNKNOWN_FUTURE` del agente para versiones futuras. Corregido a `max: "23.0"` explícito en las 7. Aclarada la semántica de `latest: SUPPORTED` en `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md`. Corregidas también 3 entradas `role_scope: PHYSICAL_STANDBY` remanentes (fuera del enum) en la misma matriz.
- **`Q-DG-MANAGED-PROCESS-001` modernizada**: de un único statement legacy (`V$MANAGED_STANDBY`) a un modelo de variantes legacy (default, 10.2+)/modern (`V$DATAGUARD_PROCESS`, on-demand, 11.2+), con normalización semántica a un modelo lógico común — sin forzar equivalencia en campos que la vista moderna no expone (`thread`/`sequence` quedan `PARTIALLY_SUPPORTED` en la variante moderna).
- 15 tests nuevos de regresión específicos de este hardening.

### Fixed — PHASE 5 — Data Guard Final Process-View & Portability Hardening

Cierre de 4 defectos finales antes de aprobar `v0.5.0-dataguard`. Ver `docs/PHASE_5_FINAL_PROCESS_VIEW_PORTABILITY_HARDENING.md` para el detalle completo.

- **`V$DATAGUARD_PROCESS` metadata (bug real)**: el hardening anterior declaró `min_version: "11.2"` y columnas `status`/`client_process` — ambos datos incorrectos, verificado contra Oracle Database Reference. Versión real de introducción: **12.2.0.1**. `STATUS`/`CLIENT_PROCESS` no son columnas de esta vista (pertenecen a `V$MANAGED_STANDBY` — confusión entre ambas vistas). Corregido a las columnas reales documentadas (`name`/`pid`/`type`/`role`/`action`/`client_pid`/`client_role`/`thread#`/`sequence#`/`block#`/`block_count`); `V$MANAGED_STANDBY` corregida también (agregadas `thread#`/`client_pid`, documentada su deprecación oficial desde 12.2.0.1).
- **Legacy/modern boundary corregida**: de "legacy default 10.2–23.0 + modern on-demand desde 11.2" a una partición real sin solapamiento — legacy única opción 10.2–12.1, modern única opción 12.2–23.0. `Q-DG-MANAGED-PROCESS-001` v3.0.0.
- **Semantic normalization corregida**: modelo lógico renombrado (`process_name`/`process_role`/`process_action`/`client_pid`/`thread`/`sequence`/`source_view`/`source_variant`) — `thread`/`sequence` pasan de `PARTIALLY_SUPPORTED` (suposición incorrecta del hardening anterior) a soportados en ambas variantes; único campo sin equivalente real es `process_role` en legacy.
- **`latest: SUPPORTED` eliminado estructuralmente** de la fila `dataguard` en `config/capability-matrix.yaml` (no sólo reinterpretado por comentario como en el hardening anterior) — reemplazado por `future_status: COMPATIBILITY_VALIDATION_REQUIRED`. `docs/CAPABILITY_MATRIX.md` actualizado igual.
- **Regresión CRLF corregida**: `compatibility/oracle-dictionary/views.yaml` tenía terminadores de línea CRLF pese a `.gitattributes` ya declarar `eol=lf` — normalizado a LF (contenido sin cambios semánticos). Barrido de todo el repositorio confirmó que era el único archivo afectado.
- **Nuevo test general de portabilidad**: `tests/test_repository_text_files_are_lf.sh` (Python stdlib, escanea *.sh/*.bash/*.py/*.yaml/*.yml/*.json/*.md) + `tests/test_gitattributes_lf_policy.sh`.
- 10 tests nuevos + 6 tests corregidos (no cosméticos — reflejan el rango/columnas reales corregidos).

## [0.4.0-rac-gi-asm-network] — 2026-09-04 — Fase 4: RAC / Grid Infrastructure / ASM / Network

Cuarta capa funcional del e-stack, sobre baseline `v0.3.0-performance`. Ver `docs/PHASE_4_RAC_GI_ASM_NETWORK.md` para el reporte de cierre completo.

### Added

- `agents/oracle-rac-analyst/` (`v2.0.0`), `agents/oracle-asm-storage-analyst/` (`v2.0.0`), `agents/oracle-network-analyst/` (`v2.0.0`) — los 3 reestructurados de manifest plano a contrato estructurado completo (`AGENT.md`/`manifest.yaml`/`routing.yaml`/`context-policy.yaml`/`collaboration.yaml`/`output-schema.yaml`/`tests/`/`CHANGELOG.md`), mismo patrón que `oracle-performance-analyst` v4.0.0. `oracle-rac-analyst` absorbe Grid Infrastructure — sin agente GI separado.
- `agents/os-platform-analyst.md` (`v1.1.0`) — extensión ligera: colaboración con `oracle-rac-analyst`/`oracle-network-analyst` para interconnect OS-level/TCP.
- 57 skills nuevas completamente materializadas: 31 `rac/*` (19 RAC + 12 `gi-*`), 12 `asm/*`, 14 `network/*` — `skills/REGISTRY.md` pasa de 63 a 120 skills `active`.
- `queries/rac/` (`Q-RAC-TOPOLOGY-001` con 2 variantes, `Q-RAC-SERVICES-001`, `Q-RAC-INTERCONNECT-001`, `Q-RAC-GES-GCS-001`) y `queries/asm/` (`Q-ASM-TOPOLOGY-001`, `Q-ASM-DISKS-001`, `Q-ASM-REBALANCE-001`) — 7 queries certificadas nuevas.
- `parsers/rac/` (nuevo, Python 3 stdlib-only) — 8 parsers de salida de collectors GI/Clusterware/ASM/red (`crsctl_resource_parser.py` cubre resources+version+oifcfg, `olsnodes_parser.py`, `srvctl_scan_parser.py`, `srvctl_service_parser.py`, `lsnrctl_status_parser.py`, `ocrcheck_parser.py`, `voting_parser.py`, `asmcmd_lsdg_parser.py`), mismo envelope/disciplina de seguridad que `parsers/performance/` de Fase 3.
- `docs/GI_READONLY_COLLECTORS.md` — Collector Contract completo (16 collectors: 11 GI/Clusterware/ASM + 5 OS network), `docs/RAC_DIAGNOSTIC_MODEL.md`, `docs/ASM_DIAGNOSTIC_MODEL.md`, `docs/ORACLE_NETWORK_DIAGNOSTIC_MODEL.md`, `docs/PHASE_4_RAC_GI_ASM_NETWORK.md` (incluye el Manual Action Contract).
- 15 fixtures de collectors (`tests/fixtures/collectors/`) + 13 fixtures de escenario (11gR2/19c/23ai RAC, service imbalance, SCAN healthy/DNS failure, listener registration issue, TNS timeout, ASM normal/low-capacity/rebalance, interconnect anomaly).
- 9 entradas nuevas de `knowledge/errors/` (`tns/`: TNS-12541/12537/12170/01199; `ora/`: ORA-3136/27300-27301/27501-27530; `crs/`: CRS-4535/4529/4533).
- 68 tests nuevos: 16 collector/parser (incl. prueba viva de prompt-injection), 11 RAC, 8 ASM, 11 Network, 14 seguridad específicos de Fase 4, 8 contrato de agente.
- `EVOLUTION.md` sección 15 — `/change parser` con checklist obligatorio para nuevos tipos de collector/parser.

### Changed

- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — RAC/GI/ASM/Network `PARTIAL/FOUNDATION_ONLY → SUPPORTED` (11gR2–23ai; 10g queda `PLANNED`/`UNSUPPORTED` según corresponda).
- `queries/rac/Q-RAC-SESSION-DIST-001.md` relocalizada desde `queries/` plano (mismo ID, sin duplicar).
- `queries/REGISTRY.md` — corregido un gap pre-existente: `Q-RAC-SERVICE-PLACEMENT-001`/`Q-ASM-DG-USAGE-001`/`Q-ASM-OPERATION-001` (Foundation) nunca tuvieron archivo real pese a figurar "materializadas"; reemplazadas por las 7 queries RAC/ASM genuinamente construidas esta fase.
- `docs/TARGET_PROFILE.md` — schema `2.0.0 → 2.1.0` (aditivo): bloques `rac`/`gi`/`asm`/`network`.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — grants RAC/GI/Network/ASM, separación explícita de 3 identidades (database/GI-OS/ASM).
- `mcp/tool-manifest.md` — 15 tools nuevas; corregidas 2 referencias a queries Foundation nunca materializadas (`get_session_distribution`, `get_asm_usage`, `get_listener_status`).
- `collectors/README.md` — 4 tipos de collector nuevos documentados en la tabla existente, referencia a `docs/GI_READONLY_COLLECTORS.md`.
- `workflows/rac.md` (`v2.0.0`), `workflows/healthcheck.md`/`assessment.md`/`diagnose.md` extendidos con las invocaciones acotadas `/healthcheck rac|asm|network`, `/assessment rac`, escenarios `/diagnose rac|service|scan|listener|interconnect|asm|connection`.
- `.gitattributes`/portabilidad (Fase 3 Completion Hardening) sin cambios — 0 archivos nuevos con CRLF detectados en esta fase.

### Known limitations

Ver `docs/PHASE_4_RAC_GI_ASM_NETWORK.md#known-limitations`. En resumen: parsers `parsers/rac/*.py` primera versión funcional, validados contra fixtures propios, no contra la diversidad completa de formatos `crsctl`/`srvctl` entre versiones GI; TAF/Application Continuity documentados narrativamente sin `skill_id`/query/collector propio; sin collector de latencia de red certificado; gap pre-existente de Multitenant sin cambios (no corresponde a esta fase).

## [0.3.0-performance] — 2026-09-03 — Fase 3: Performance Completion & Portability Hardening

Cierra 4 gaps de Fase 3 sobre el mismo baseline `v0.2.0-oracle-core` — no es un rebuild de Fase 3. Ver `docs/PHASE_3_COMPLETION_HARDENING.md` para el reporte de cierre completo.

### Added

- `parsers/performance/` (nuevo, Python 3 stdlib-only — primer código fuente no Markdown/YAML/Bash del repositorio): `common.py` (envelope `ParsedReport`, `ParseStatus`, `SizeLimitPolicy`, `Sanitizer`), `type_detector.py`, `statspack_parser.py`, `awr_parser.py`, `addm_parser.py`, `execution_plan_parser.py`, `ingest.py` (orquestador único), `__init__.py`.
- Statspack ahora cubre reportes multi-sección completos (Load Profile, Instance Efficiency, Top Wait Events, SQL ordered by CPU/elapsed/executions/gets/reads, Instance Activity, Library Cache, Latch, Enqueue, I/O incl. ASM, Memory/Cache Sizes, Redo/Commit y Parsing derivados) — antes sólo wait events.
- 15 fixtures de reportes (`tests/fixtures/reports/`), incluyendo un intento de prompt injection (`addm-injection-attempt.txt`) usado para probar que el contenido de un reporte nunca se interpreta como instrucción.
- 28 tests nuevos de parsers (detección de tipo ×6, parsers AWR/ADDM/execution-plan ×4, Statspack ×12, seguridad/límites/sanitización ×3, secciones faltantes/malformadas/vacías ×3).
- `agents/oracle-performance-analyst/` materializado en contrato estructurado completo (`v4.0.0`): `manifest.yaml`, `routing.yaml`, `context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml`, `tests/README.md`, `CHANGELOG.md`; `AGENT.md` reescrito como documento narrativo que referencia, nunca duplica, esos campos.
- 7 tests nuevos de contrato de agente (manifest/routing/context-policy/collaboration/output-schema/no-execution-capability/no-delegation-loop).
- `.gitattributes` — fuerza `eol=lf` en `*.sh/*.bash/*.py/*.yaml/*.yml/*.json/*.md`.
- `tests/test_no_crlf_in_shell_scripts.sh` — falla el build si cualquier `*.sh`/`*.bash` contiene CRLF o carece de shebang bash válido.
- `tests/run_all.py` — runner de tests portable en Python 3 (stdlib only), coherente con `tests/run-all.sh`, no lo reemplaza.

### Changed

- `skills/performance/statspack-analysis` (`v2.0.0`) — capability map explícito por sección (`statspack_capabilities:`), 3 patrones de correlación certificados nuevos.
- `skills/performance/awr-analysis` (`v1.1.0`), `skills/performance/addm-analysis` (`v1.1.0`), `skills/performance/execution-plan` (`v1.1.0`) — añadida ruta de ingesta de reporte de archivo vía el parser correspondiente, sin tocar la ruta de query en vivo existente.
- `tests/run-all.sh` — agrega totales (`N/M tests OK`) y lista de nombres de tests fallidos al resumen; preserva el comportamiento existente (no fail-fast, exit code agregado).
- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — Statspack ya no se limita a "sólo wait events"; nota actualizada para reflejar cobertura multi-sección con `capability_status` por sección.
- **Normalización de line endings**: 85 archivos `tests/test_*.sh` pre-existentes (de Foundation Hardening/Fase 2/Oracle Core Compatibility Hardening) contenían CRLF real, no detectado hasta ahora porque el chequeo original carecía de la flag `-U`/`--binary` de grep (en Git Bash/MSYS, grep descarta CR de fin de línea antes de matchear salvo que se le indique explícitamente no hacerlo). Normalizados a LF sin alterar contenido (verificado byte a byte, `diff` vacío tras `tr -d '\r'`).

### Known limitations

- `awr_parser.py` es una primera versión funcional — alineación de columnas numéricas imperfecta en algunas filas de wait events; no cubre todos los formatos históricos de AWR.
- El parser de ejecución de planes requiere la firma exacta `"| Id  | Operation"`; formatos de `DBMS_XPLAN` no tabulares devuelven `UNSUPPORTED_FORMAT` en vez de un intento de mejor esfuerzo.
- Ningún parser genera evidencia desde un reporte que el DBA no haya adjuntado — la ruta de query en vivo sigue siendo la única fuente de evidencia sin insumo externo.

Segunda capa funcional del e-stack, sobre baseline `v0.2.0-oracle-core`. Ver `docs/PHASE_3_ORACLE_PERFORMANCE.md` para el reporte de cierre completo.

### Added

- `agents/oracle-performance-analyst/AGENT.md` (`v3.0.0`) — reestructurado a carpeta profunda; Licensing Gate formalizado, Performance workflow, Correlation model con ejemplos certificados, SQL text policy, Manual command generation (nunca `KILL SESSION`/`ALTER SYSTEM` ejecutado).
- 31 skills `performance/*` completamente materializadas (`SKILL.md` + `manifest.yaml`), incluyendo 3 previamente ni siquiera `registered` (`memory`, `commit-redo`, `trending`).
- `queries/performance/` — 21 queries certificadas (Query Contract v2 + Query Variant Contract), todas `implicit_full_range`, sin discrepancias metadata↔SQL.
- `Q-PERF-WAIT-STATSPACK-001` materializada (antes sólo `registered`) — Statspack como ruta de primera clase, no fallback de segunda categoría.
- 11 fixtures nuevas (`tests/fixtures/{10g-statspack,11g-statspack,12c-awr,19c-standalone-performance,19c-rac-multi-instance,19c-no-diagnostic-pack,19c-blocking,19c-high-cpu,19c-high-io,19c-log-file-sync,23ai-modern-performance}.yaml`).
- 47 tests nuevos: AWR (9), Statspack (5), ruta estándar sin licencia (5), SQL performance (6), memoria (4), concurrencia (4), I/O (3), paralelismo (2), seguridad (8), version-support (1).
- `docs/PHASE_3_ORACLE_PERFORMANCE.md` — reporte de cierre de fase.
- 9 tools MCP nuevas en `mcp/tool-manifest.md` (`get_db_time`, `get_execution_plan`, `get_memory_status`, `get_io_waits`, `get_active_temp_usage`, `get_blocking_sessions`, `get_parallel_sessions`, `get_redo_activity`; `get_top_sql_metrics` materializada de `registered` a `active`).

### Changed

- `Q-PERF-WAIT-AWR-001`/`Q-PERF-WAIT-ASH-001` relocalizadas de `queries/` plano a `queries/performance/waits/` (mismos IDs, sin duplicar).
- `skills/performance/wait-events` reestructurado de `wait-events.md` plano a `wait-events/SKILL.md` + `manifest.yaml` (v2.0.0) — extendido con ruta dinámica sin licencia, no reconstruido.
- `config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — `Performance` `PARTIAL → SUPPORTED`, `Statspack` `FOUNDATION_ONLY → SUPPORTED` (10g–23ai); `AWR`/`ASH`/`ADDM` sin cambio (`LICENSE_DEPENDENT`, no es limitación del e-stack).
- `workflows/analyze.md` extendido con mapeo explícito `performance`/`sql`/`memory`/`io`/`waits` → `oracle-performance-analyst`, sin slash commands nuevos.
- `workflows/awr.md` — gate de versión actualizado (Statspack `FOUNDATION_ONLY → SUPPORTED`).
- `policies/licensing-awareness-policy.md`, `queries/REGISTRY.md` — referencias de ruta actualizadas tras la relocalización de `wait-events`.

### Known limitations

Ver `docs/PHASE_3_ORACLE_PERFORMANCE.md#known-limitations`. En resumen: parser local de AWR HTML/texto externo documentado pero no implementado (evidencia proviene de queries certificadas contra el ambiente vivo, no de parsear un archivo); Statspack cubre sólo wait events (Load Profile/SQL statistics vía Statspack quedan para `/change query` futuro); `V$PQ_SYSSTAT` agregado no materializado; ADDM se interpreta sólo cuando el DBA provee su output, nunca generado por el e-stack.

## [0.1.0] — 2026-09-02 — Fase 1: Foundation

### Added

- Arquitectura, planos del sistema y decisiones de diseño (`ARCHITECTURE.md`).
- Modelo de seguridad, amenazas y controles (`SECURITY.md`).
- Modelo de evolución gobernada `/change` (`EVOLUTION.md`).
- Modelo de distribución y bootstrap (`DISTRIBUTION.md`).
- Agent Contract, Skill Contract, Workflow Contract y Query Contract definitivos (`docs/CONTRACTS.md`).
- Registro completo de 18 agentes obligatorios con manifests conforme al Agent Contract (`agents/`).
- Registro completo del catálogo de skills por dominio (`skills/REGISTRY.md`) con materialización representativa por dominio.
- Catálogo certificado inicial de queries/tools semánticas read-only, extendido más allá de las 14 nombradas explícitamente para cubrir RMAN/backup, security posture y capacity trending (`queries/`).
- Diseño del MCP Diagnostic Gateway local y su tool manifest (`mcp/`).
- Política de sanitización y minimización de datos (`sanitizers/`).
- Políticas de seguridad, identidad, operaciones prohibidas, rate limiting, licensing y retención de evidencia (`policies/`).
- Modelo de evidencia (`raw/sanitized/derived`) y de análisis (`analysis/ANA-*`) con trazabilidad EVD→FND→REC→CHG.
- Modelo de documentación Markdown-first con entregables binarios bajo demanda (`docs/CONTRACTS.md`, `templates/`).
- 13 slash commands implementados en `.claude/commands/`, cada uno resolviendo a un Workflow Contract en `workflows/`.
- Taxonomía inicial de `knowledge/errors/` (ORA/TNS/RMAN/CRS) con entradas representativas validadas.
- Suite de tests de Fase 1: prohibición de escritura, prohibición de shell arbitrario, bloqueo de application data, detección de secretos, trazabilidad de evidencia, activación mínima de agentes, tests adversariales/prompt-injection (`tests/`).
- Scripts de bootstrap de estación de trabajo (`scripts/`).

### Known limitations

Ver reporte de cierre de Fase 1. En resumen: el Gateway MCP, los collectors y los generadores de documentos binarios son contratos/diseño, no runtime ejecutable; eso corresponde a Fases 2–9.

## [0.1.0-foundation] — 2026-09-02 — Foundation Hardening

Pass de endurecimiento sobre el mismo baseline de Fase 1 (no avanza a Fase 2). Ver reporte de cierre "FOUNDATION HARDENING RESULT".

### Added

- **Query Contract v2** (`docs/CONTRACTS.md`, `queries/_QUERY_CONTRACT_TEMPLATE.md`): `container_scope`, `database_role_scope`, `risk_class` (separado de `cost_class`), `cost_class`, `max_output_bytes`, `sanitization_required`, `license_requirements`, `execution_mode: READ_ONLY`.
- `policies/query-cost-policy.md` — clasificación LOW/MEDIUM/HIGH/BLOCKED, distinta de `risk_class`.
- `policies/capability-degradation-policy.md` — modelo formal de 8 estados (`SUPPORTED…ENVIRONMENT_UNKNOWN`) con `reason/impact/alternative/required_action`.
- `policies/version-awareness-policy.md` — representación normalizada de versión (`major/minor/release/ru/raw`) y degradación explícita por versión/arquitectura.
- `docs/CAPABILITY_MATRIX.md` + `config/capability-matrix.yaml` — cobertura por 17 dominios × 8 versiones Oracle.
- `skills/core/version-awareness.md` — materializado (`registered → active`).
- Bloque `gates:` (version/architecture/environment/license/privilege/security/cost/evidence) en el Workflow Contract y en los 13 workflows activos.
- Pipeline `DISCOVERY → CAPABILITY FILTER → AGENT FILTER → SKILL FILTER → CONTEXT PACKAGE` y métricas `agents_skipped_by_capability`/`skills_skipped_by_version`/`skills_skipped_by_license`/`queries_skipped_by_cost`/`tokens_avoided` en `docs/CONTRACTS.md` y `agents/oracle-operations-orchestrator.md`.
- 28 tests nuevos (IDs canónicos, Query Contract v2, cost class, los 8 estados de capability, gates de version/license/workflow, schema y consistencia de la Capability Matrix) — ver `tests/README.md`.

### Changed (breaking)

- **`skill_id` es siempre domain-qualified** (`dominio/skill`). `skills/REGISTRY.md` reescrito con `skill_id` explícito por fila; nombres cortos (`temp`, `undo`, `sga`, `pga`, `services`, `memory`, `io`) dejan de ser identificadores válidos — sólo `display_name`.
- `agents/os-platform-analyst.md` — `Allowed skills` corregido de `os/<skill>` a `os/<platform>/<skill>` para coincidir con el `skill_id` canónico real.
- `queries/REGISTRY.md`, `queries/_QUERY_CONTRACT_TEMPLATE.md` y las 3 queries materializadas migradas a Query Contract v2 (`objects_queried` → `objects_accessed`, `versions` → `supported_oracle_versions`, `platform` → `supported_os`, `architecture` → `supported_architectures`, `risk` → `risk_class` + `cost_class` nuevo).
- `policies/rate-limiting-policy.md` — la clasificación de costo se movió a `policies/query-cost-policy.md`; esta política mantiene sólo los límites por defecto.
- `policies/licensing-awareness-policy.md` — agregada la secuencia de gate explícita y el estado formal `LICENSE_RESTRICTED`.
- `EVOLUTION.md` — nueva sección 13 (`/change compatibility` — validaciones obligatorias); `GAP ANALYSIS`/`IMPACT ANALYSIS`/`TEST` amplían su alcance.
- `tests/test_application_data_blocked.sh`, `tests/test_version_awareness.sh`, `tests/test_query_limits.sh` actualizados a los nuevos nombres de campo.

### Known limitations

Las mismas de Fase 1 (Gateway MCP/collectors/generadores de documentos son contrato, no runtime). Adicional: `test_no_ambiguous_skill_references.sh` es una heurística de grep sobre backticks, no un parser real de Markdown — puede tener falsos negativos ante formatos de referencia no anticipados; se refuerza en Fase 2+ si aparecen casos reales.

## [0.2.0-oracle-core] — 2026-09-03 — Oracle Core Compatibility Hardening

Pasada de endurecimiento sobre `v0.2.0-oracle-core` (branch `phase/2-oracle-core`), previa a aprobar ese baseline — NO una reconstrucción de Fase 2. Ver `docs/PHASE_2_COMPATIBILITY_HARDENING.md` para el reporte de cierre completo.

### Added

- **Query Variant model** (`docs/QUERY_VARIANTS.md`) — separa logical query de physical SQL variant; Query Variant Resolver documentado (Target Profile → variante compatible → SQL certificado); nunca "closest version", nunca fallback silencioso.
- `compatibility/oracle-dictionary/views.yaml` — capa mínima de disponibilidad de vistas/columnas por versión Oracle, usada por el SQL Static Validator.
- `config/query-compatibility-matrix.yaml` — fuente estructurada por logical query (variantes, rango, vistas requeridas, `validation_status`).
- 28 tests nuevos: SQL Static Validator, contrato de variantes (7), Resolver por versión (7 + no-match), regresión específica Identity/RAC/ASM/TEMP/CDB/PDB (10), documentación-vs-realidad, fixture-resolution.
- `compatibility_schema` (`available_views`/`available_columns`) en las 9 fixtures existentes.

### Changed

- `Q-DISC-IDENTITY-001` (v3.0.0), `Q-DISC-RAC-001` (v2.0.0), `Q-ORA-INSTANCE-STATE-001` (v2.0.0), `Q-DBA-TBS-USAGE-001` (v2.0.0) — divididas en variantes reales; ya no declaran soporte de versión sin SQL validado para ese rango.
- `Q-DISC-ASM-001` (v2.0.0) — variante `routine_stat` (`V$ASM_DISKGROUP_STAT`, `cost_class: LOW`, default) separada de `detailed_diskgroup` (`V$ASM_DISKGROUP`, `cost_class: MEDIUM`, on-demand only).
- `Q-ORA-JOBS-SUMMARY-001` + `skills/oracle/jobs/SKILL.md` (v1.1.0) — alcance acotado a `DBMS_SCHEDULER`; gap `DBA_JOBS` legacy documentado `PARTIALLY_SUPPORTED`/`PLANNED`, no un SELECT ficticio.
- `Q-ORA-ARCHIVE-001`, `Q-ORA-CONTROLFILE-001`, `Q-ORA-DB-STATE-001`, `Q-ORA-REDO-001`, `Q-ORA-REDO-SWITCH-FREQ-001`, `Q-PERF-WAIT-AWR-001`, `Q-PERF-WAIT-ASH-001` — `container_scope: CDB_ROOT → ANY_CONTAINER` (CDB_ROOT es exclusivo de Multitenant 12c+, inválido junto a soporte 10g/11g declarado); propagado a `queries/REGISTRY.md`.
- `docs/CONTRACTS.md` — campo opcional `open_mode_scope` en el Query Contract.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — mapping `query_variant → required object privilege`.
- `mcp/tool-manifest.md` — sección "MCP Query Certification" (sólo `CERTIFIED` por target, nunca `NOT_CERTIFIED`/`PARTIAL sin variant`/`UNKNOWN`).
- `EVOLUTION.md` — checklist obligatorio de `/change compatibility` extendido (dictionary delta + variants + matrix + fixtures + tests + skills + docs).
- `config/capability-matrix.yaml` — nota de `oracle-core` extendida (validación real vía Resolver, gap `DBA_JOBS` documentado).

### Fixed

- `tests/test_non_cdb_pdb_unsupported.sh` (Foundation Hardening) — su aserción de que existe una query materializada `container_scope: CDB_ROOT` quedó invalidada por la corrección de arriba; ajustada para validar la existencia del valor de enum en el contrato, no un uso concreto.
- 6 tests de extracción de bloque SQL por variante (`test_identity_*`/`test_rac_*`) tenían un bug de coincidencia de patrón `awk` que capturaba el bloque de metadata del frontmatter en vez del heading real del body.

## [0.2.0-oracle-core] — 2026-09-03 — Fase 2: Oracle Core

Primera capa funcional Oracle del e-stack, sobre baseline `v0.1.0-foundation`. Ver `docs/PHASE_2_ORACLE_CORE.md` para el reporte de cierre completo.

### Added

- **Target Profile** (`docs/TARGET_PROFILE.md`) — schema estructurado de identidad de ambiente (versión normalizada, arquitectura, rol, container, capabilities), publicado una vez por análisis y reutilizado por todo el pipeline.
- `agents/oracle-discovery-analyst/AGENT.md` (`v2.0.0`) — Discovery Sequence de 11 pasos, detección por dimensión, Discovery Cache diferenciado por volatilidad.
- `agents/oracle-dba-analyst/AGENT.md` (`v2.0.0`) — 18 áreas Oracle Core, DBA Command Generation formalizado.
- 18 skills `oracle/*` completamente materializadas (`SKILL.md` + `manifest.yaml`), reemplazando el único ejemplo representativo de Fase 1.
- ~20 queries nuevas `Q-ORA-*` (Query Contract v2) bajo `queries/oracle/<categoría>/`, más 3 queries de discovery/tablespaces previamente sólo-registro ahora materializadas.
- `policies/discovery-cache-policy.md` — TTL diferenciado por volatilidad de campo.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — propuesta de `ESTACK_DIAGNOSTIC_ROLE` para Oracle Core (revisión humana, nunca ejecutado).
- 9 fixtures (`tests/fixtures/*.yaml`) para 10g/11g/12c/19c/21c/23ai × standalone/RAC/CDB/standby.
- 40 tests nuevos: 7 de detección por versión, 18 de skill Oracle Core, 12 de seguridad, 3 de compatibilidad de query.
- 15 nuevas tools MCP semánticas en `mcp/tool-manifest.md` (`get_database_state`, `get_controlfile_metadata`, etc.).

### Changed

- `agents/oracle-discovery-analyst.md` y `agents/oracle-dba-analyst.md` → reestructurados a `agents/<id>/AGENT.md` (extensión aditiva; el resto de agentes permanece plano).
- `skills/oracle/tablespaces.md` → `skills/oracle/tablespaces/SKILL.md` + `manifest.yaml`, extendido de v1.0.0 a v2.0.0.
- `config/capability-matrix.yaml` / `docs/CAPABILITY_MATRIX.md`: fila `oracle-core` de `PARTIAL` a `SUPPORTED` en las 8 columnas de versión.
- `workflows/healthcheck.md` → `v2.0.0`, cobertura ampliada a las 18 áreas Oracle Core.
- `skills/core/context-discovery.md` → `v1.1.0`, nota de supersesión de nomenclatura por el Target Profile (sin romper Foundation).
- Tests de Foundation/Hardening que escaneaban `queries/*.md` de forma plana actualizados para recorrer `queries/oracle/**` recursivamente.

### Known limitations

Ver `docs/PHASE_2_ORACLE_CORE.md#known-limitations`. En resumen: Gateway MCP/collectors/generadores de documentos siguen siendo contrato, no runtime; multi-PDB individual no iterado automáticamente; RAC One Node no confirmable sin query adicional; tests estáticos/basados en fixtures, no contra ambiente real.
