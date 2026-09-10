# Phase 6 — Oracle Multitenant / CDB / PDB

Branch: `phase/6-multitenant`. Baseline: `v0.5.0-dataguard`. Objetivo del baseline resultante: `v0.6.0-multitenant`.

**Nota (superado parcialmente)**: 3 defectos de certificación detectados post-construcción (`CDB_PDB_SAVED_STATES` no es una vista real; `V$RSRCPDBMETRIC` declarada disponible desde 12.1 cuando en realidad es 12.2.0.1+; `PDB_PLUG_IN_VIOLATIONS.CON_ID` declarado disponible desde 12.1 cuando en realidad es 12.2+) fueron corregidos en un hardening posterior sobre esta misma rama — ver `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`. Un hardening final adicional corrigió la semántica incorrecta de `PDB_PLUG_IN_VIOLATIONS.NAME` (identidad de PDB, no "violación/componente") y creó `scripts/lib/version.sh` (patch-level-aware, aún acotada a un subconjunto de tests) — ver `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md`. Un cuarto hardening de consolidación migró los ~17 tests de resolución de variantes restantes que todavía reimplementaban comparación de versión localmente, y endureció el enforcement global — ver `docs/PHASE_6_VERSION_RESOLVER_CONSOLIDATION_FINALIZATION.md`. Las secciones de este documento (query catalog, dictionary, capability matrix) reflejan el estado ya corregido por los cuatro hardenings.

## Scope

Capa especializada de diagnóstico Multitenant/CDB/PDB: arquitectura CDB/NON-CDB, inventario y estado de PDBs, servicios y colocación RAC, sesiones, storage/temp/undo por PDB, scope y drift de parámetros, identidad común vs. local (visibilidad), salud de componentes por contenedor, violaciones de plug-in (`PDB_PLUG_IN_VIOLATIONS`), uso de recursos y Resource Manager (visibilidad), lockdown profiles (visibilidad), Application Containers/Proxy PDB (topología) — nunca ejecutando ninguna operación de ciclo de vida de PDB, ni cambio de parámetro/Resource Manager/lockdown profile/usuario. No reconstruye Foundation/Oracle Core/Performance/RAC-GI-ASM-Network/Data Guard, no avanza a RMAN/Backup-Recovery/Security profundos, no implementa auto-remediation, no introduce un Execution Plane.

## Multitenant Agent

`agents/oracle-multitenant-analyst/` (v2.0.0) — materializado en contrato estructurado completo, mismo patrón que `oracle-rac-analyst`/`oracle-asm-storage-analyst`/`oracle-network-analyst`/`oracle-dataguard-analyst`.

## Multitenant Skills

26 skills materializados: `architecture, cdb-discovery, pdb-inventory, pdb-state, pdb-open-mode, pdb-services, pdb-rac-placement, pdb-sessions, pdb-tablespaces, pdb-temp, pdb-undo, local-undo, parameters, common-local-users, common-local-roles, components, plugin-violations, resource-usage, resource-manager, lockdown-profiles, application-containers, proxy-pdb, configuration-drift, healthcheck, assessment, troubleshooting`. Reconciliación de la lista Foundation de 12 skills documentada en `skills/REGISTRY.md#multitenant`.

## Query catalog

`queries/multitenant/` — 15 queries: `Q-CDB-PDB-STATE-001`, `Q-CDB-CONTAINERS-001`, `Q-CDB-PDB-SAVED-STATE-001`, `Q-CDB-SERVICES-001`, `Q-CDB-SESSION-DIST-001`, `Q-CDB-TABLESPACES-001`, `Q-CDB-TEMP-001`, `Q-CDB-PARAMETERS-001`, `Q-CDB-USERS-001`, `Q-CDB-ROLES-001`, `Q-CDB-COMPONENTS-001`, `Q-CDB-PLUGIN-VIOLATIONS-001`, `Q-CDB-RESOURCE-USAGE-001`, `Q-CDB-RESOURCE-MANAGER-001`, `Q-CDB-LOCKDOWN-001`. Corrección de un gap pre-existente: `Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001` (Foundation) figuraban "materializadas" en `queries/REGISTRY.md` sin archivo `.md` real ni `container_scope` correcto — mismo patrón detectado y corregido en Fase 4 (RAC/ASM) y Fase 5 (Data Guard). Ver `docs/CDB_PDB_QUERY_MODEL.md`.

## Query variants

Tres queries tienen Query Variant Contract real: `Q-CDB-PDB-STATE-001` (V1 12.1 sin `application_root/application_pdb/application_seed/proxy_pdb/local_undo` — columnas 12.2+-only; V2 12.2–23.0 con esas 5 columnas); `Q-CDB-PDB-SAVED-STATE-001` (una sola variante, min patch-level `12.1.0.2`, corregido en `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md` — no existe en 12.1.0.0/12.1.0.1); `Q-CDB-PLUGIN-VIOLATIONS-001` (V1 legacy 12.1 sin `CON_ID`; V2 modern 12.2–23.0 con `CON_ID`, también corregido en ese mismo hardening). Las 12 queries restantes son `implicit_full_range` (`max` explícito `"23.0"` — nunca `"latest"`, mismo criterio que Compatibility Hardening de Fase 2/5); `Q-CDB-RESOURCE-USAGE-001` corregida de `min: "12.1"` a `min: "12.2"` en el mismo hardening (`V$RSRCPDBMETRIC` no existe en 12.1).

## NON-CDB handling

`# 6` del prompt: sobre un target NON-CDB o 10g/11g, `oracle-multitenant-analyst` nunca se activa — el Capability Filter lo excluye antes del Agent Filter. `MULTITENANT_STATUS: NOT_APPLICABLE` se publica directamente por `oracle-discovery-analyst` desde `target_profile.architecture.multitenant_mode`/`target_profile.multitenant.cdb`, ya publicado en el Target Profile (schema 2.3.0). 10g/11g mapean a `NOT_APPLICABLE`, no `KNOWN_UNSUPPORTED` (la categoría de feature no existe ahí, no es un límite del e-stack).

## CDB detection

`# 7`: nunca reimplementa la detección de `V$DATABASE.CDB` — reutiliza `Q-DISC-IDENTITY-001` (Oracle Core, Fase 2), que ya expone `d.cdb` en sus variantes V2/V3 (12.1+), nunca en V1 (10.2–11.2). Ver `docs/MULTITENANT_DIAGNOSTIC_MODEL.md#cdb-detection`.

## Container scope contract

`# 9`: toda query Multitenant declara `container_scope: CDB_ROOT_ONLY|PDB_ONLY|ANY_CONTAINER|NON_CDB_ONLY|NOT_APPLICABLE`. La presencia de `CON_ID` en una vista nunca implica por sí sola que la ejecución cruzando contenedores sea segura.

## PDB inventory

`multitenant/pdb-inventory` — inventario estructurado (`con_id`, `pdb_token`, `open_mode`, `restricted`, `save_state_visible`, `open_time`, `total_size_bytes`, `recovery_status`) vía `Q-CDB-PDB-STATE-001`. Large CDB support: resumen → detección de anomalías → análisis profundo sólo para PDBs afectadas, nunca inventario completo detallado por defecto (`# 49`, `# 50`).

## PDB state / open mode

`multitenant/pdb-state`, `multitenant/pdb-open-mode` — clasificación `MOUNTED|READ WRITE|READ ONLY|MIGRATE|UNKNOWN`. `MOUNTED` explícitamente **no** es un error por sí mismo — se evalúa contra ventanas de mantenimiento/intención declaradas antes de clasificar como anomalía (`# 11`).

## Save state awareness

`multitenant/pdb-state` expone visibilidad de `CDB_PDB_SAVED_STATES` (`Q-CDB-PDB-SAVED-STATE-001`) sin ejecutar `SAVE STATE`/`DISCARD STATE` jamás (`# 12`).

## PDB services

`multitenant/pdb-services` — extiende el patrón certificado de Fase 4 (`Q-RAC-SERVICES-001`) con `con_id` (`Q-CDB-SERVICES-001`), correlacionando `GV$SERVICES`/`GV$ACTIVE_SERVICES` por PDB.

## PDB RAC placement

`multitenant/pdb-rac-placement` — distingue colocación configurada/apertura real/diseño de servicio. Nunca asume que una PDB debe estar abierta en todas las instancias — correlaciona con el diseño de servicios antes de reportar `MISMATCH` (`# 13`). Clasificación: `MATCHES_DESIGN|PARTIAL|MISMATCH|INSUFFICIENT_EVIDENCE`.

## PDB sessions

`multitenant/pdb-sessions` — extiende `Q-RAC-SESSION-DIST-001` con `con_id` (`Q-CDB-SESSION-DIST-001`), desglose activo/inactivo por PDB.

## PDB storage / temp / undo

`multitenant/pdb-tablespaces`, `multitenant/pdb-temp`, `multitenant/pdb-undo` — `Q-CDB-TABLESPACES-001`/`Q-CDB-TEMP-001` correlacionan `CDB_TABLESPACE_USAGE_METRICS`/`CDB_TABLESPACES`/`CDB_DATA_FILES`/`CDB_TEMP_FILES`/`GV$TEMP_SPACE_HEADER`. Nunca mezcla capacidad física ASM subyacente con capacidad lógica de la PDB (`# 16`) — presión de storage con origen ASM sospechado se delega a `oracle-asm-storage-analyst`, nunca inferida directamente.

## Local Undo

`multitenant/local-undo` — Local Undo **no existe** en 12.1 (introducido en 12.2). `V$PDBS.LOCAL_UNDO` sólo se consulta en la variante V2 de `Q-CDB-PDB-STATE-001` (12.2+); en 12.1, `undo_mode = SHARED` por definición de versión, nunca por adivinanza (`# 19`, `# 20`).

## Parameters / drift

`multitenant/parameters` — distingue scope `inherited/pdb_override/instance_specific` vía `GV$SYSTEM_PARAMETER` (`Q-CDB-PARAMETERS-001`). Drift clasificado `EXPECTED_DIFFERENCE|UNEXPECTED_DIFFERENCE|INSUFFICIENT_CONTEXT` — una diferencia nunca es automáticamente "drift incorrecto" (`# 21`, `# 22`).

## Common vs. local identity

`multitenant/common-local-users`, `multitenant/common-local-roles` — `CDB_USERS.COMMON`/`CDB_ROLES.COMMON` (`Q-CDB-USERS-001`/`Q-CDB-ROLES-001`) es la única fuente de verdad, nunca inferido por convención de nombre (`# 23`). Sólo visibilidad/assessment — nunca password hashes, nunca DDL, nunca se convierte en deep assessment de Security.

## Components

`multitenant/components` — salud de componentes por contenedor vía `CDB_REGISTRY` (`Q-CDB-COMPONENTS-001`), nunca agregado a un único estado CDB-wide sin desglose por `con_id`.

## Plug-in violations

`multitenant/plugin-violations` — `PDB_PLUG_IN_VIOLATIONS` (`Q-CDB-PLUGIN-VIOLATIONS-001`) tiene dos señales de identidad de PDB: `CON_ID` (12.2+ únicamente) y **`NAME`** (*"the name of an existing PDB or a PDB intended to be created"*, verificado vía WebFetch contra Oracle Database Reference 12.1/19c, disponible en todo el rango 12.1–23ai — corrección de PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING sobre una afirmación incorrecta previa). En 12.1, `container_name`/`pdb_token` se derivan de `NAME` (`container_id` sigue `NOT_AVAILABLE`, sin `con_id` no hay correlación por contenedor); en 12.2+ se correlacionan `CON_ID`+`NAME`, publicando `IDENTITY_MISMATCH` si no coinciden — nunca un JOIN SQL directo contra el inventario. `MESSAGE`/`ACTION` siempre tratados como **DATA inerte**, sanitizados, nunca ejecutados como instrucción — defensa explícita contra prompt injection (`# 26`, `# 27`, `# 48`). Clasificación: `WARNING|ERROR|PENDING|RESOLVED|UNKNOWN`.

## Application Containers / Proxy PDB

`multitenant/application-containers`, `multitenant/proxy-pdb` — topología vía `V$PDBS.APPLICATION_ROOT/APPLICATION_PDB/APPLICATION_SEED/PROXY_PDB` (12.2+, verificado real). `capability_status: PARTIALLY_SUPPORTED` cuando el detalle completo no está certificado (`# 28`, `# 29`). Proxy PDB nunca abre conexiones remotas ni almacena connect strings.

## Resource usage / Resource Manager

`multitenant/resource-usage` — `V$RSRCPDBMETRIC` (`Q-CDB-RESOURCE-USAGE-001`, 17 columnas verificadas). `multitenant/resource-manager` — `DBA_CDB_RSRC_PLAN_DIRECTIVES` (`Q-CDB-RESOURCE-MANAGER-001`); corrección de un nombre de vista incorrecto en el prompt original (sección 8 sugería `CDB_RSRC_PLAN_DIRECTIVES`, que no existe — verificado vía WebFetch antes de escribir cualquier metadata, evitando repetir el error de `V$DATAGUARD_PROCESS` de Fase 5). Ambos son sólo visibilidad — ningún cambio de plan/directiva ejecutado.

## Lockdown profiles

`multitenant/lockdown-profiles` — `CDB_LOCKDOWN_PROFILES` (`Q-CDB-LOCKDOWN-001`, 12.2+, 7 columnas verificadas). Sólo visibilidad — ninguna modificación de perfil ejecutada.

## Configuration drift

`multitenant/configuration-drift` — orquestador puro, sin `query_id` propio, reutiliza evidencia de `parameters`/`components`/`lockdown-profiles` ya recolectada, nunca re-consulta.

## Correlation model

- **ASM/Storage** (`# 16`): presión de storage con origen ASM sospechado → delega a `oracle-asm-storage-analyst`, nunca inferido directamente.
- **RAC** (`# 13`): colocación de PDB en instancias/servicios → delega a `oracle-rac-analyst` cuando el target es RAC, nunca activado por defecto en standalone.
- **Data Guard**: contexto CDB/PDB en un target Data Guard → recibido desde `oracle-dataguard-analyst` (`receives_from`), nunca activado por defecto sin ese contexto.
- **Performance**: presión de recursos/sesiones con impacto en DB Time → delega a `oracle-performance-analyst`.
- **Security profundo**: identidad común/local es sólo visibilidad — cualquier análisis de Security profundo está fuera de alcance de esta fase.

## Large CDB support

`# 49`, `# 50`: resumen CDB → detección de anomalías → análisis profundo sólo para las PDBs afectadas. Nunca inventario completo de PDBs ni análisis profundo por-PDB por defecto en un CDB grande.

## Healthcheck Multitenant

`multitenant/healthcheck` — orquestador puro. Ver `docs/PDB_HEALTHCHECK_MODEL.md` para el CDB Health Model (10 dimensiones) y el PDB Health Model (10 dimensiones por PDB) — nunca un score único opaco (`# 39`).

## Assessment Multitenant

`multitenant/assessment` — orquestador puro, reutiliza evidencia ya recolectada por los skills de detalle.

## Diagnose workflows

`workflows/diagnose.md` extendido con escenarios `cdb/pdb/pdb-open-state/pdb-service/pdb-temp/pdb-undo/plugin-violation/pdb-resource/pdb-rac-placement` → `multitenant/troubleshooting`.

## Evidence model

Mismo modelo `RAW DATA → PARSER LOCAL → FILTER → AGGREGATION → REDACTION/TOKENIZATION → SANITIZED EVIDENCE → MODELO` de fases anteriores. `MESSAGE`/`ACTION` de `PDB_PLUG_IN_VIOLATIONS` sanitizados explícitamente antes de llegar al modelo.

## Sanitization

Ningún dato de aplicación, ningún bind value, ningún password hash (`CDB_USERS`) enviado al modelo — sólo el flag `COMMON`/`ORACLE_MAINTAINED`.

## Token/context optimization

`context-policy.yaml`: `top_n` (pdb_inventory_default: 20, sessions_default: 20, plugin_violations_default: 20), sin inventario completo por defecto en CDBs grandes, sin datos de aplicación.

## Capability Matrix

`config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` fila `multitenant`: `SUPPORTED` 12.1–23ai, `future_status: COMPATIBILITY_VALIDATION_REQUIRED` (mismo criterio que Data Guard Fase 5 — columna `latest` eliminada). `UNSUPPORTED` en 10g/11g (feature no existe).

## Documentation

6 documentos nuevos: este documento, `docs/MULTITENANT_DIAGNOSTIC_MODEL.md`, `docs/CDB_PDB_QUERY_MODEL.md`, `docs/MULTITENANT_READONLY_PRIVILEGES.md`, `docs/PDB_HEALTHCHECK_MODEL.md`, `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md` (hardening posterior sobre esta misma rama).

## Security validation

Todos los tests de fases anteriores siguen pasando sin modificación de su lógica. Nuevos (construcción base): 14 tests de query/inventario, 7 de versión, 4 RAC, 5 de plug-in violations, 4 de recursos (34 — sección 57-61 del prompt), 15 tests de seguridad específicos de Fase 6 (`# 62`: no create/drop/clone/unplug/plug PDB, no open/close execution, no save state execution, no alter session container si prohibido, no common/local user create, no lockdown profile modify, no resource manager modify, no parameter change, queries SELECT-only), 4 de contrato de agente — 53 tests, todos `PASS` tras corregir varios falsos positivos de grep-phrasing. Nuevos (hardening de compatibilidad, `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`): 21 tests adicionales de compatibilidad/certificación de diccionario. Nuevos (hardening final, `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md`): 13 tests nuevos de identidad de PDB/librería de versión compartida + 4 refactorizados sin cambio de comportamiento. Nuevos (consolidación de resolver, `docs/PHASE_6_VERSION_RESOLVER_CONSOLIDATION_FINALIZATION.md`): 2 tests nuevos de enforcement global (`test_no_local_version_resolvers_in_tests.sh`, `test_shared_version_library_exists.sh`) + 17 archivos migrados a `scripts/lib/version.sh` sin cambio de comportamiento (1 hallazgo real corregido: `Q-CDB-PDB-SAVED-STATE-001` en `test_query_variant_resolver_12c.sh`) — 93 tests nuevos en total, todos `PASS`.

## Test results

93 tests nuevos (53 construcción base + 21 hardening de compatibilidad + 17 hardening final + 2 consolidación de resolver), todos `PASS`. Ver desglose por categoría arriba, en `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md#7-tests-21-nuevos`, `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md#13-tests-17-nuevosrefactorizados` y `docs/PHASE_6_VERSION_RESOLVER_CONSOLIDATION_FINALIZATION.md`.

## Regression results

Ver el reporte de cierre final para el resultado agregado de `tests/run-all.sh` sobre el árbol completo (Foundation → Fase 6), ejecutado después de la construcción completa de esta fase y de su hardening de compatibilidad.

## Known limitations

- `Application Containers`/`Proxy PDB` reconocidos por topología (`V$PDBS`) pero sin análisis profundo de lifecycle — `PARTIALLY_SUPPORTED`, candidatos a `/change query`/`/change skill` en una fase futura si se requiere certificación completa.
- 8 vistas `CDB_*` mirror estándar (`CDB_TABLESPACE_USAGE_METRICS`, `CDB_TABLESPACES`, `CDB_DATA_FILES`, `CDB_TEMP_FILES`, `GV$TEMP_SPACE_HEADER`, `GV$SYSTEM_PARAMETER`, `CDB_USERS`, `CDB_ROLES`) registradas sin `columns_exhaustive: true` — permisivas para el SQL Static Validator, reflejando honestamente menor confianza de verificación que las 7 vistas WebFetch-verificadas (`V$PDBS`, `V$CONTAINERS`, `DBA_PDB_SAVED_STATES`, `PDB_PLUG_IN_VIOLATIONS`, `V$RSRCPDBMETRIC`, `DBA_CDB_RSRC_PLAN_DIRECTIVES`, `CDB_LOCKDOWN_PROFILES`).
- No se implementan errores ORA-650xx/651xx específicos de Multitenant en `knowledge/errors/` (`# 44` es explícitamente opcional, "no inventar códigos") — se documenta como limitación conocida en vez de fingir soporte.
- No se implementa RMAN profundo ni Security profundo — fuera de alcance explícito de esta fase.
- (Hardening) el chequeo view/column-level `min_version` del SQL Static Validator sólo cubre las 7 vistas Multitenant `columns_exhaustive: true` — no extendido retroactivamente a fases anteriores pese al mismo patrón de defecto conocido en `V$ASM_DISK` (Fase 4) y `V$DATAGUARD_PROCESS` (Fase 5). Ver `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md#8-known-limitations`.

## NOT_CERTIFIED queries

Ninguna — las 15 queries del catálogo están certificadas y materializadas.

## NOT_CERTIFIED collectors

No aplica — Fase 6 no introduce collectors OS/shell nuevos (a diferencia de Fase 4/5), todas las evidencias son SQL de sólo lectura vía las queries certificadas de arriba.

## Manual Action Contract

Toda recomendación de `oracle-multitenant-analyst` que implique un comando ejecutable (`ALTER PLUGGABLE DATABASE`, `ALTER SYSTEM SET RESOURCE_MANAGER_PLAN`, `ALTER LOCKDOWN PROFILE`, `CREATE/ALTER/DROP USER`, etc.) usa el siguiente esquema:

```yaml
manual_action:
  action_id: string
  purpose: string
  owner_role: string           # DBA
  command: string
  prechecks: [string]
  expected_result: string
  risk: string
  rollback: string
  postchecks: [string]
  execution_status: NOT_EXECUTED   # nunca EXECUTED
```

Presentado siempre con las etiquetas `MANUAL DBA ACTION` / `NOT EXECUTED` visibles. Ningún agente de esta fase ejecuta el comando — sólo lo genera como texto para revisión y ejecución humana.

## Next phase

Fase 7+ — según el orden de `README.md` (RMAN/Backup-Recovery profundo, Security profundo). Explícitamente fuera de alcance de esta fase.
