---
name: optimizer-statistics
display_name: "Optimizer Statistics"
id: oracle/optimizer-statistics
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar si el optimizer trabaja con estadísticas vigentes: tablas sin estadísticas, obsoletas o bloqueadas por tipo de dueño (fixed objects, esquemas de Oracle y propios) y si la recolección automática está habilitada y terminando bien. Estadísticas faltantes u obsoletas son una causa frecuente de cambios de plan y degradación de SQL.

# Scope

**En alcance:** conteos agregados por contenedor y tipo de dueño (`Q-ORA-OPTIMIZER-STATS-001`) y el estado de la tarea automática de estadísticas (`Q-ORA-AUTOTASK-001`). **Fuera de alcance:** estadísticas de índices, columnas e histogramas, preferencias de `DBMS_STATS` y el plan de un SQL concreto (eso es `performance/execution-plan` y `performance/plan-regression`).

# Supported Oracle versions

10g–23ai. AutoTask desde 11.1; en 10g la recolección automática es el job `GATHER_STATS_JOB` del Scheduler y se evalúa con `oracle/jobs`. La clasificación propio/Oracle usa `ORACLE_MAINTAINED` desde 12.1.0.2; antes solo `SYS`/`SYSTEM` cuentan como Oracle y el resto sale `OTHER`.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (las estadísticas son de la base, no de la instancia). NON-CDB y CDB: desde `CDB$ROOT` cada contenedor abierto tiene su fila.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-OPTIMIZER-STATS-001`

# Optional evidence

- `Q-ORA-AUTOTASK-001` (11.1+)

# Data collection

`CDB_TAB_STATISTICS` (`DBA_TAB_STATISTICS` antes de 12.1): tablas y fixed objects, sin particiones ni papelera. `CDB_AUTOTASK_CLIENT`, `CDB_AUTOTASK_WINDOW_CLIENTS` y `CDB_AUTOTASK_JOB_HISTORY` para la recolección automática. Solo conteos y horas: nunca nombres de tabla ni de esquema.

# Diagnostic logic / Decision tree

```text
por contenedor:
IF owner_kind = FIXED AND tables_without_stats = tables      → MEDIUM: fixed objects nunca analizados
IF owner_kind = ORACLE AND max_hours_since_analyzed > 8760   → LOW: diccionario sin estadísticas en un año
IF owner_kind IN (CUSTOM, OTHER):
   pct_stale   = tables_stale / tables
   pct_missing = tables_without_stats / tables
   IF pct_missing >= 10% OR pct_stale >= 20%                → MEDIUM (HIGH si además AUTO_OPTIMIZER_STATS no corre)
   IF tables_stats_locked > 0                               → INFO: estadísticas bloqueadas a propósito; verificar que siga vigente
AUTO_OPTIMIZER_STATS:
   IF autotask_status = DISABLED                            → MEDIUM: sin recolección automática; confirmar si hay recolección propia
   IF windows_enabled = 0                                   → MEDIUM: habilitada pero sin ventana que la corra
   IF runs_not_succeeded_7d > 0                             → MEDIUM: ejecuciones fallidas o detenidas
   IF hours_since_last_success > 48 (o nulo)                → MEDIUM: sin ejecución exitosa reciente
```

# Normal behavior

`AUTO_OPTIMIZER_STATS` habilitada, con ventanas y una ejecución exitosa en las últimas 24–48 horas; pocas tablas propias obsoletas; fixed objects con estadísticas recolectadas al menos una vez tras el último upgrade.

# Abnormal patterns

Recolección automática deshabilitada sin sustituto, ejecuciones que se detienen al cerrar la ventana (`STOPPED`), un alto porcentaje de tablas propias sin estadísticas, fixed objects nunca analizados.

# Root cause patterns

Una regresión de plan coincide con tablas obsoletas o sin estadísticas de esa aplicación (`PROBABLE_CAUSE` solo si `performance/plan-regression` identifica el SQL y el contenedor). La ventana de mantenimiento es demasiado corta para el volumen (ejecuciones `STOPPED`).

# Correlation rules

Cruzar con `oracle/jobs` (recolección propia vía Scheduler, que justifica AutoTask deshabilitado), con `performance/plan-regression` (cambios de plan) y con `oracle/database-state` (bases recién migradas o actualizadas: fixed objects sin recolectar).

# False positives

- Tablas temporales globales y externas sin estadísticas: suelen ser lo esperado y cuentan en `tables_without_stats`.
- `tables_stale` depende del último flush del monitoreo DML: puede ir atrasado algunas horas.
- AutoTask deshabilitado no es hallazgo si el DBA confirma una recolección propia vigente.
- Un contenedor recién creado o un standby (las estadísticas son las del primario).

# Confidence model

`FACT` para los conteos y el estado de AutoTask. `PROBABLE_CAUSE` como máximo para cualquier relación con una degradación de SQL, y solo con evidencia de plan. Sin validación en campo para el ambiente, la confianza no supera `PROBABLE_CAUSE`.

# Findings

```yaml
finding_id: FND-...
category: optimizer-statistics
severity: INFO|LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|PROBABLE_CAUSE
impact: string
recommendations: [REC-...]
```

# Recommendations

Habilitar o reprogramar la recolección automática, ampliar la ventana de mantenimiento, recolectar estadísticas de fixed objects y del diccionario tras un upgrade, revisar la vigencia de las estadísticas bloqueadas — siempre `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar carga baja (fuera de horario pico) y espacio en SYSAUX
command:    EXEC DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;
            EXEC DBMS_STATS.GATHER_DICTIONARY_STATS;
            -- recolección automática (11.1+):
            EXEC DBMS_AUTO_TASK_ADMIN.ENABLE(client_name => 'auto optimizer stats collection', operation => NULL, window_name => NULL);
expected_result: Q-ORA-OPTIMIZER-STATS-001 muestra FIXED/ORACLE con análisis reciente; Q-ORA-AUTOTASK-001 ENABLED con ejecución exitosa
rollback:   DBMS_STATS.RESTORE_*_STATS a un timestamp previo (historial de estadísticas, retención 31 días por defecto)
postcheck:  re-ejecutar Q-ORA-OPTIMIZER-STATS-001 y Q-ORA-AUTOTASK-001
```

# Version differences

10g: `GATHER_STATS_JOB` del Scheduler en lugar de AutoTask (`Q-ORA-AUTOTASK-001` es `UNSUPPORTED`). 11.1+: AutoTask. 12.1.0.2+: clasificación por `ORACLE_MAINTAINED`. 19c+: la recolección de alta frecuencia y en tiempo real (Exadata/Autonomous) no se distingue con esta evidencia.

# RAC considerations

Las estadísticas son de la base; en RAC la evidencia es la misma desde cualquier instancia.

# Multitenant considerations

Cada PDB tiene sus estadísticas y su AutoTask: desde `CDB$ROOT` se evalúa cada contenedor por separado, nunca se suman.

# Standby considerations

`PRIMARY`: un standby físico tiene las estadísticas del primario y no ejecuta AutoTask.

# Security

Read-only, `SELECT` sobre `CDB_TAB_STATISTICS`, `CDB_USERS` y `CDB_AUTOTASK_*` (o sus `DBA_*`). Nunca expone nombres de tablas ni de esquemas.

# Licensing

No depende de ninguna feature licenciada. Ejecutar el SQL Tuning Advisor (otro cliente de AutoTask) requiere Tuning Pack; este skill no lo evalúa.

# Related skills

`oracle/jobs`, `performance/plan-regression`, `performance/execution-plan`.

# Escalation

Una regresión de plan con estadísticas obsoletas en el contenedor afectado escala a `oracle-performance-analyst`.

# Examples

Ver `mcp_gateway/fixtures/fixture-cdb-root-19c/Q-ORA-OPTIMIZER-STATS-001.json`.

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto bajo.

# Tests

`tests/test_oracle_core_optimizer_statistics.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | `CHG-ESTACK-C-NEW-QUERIES-001` (lote C) | Creado: dominio X del assessment (estadísticas y optimizer), sin evidencia hasta ahora. |
