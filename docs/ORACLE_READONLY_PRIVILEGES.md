# Oracle Read-Only Privileges — `ESTACK_DIAGNOSTIC_ROLE` (Fase 2)

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

- Esta lista cubre exclusivamente Oracle Core (Fase 2) + Discovery. Fases futuras (Performance/RAC/ASM/Data Guard/Multitenant/RMAN/Network/OS) requerirán privilegios adicionales, documentados incrementalmente vía `/change` cuando esas fases se implementen.
- No cubre la instancia ASM por separado (ver arriba).
- El acceso a `alert.log` depende de la configuración de permisos del sistema operativo del target, fuera del control de Oracle SQL — se documenta como prerequisito operativo, no como un `GRANT`.

## Referencia

`policies/identity-model.md`, `SECURITY.md#identidades-y-privilegios`, `queries/REGISTRY.md`.
