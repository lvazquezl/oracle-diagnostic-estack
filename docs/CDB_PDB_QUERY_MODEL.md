# CDB/PDB Query Model — Fase 6

Vista legible del catálogo `queries/multitenant/` — fuente de verdad es cada archivo `.md` individual (`queries/REGISTRY.md`).

**Nota (superado parcialmente)**: la tabla y las secciones de este documento reflejan el estado ya corregido por `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md` — `Q-CDB-PDB-SAVED-STATE-001` usa `DBA_PDB_SAVED_STATES` (no `CDB_PDB_SAVED_STATES`, que no es una vista real), `Q-CDB-RESOURCE-USAGE-001` cubre 12.2–23.0 (no 12.1), y `Q-CDB-PLUGIN-VIOLATIONS-001` tiene dos variantes reales (legacy 12.1 sin `CON_ID` / modern 12.2+ con `CON_ID`).

## Catálogo

| query_id | vista(s) | dominio de uso | container_scope |
|---|---|---|---|
| `Q-CDB-PDB-STATE-001` | `V$PDBS` | `pdb-inventory`, `pdb-state`, `pdb-open-mode`, `local-undo`, `application-containers`, `proxy-pdb` | `CDB_ROOT_ONLY` |
| `Q-CDB-CONTAINERS-001` | `V$CONTAINERS` | `cdb-discovery`, `architecture` | `CDB_ROOT_ONLY` |
| `Q-CDB-PDB-SAVED-STATE-001` | `DBA_PDB_SAVED_STATES` (12.1.0.2+) | `pdb-state` (save state visibility) | `CDB_ROOT_ONLY` |
| `Q-CDB-SERVICES-001` | `GV$SERVICES`, `GV$ACTIVE_SERVICES` | `pdb-services`, `pdb-rac-placement` | `CDB_ROOT_ONLY` |
| `Q-CDB-SESSION-DIST-001` | `GV$SESSION` | `pdb-sessions` | `CDB_ROOT_ONLY` |
| `Q-CDB-TABLESPACES-001` | `CDB_TABLESPACE_USAGE_METRICS`, `CDB_TABLESPACES`, `CDB_DATA_FILES` | `pdb-tablespaces` | `CDB_ROOT_ONLY` |
| `Q-CDB-TEMP-001` | `CDB_TEMP_FILES`, `GV$TEMP_SPACE_HEADER` | `pdb-temp` | `CDB_ROOT_ONLY` |
| `Q-CDB-PARAMETERS-001` | `GV$SYSTEM_PARAMETER` | `parameters`, `configuration-drift` | `CDB_ROOT_ONLY` |
| `Q-CDB-USERS-001` | `CDB_USERS` | `common-local-users` | `CDB_ROOT_ONLY` |
| `Q-CDB-ROLES-001` | `CDB_ROLES` | `common-local-roles` | `CDB_ROOT_ONLY` |
| `Q-CDB-COMPONENTS-001` | `CDB_REGISTRY` | `components` | `CDB_ROOT_ONLY` |
| `Q-CDB-PLUGIN-VIOLATIONS-001` | `PDB_PLUG_IN_VIOLATIONS` (2 variantes: legacy 12.1 sin `CON_ID` / modern 12.2+ con `CON_ID`) | `plugin-violations` | `CDB_ROOT_ONLY` |
| `Q-CDB-RESOURCE-USAGE-001` | `V$RSRCPDBMETRIC` (12.2+; 12.1: `PARTIALLY_SUPPORTED`) | `resource-usage` | `CDB_ROOT_ONLY` |
| `Q-CDB-RESOURCE-MANAGER-001` | `DBA_CDB_RSRC_PLAN_DIRECTIVES` | `resource-manager` | `CDB_ROOT_ONLY` |
| `Q-CDB-LOCKDOWN-001` | `CDB_LOCKDOWN_PROFILES` | `lockdown-profiles` | `CDB_ROOT_ONLY` |

## Principios (`# 8`, `# 9` del prompt de Fase 6)

Toda query reutiliza el mismo modelo establecido en fases anteriores: Logical Query ID, Query Variant Contract, Query Variant Resolver, Oracle Dictionary Compatibility Model, SQL Static Validator, `container_scope` (columna dedicada, obligatoria en Multitenant — extiende el modelo `database_role_scope` de Data Guard), `cost_class`, `validation_status`. Ninguna query es de rango único fabricado sin verificación — las 7 vistas con `columns_exhaustive: true` (`V$PDBS`, `V$CONTAINERS`, `DBA_PDB_SAVED_STATES`, `PDB_PLUG_IN_VIOLATIONS`, `V$RSRCPDBMETRIC`, `DBA_CDB_RSRC_PLAN_DIRECTIVES`, `CDB_LOCKDOWN_PROFILES`) fueron verificadas vía WebFetch contra Oracle Database Reference antes de escribir SQL o metadata.

## Query Variant Contract real: 3 queries

`Q-CDB-PDB-STATE-001` (V1 12.1 sin `application_root/application_pdb/application_seed/proxy_pdb/local_undo` — no existen en 12.1; V2 12.2–23.0 con esas 5 columnas — mismo precedente que `Q-DG-MANAGED-PROCESS-001`, Fase 5, legacy/modern); `Q-CDB-PDB-SAVED-STATE-001` (una variante, min patch-level `12.1.0.2` — corregido en `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`, no existe en 12.1.0.0/12.1.0.1); `Q-CDB-PLUGIN-VIOLATIONS-001` (V1 legacy 12.1 sin `CON_ID`; V2 modern 12.2–23.0 con `CON_ID` — corregido en el mismo hardening, `CON_ID` no existe en la referencia 12.1). Las 12 queries restantes son `implicit_full_range` con `max: "23.0"` explícito — nunca `"latest"` (lección directamente heredada de Compatibility Hardening de Fase 2/5, donde `vernum("latest")` resolvía a un techo no acotado); `Q-CDB-RESOURCE-USAGE-001` corregida a `min: "12.2"` en el mismo hardening (`V$RSRCPDBMETRIC` no existe en 12.1).

## Corrección de nombre de vista (`# 8` del prompt)

El prompt de Fase 6 usó `CDB_RSRC_PLAN_DIRECTIVES` como ejemplo de vista de Resource Manager — esa vista **no existe**. La vista real, verificada vía WebFetch, es `DBA_CDB_RSRC_PLAN_DIRECTIVES` (columnas `PLAN`, `PLUGGABLE_DATABASE`, `SHARES`, `UTILIZATION_LIMIT`, `PARALLEL_SERVER_LIMIT`). `Q-CDB-RESOURCE-MANAGER-001.md` documenta explícitamente esta corrección en su frontmatter — mismo criterio de verificación independiente que evitó repetir el error de `V$DATAGUARD_PROCESS` (Fase 5 Final Process-View Hardening).

## Identidad de PDB en `PDB_PLUG_IN_VIOLATIONS` — CON_ID y NAME

`PDB_PLUG_IN_VIOLATIONS` tiene `CON_ID` sólo en la variante modern (12.2+; ausente en la variante legacy 12.1 — ver `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md#3-pdb_plug_in_violationscon_id-fix`), pero **sí tiene** una columna de identidad de PDB propia en ambas variantes: `NAME` (*"the name of an existing PDB or a PDB intended to be created"*, verificado vía WebFetch contra Oracle Database Reference 12.1/19c — corrección de PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING sobre una afirmación previa incorrecta de este mismo documento). `Q-CDB-PLUGIN-VIOLATIONS-001` documenta que en la variante legacy `container_name`/`pdb_token` se derivan de `NAME` (sanitizada) — `container_id` sigue `NOT_AVAILABLE` (sin `CON_ID` no hay correlación por contenedor); en la variante moderna se correlacionan `CON_ID` (contra el inventario ya publicado por `Q-CDB-PDB-STATE-001`) y `NAME`, publicando `IDENTITY_MISMATCH` si no coinciden — nunca ocultando la inconsistencia.

## Gap pre-existente corregido

`Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001` figuraban "materializadas" en `queries/REGISTRY.md` desde Foundation sin archivo `.md` real ni `container_scope` correcto (`CDB_ROOT` en vez de `CDB_ROOT_ONLY`) — mismo patrón detectado y corregido en Fase 4 (RAC/ASM) y Fase 5 (Data Guard). Corregido en esta fase: ambas ahora tienen archivo real bajo `queries/multitenant/`, mismos IDs, `container_scope` corregido, sin duplicar.

## Referencia

`queries/REGISTRY.md`, `config/query-compatibility-matrix.yaml`, `compatibility/oracle-dictionary/views.yaml` (sección Fase 6), `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md` (3 correcciones de certificación post-construcción).
