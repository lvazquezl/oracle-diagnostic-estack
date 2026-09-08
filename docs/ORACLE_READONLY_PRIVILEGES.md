# Oracle Read-Only Privileges — `ESTACK_DIAGNOSTIC_ROLE` (Fase 2, extendido en Fase 4/5)

Este documento es **propuesta para revisión humana** — no se ejecuta automáticamente. El e-stack nunca crea usuarios/roles ni otorga privilegios (ver `policies/forbidden-operations.md`). El DBA revisa este documento y decide qué otorgar, cuándo y a quién.

## Principio

Mínimo privilegio suficiente para el catálogo certificado de Fase 2 (`queries/oracle/*`, `queries/oracle/discovery/*`). Nunca `SELECT ANY TABLE`, `DBA`, `SYSDBA`, `SYSOPER`, `SYSASM` por defecto — se evalúan explícitamente y se descartan salvo justificación excepcional documentada aparte.

## Required privileges (mínimo para Oracle Core + Discovery)

```sql
-- Vistas de diccionario/dinámicas usadas por el catálogo de Fase 2 (discovery + oracle/*)
GRANT SELECT ON V_$INSTANCE            TO estack_diagnostic_role;
GRANT SELECT ON GV_$INSTANCE           TO estack_diagnostic_role;
GRANT SELECT ON V_$DATABASE            TO estack_diagnostic_role;
GRANT SELECT ON V_$ACTIVE_INSTANCES    TO estack_diagnostic_role;
GRANT SELECT ON V_$ASM_DISKGROUP       TO estack_diagnostic_role;   -- si la instancia tiene acceso a ASM
GRANT SELECT ON V_$PARAMETER           TO estack_diagnostic_role;
GRANT SELECT ON GV_$PARAMETER          TO estack_diagnostic_role;
GRANT SELECT ON V_$SPPARAMETER         TO estack_diagnostic_role;
GRANT SELECT ON V_$CONTROLFILE         TO estack_diagnostic_role;
GRANT SELECT ON V_$CONTROLFILE_RECORD_SECTION TO estack_diagnostic_role;
GRANT SELECT ON V_$LOG                 TO estack_diagnostic_role;
GRANT SELECT ON V_$LOGFILE             TO estack_diagnostic_role;
GRANT SELECT ON V_$LOG_HISTORY         TO estack_diagnostic_role;
GRANT SELECT ON V_$ARCHIVE_DEST        TO estack_diagnostic_role;
GRANT SELECT ON V_$ARCHIVE_DEST_STATUS TO estack_diagnostic_role;
GRANT SELECT ON V_$ARCHIVED_LOG        TO estack_diagnostic_role;
GRANT SELECT ON V_$UNDOSTAT            TO estack_diagnostic_role;
GRANT SELECT ON V_$SESSION             TO estack_diagnostic_role;
GRANT SELECT ON V_$PROCESS             TO estack_diagnostic_role;
GRANT SELECT ON V_$RESOURCE_LIMIT      TO estack_diagnostic_role;
GRANT SELECT ON V_$DIAG_INFO           TO estack_diagnostic_role;   -- 11g+

GRANT SELECT ON DBA_TABLESPACES              TO estack_diagnostic_role;
GRANT SELECT ON DBA_DATA_FILES               TO estack_diagnostic_role;
GRANT SELECT ON DBA_TABLESPACE_USAGE_METRICS TO estack_diagnostic_role;   -- 11g+
GRANT SELECT ON DBA_FREE_SPACE               TO estack_diagnostic_role;
GRANT SELECT ON DBA_TEMP_FILES               TO estack_diagnostic_role;
GRANT SELECT ON DBA_TEMP_FREE_SPACE          TO estack_diagnostic_role;
GRANT SELECT ON DBA_SCHEDULER_JOBS           TO estack_diagnostic_role;
GRANT SELECT ON DBA_SCHEDULER_JOB_RUN_DETAILS TO estack_diagnostic_role;
GRANT SELECT ON DBA_JOBS                     TO estack_diagnostic_role;   -- legacy, si aún en uso
GRANT SELECT ON DBA_OBJECTS                  TO estack_diagnostic_role;
GRANT SELECT ON DBA_REGISTRY                 TO estack_diagnostic_role;
GRANT SELECT ON DBA_OUTSTANDING_ALERTS       TO estack_diagnostic_role;   -- 11g+
GRANT SELECT ON DBA_PDBS                     TO estack_diagnostic_role;   -- 12c+
GRANT SELECT ON V_$PDBS                      TO estack_diagnostic_role;   -- 12c+
GRANT SELECT ON V_$CONTAINERS                TO estack_diagnostic_role;   -- 12c+
```

## Required privileges — RAC/GI/Network (Fase 4)

```sql
GRANT SELECT ON GV_$SESSION                   TO estack_diagnostic_role;
GRANT SELECT ON GV_$SERVICES                  TO estack_diagnostic_role;
GRANT SELECT ON GV_$ACTIVE_SERVICES           TO estack_diagnostic_role;   -- 11.2+
GRANT SELECT ON GV_$CLUSTER_INTERCONNECTS     TO estack_diagnostic_role;   -- 11.2+
GRANT SELECT ON GV_$GES_STATISTICS            TO estack_diagnostic_role;   -- 11.2+
GRANT SELECT ON GV_$GCS_STATISTICS            TO estack_diagnostic_role;   -- 11.2+
GRANT SELECT ON GV_$INSTANCE_CACHE_TRANSFER   TO estack_diagnostic_role;   -- 11.2+
```

Los collectors GI/Clusterware/red (`docs/GI_READONLY_COLLECTORS.md`) no usan SQL — requieren una **identidad diagnóstica de sistema operativo separada** (ver "Identity separation" abajo), nunca la identidad SQL `ESTACK_DIAGNOSTIC_ROLE`.

## Required privileges — ASM (Fase 4)

```sql
-- Ejecutados contra la instancia +ASM, no contra la base de datos — conexión SQL separada.
GRANT SELECT ON GV_$ASM_INSTANCE       TO estack_diagnostic_role;   -- 11.2+
GRANT SELECT ON V_$ASM_DISKGROUP_STAT  TO estack_diagnostic_role;   -- default de monitoreo rutinario
GRANT SELECT ON V_$ASM_DISK            TO estack_diagnostic_role;   -- 11.2+, cost_class MEDIUM
GRANT SELECT ON GV_$ASM_OPERATION      TO estack_diagnostic_role;   -- 11.2+
-- V$ASM_DISKGROUP (disk discovery) sólo bajo demanda explícita — no otorgar por defecto
-- (mismo criterio de Q-DISC-ASM-001-V2, ver tabla de variantes abajo).
```

## Required privileges — Data Guard (Fase 5)

```sql
-- Ejecutadas en el sitio primary y en cada standby conocido, mismo rol ESTACK_DIAGNOSTIC_ROLE.
GRANT SELECT ON V_$DATAGUARD_STATS      TO estack_diagnostic_role;
GRANT SELECT ON V_$ARCHIVE_GAP          TO estack_diagnostic_role;
GRANT SELECT ON V_$MANAGED_STANDBY      TO estack_diagnostic_role;
GRANT SELECT ON GV_$MANAGED_STANDBY     TO estack_diagnostic_role;   -- si el sitio es RAC
GRANT SELECT ON V_$STANDBY_LOG          TO estack_diagnostic_role;
GRANT SELECT ON GV_$ARCHIVE_DEST_STATUS TO estack_diagnostic_role;   -- si el primary es RAC
-- V$DATABASE, V$ARCHIVE_DEST, V$ARCHIVE_DEST_STATUS, V$ARCHIVED_LOG, V$LOG ya cubiertos arriba (Fase 2/3).
```

Los collectors Broker (`docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md`) no usan SQL — requieren la identidad diagnóstica Broker separada (ver "Identity separation" abajo), nunca la identidad SQL `ESTACK_DIAGNOSTIC_ROLE`.

## Identity separation (Fase 4/5, `# 77` del prompt de Fase 5)

Extiende la tabla de Fase 4 con una cuarta identidad:

| Identidad | Alcance | Usada por |
|---|---|---|
| `ESTACK_DIAGNOSTIC_ROLE` (database, primary y standby) | `SELECT` sobre las vistas Data Guard de este documento, en cada sitio conocido | `Q-DG-*` |
| Identidad diagnóstica Broker | Ejecución allowlisted de `dgmgrl` limitada a `SHOW CONFIGURATION`/`SHOW DATABASE [VERBOSE]`/`SHOW FAST_START FAILOVER` | Collectors de `docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md` |

Ninguna identidad Data Guard es `SYSDBA` permanente (`# 77`: "No recomendar SYSDBA permanente para el e-stack"). Para cualquier evidencia que requiera un privilegio no disponible: `INSUFFICIENT_PRIVILEGES` + `MANUAL_COLLECTION_REQUIRED` — nunca escalamiento automático, mismo modelo que Fase 4.

## Identity separation (Fase 4, `# 71` del prompt de Fase 4)

Tres identidades distintas, ninguna con capacidad de escritura, nunca `root`/`sudo`/`grid` con capacidad de cambio:

| Identidad | Alcance | Usada por |
|---|---|---|
| `ESTACK_DIAGNOSTIC_ROLE` (database) | `SELECT` sobre las vistas de este documento, contra la base de datos | Todas las queries `Q-ORA-*`/`Q-PERF-*`/`Q-RAC-*` |
| Identidad diagnóstica GI/OS | Ejecución allowlisted de `olsnodes`/`crsctl`/`srvctl`/`lsnrctl`/`oifcfg`/`ocrcheck` (subcomandos de lectura únicamente) | Collectors de `docs/GI_READONLY_COLLECTORS.md` |
| `ESTACK_DIAGNOSTIC_ROLE` (ASM) | `SELECT` sobre las vistas ASM de este documento, contra la instancia `+ASM` (conexión separada, rol distinto al de la base de datos — arquitectura estándar Oracle, no una elección de este e-stack) | `Q-ASM-*` |

Para cualquier evidencia que requiera un privilegio no disponible en alguna de estas tres identidades: `INSUFFICIENT_PRIVILEGES` + `MANUAL COLLECTION INSTRUCTION` para que un administrador autorizado (DBA/Grid admin, según corresponda) ejecute el comando/query y entregue la salida — nunca se escalan privilegios automáticamente, y nunca se recomienda `root`/`sudo`/`grid` con capacidad de cambio como identidad permanente del e-stack.

Lectura de `alert.log` (`Q-ORA-DIAGNOSTICS-ALERTLOG-001`) es un privilegio de **sistema operativo**, no SQL — requiere que el usuario OS bajo el que corre el collector tenga permiso de lectura sobre el ADR home (típicamente el grupo `oinstall`/equivalente), nunca escritura.

## Optional privileges

```sql
GRANT SELECT ON DBA_TS_QUOTAS TO estack_diagnostic_role;   -- si se materializa un skill de cuotas por usuario (registered, no Fase 2)
```

## Query variant → privilege mapping (Compatibility Hardening)

Para las logical queries con variantes reales (`docs/QUERY_VARIANTS.md`), el privilegio requerido puede diferir por variante — un target cuyo Query Resolver nunca seleccionará cierta variante (por versión conocida y fija) no necesita el grant de esa variante. Otorgar sólo lo que el Resolver puede seleccionar para ese target es coherente con mínimo privilegio; en targets de versión no fija (ej. rangos de flota heterogéneos), otorgar la unión.

| Logical query | Variant | Rango | Objetos (privilegio) |
|---|---|---|---|
| `Q-DISC-IDENTITY-001` | V1 legacy_10g_11g | 10.2–11.2 | `V$INSTANCE`, `V$DATABASE` (sin `CDB`/`VERSION_FULL`) |
| `Q-DISC-IDENTITY-001` | V2 multitenant_12c | 12.1–12.2 | `V$INSTANCE`, `V$DATABASE` (incl. `CDB`) |
| `Q-DISC-IDENTITY-001` | V3 modern_18plus | 18.0+ | `V$INSTANCE` (incl. `VERSION_FULL`), `V$DATABASE` |
| `Q-DISC-RAC-001` | V1 pre_multitenant | 11.2 | `V$ACTIVE_INSTANCES` (sin `CON_ID`) |
| `Q-DISC-RAC-001` | V2 multitenant_aware | 12.1+ | `V$ACTIVE_INSTANCES` (incl. `CON_ID`) |
| `Q-ORA-INSTANCE-STATE-001` | V1 legacy_10g | 10.2 | `V$INSTANCE` (sin `INSTANCE_ROLE`) |
| `Q-ORA-INSTANCE-STATE-001` | V2 modern_11plus | 11.0+ | `V$INSTANCE` (incl. `INSTANCE_ROLE`) |
| `Q-DBA-TBS-USAGE-001` | V1 legacy_10g | 10.2 | `DBA_DATA_FILES`, `DBA_FREE_SPACE` |
| `Q-DBA-TBS-USAGE-001` | V2 modern_11plus | 11.0+ | `DBA_TABLESPACE_USAGE_METRICS` |
| `Q-DISC-ASM-001` | V1 routine_stat (default) | 11.0+ | `V$ASM_DISKGROUP_STAT` (bajo costo, sin disk discovery) |
| `Q-DISC-ASM-001` | V2 detailed_diskgroup (on-demand) | 11.0+ | `V$ASM_DISKGROUP` — otorgar sólo si el target realmente ejecutará diagnóstico ASM profundo bajo demanda; **no** otorgar por defecto para monitoreo rutinario (ver sección "ASM QUERY COST FIX" en `docs/PHASE_2_COMPATIBILITY_HARDENING.md`) |

Queries de rango único (`implicit_full_range`, ver `config/query-compatibility-matrix.yaml`) no requieren esta distinción — un solo conjunto de privilegios cubre todo su rango declarado (ya reflejado en la tabla `GRANT` de arriba).

## Query mapping

Ver `queries/REGISTRY.md` (secciones "Identity & Scope" y "Oracle Core queries") — cada entrada declara `objects_accessed`, que es la fuente de verdad de qué vista requiere qué privilegio. Este documento es una consolidación legible, no una fuente independiente (evitar contradicción — ver `docs/CONTRACTS.md` sección 46 del prompt de Fase 2, "Source of Truth").

## Security rationale

- `SELECT` explícito sobre cada vista, nunca `SELECT_CATALOG_ROLE` como default ciego — `SELECT_CATALOG_ROLE` incluye acceso a decenas de vistas no usadas por el catálogo de Fase 2 (superficie innecesaria).
- Ninguna concesión sobre tablas de aplicación, `SYS.*` tablas base (siempre a través de las vistas `V$`/`DBA_*` públicas), ni procedimientos con side effects.
- El acceso a `V$ASM_DISKGROUP` requiere una conexión separada a la instancia ASM (arquitectura estándar de Oracle) — el `ESTACK_DIAGNOSTIC_ROLE` en la instancia ASM es un rol **distinto**, igualmente de sólo lectura, no cubierto por este documento (ASM profundo es Fase 4).

## Alternatives considered

- **`SELECT_CATALOG_ROLE`**: evaluado y descartado como *default* — otorga acceso a más vistas de las necesarias (incluye vistas de auditoría, definiciones de objetos con potencial de exponer más superficie de la requerida). Puede ser una alternativa pragmática para ambientes donde crear 30+ grants individuales es operacionalmente inviable, a discreción del DBA — se documenta como alternativa, no como recomendación por defecto.
- **Vistas diagnósticas propias (`ESTACK_V_*`)**: para vistas donde `V$SESSION`/`V$PROCESS` exponen más columnas de las necesarias (ej. `SQL_TEXT`, `MODULE`, `ACTION` no usadas por Fase 2), el DBA puede optar por crear una vista propia que exponga sólo las columnas requeridas y conceder `SELECT` sobre ella en vez de la vista completa — más trabajo inicial, menor superficie.

## Limitations

- Esta lista cubre Oracle Core (Fase 2) + Discovery + Performance (Fase 3) + RAC/GI/ASM/Network (Fase 4) + Data Guard (Fase 5). Fases futuras (Multitenant/RMAN/Security profundos) requerirán privilegios adicionales, documentados incrementalmente vía `/change` cuando esas fases se implementen.
- La instancia ASM ahora está cubierta (ver "Required privileges — ASM (Fase 4)" arriba) — sigue siendo una conexión/rol separado de la base de datos, arquitectura estándar Oracle.
- El acceso a `alert.log` depende de la configuración de permisos del sistema operativo del target, fuera del control de Oracle SQL — se documenta como prerequisito operativo, no como un `GRANT`.

## Referencia

`policies/identity-model.md`, `SECURITY.md#identidades-y-privilegios`, `queries/REGISTRY.md`.
