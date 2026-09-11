# RMAN Diagnostic Model — Fase 7

## Backup model

```yaml
backup:
  key:
  type:                    # FULL | INCREMENTAL_LEVEL_0 | LEVEL_1_DIFFERENTIAL | LEVEL_1_CUMULATIVE
                            # | ARCHIVELOG | CONTROLFILE | SPFILE | IMAGE_COPY
  level:
  incremental_type:
  device_type:              # DISK | SBT_TAPE | UNKNOWN
  start_time:
  completion_time:
  elapsed:
  status:                    # COMPLETED | COMPLETED WITH WARNINGS | FAILED | RUNNING | UNKNOWN
  size:
  pieces:
  tag:
  controlfile_included:
  spfile_included:
  archivelogs_included:
```

`type`/`level` se derivan siempre de `BACKUP_TYPE`+`INCREMENTAL_LEVEL` (`V$BACKUP_SET`) — nunca de heurística sobre el `TAG` (`# 9` del prompt).

## RMAN status normalization

```text
COMPLETED
COMPLETED WITH WARNINGS
FAILED
RUNNING
UNKNOWN
```

Reportado tal cual `V$RMAN_STATUS.STATUS` lo declara — nunca se inventa un mapping adicional (`# 12`).

## Freshness / completeness

```text
COMPLETE               — last full/level0, last incremental, last archivelog, last controlfile,
                          last SPFILE, todos dentro de la ventana esperada.
PARTIAL                — al menos uno fuera de ventana o ausente.
STALE                  — ningún backup reciente.
UNKNOWN                — sin suficiente contexto para clasificar.
INSUFFICIENT_EVIDENCE  — Recovery Catalog inaccesible y controlfile rotado, u otra pérdida de
                          evidencia — nunca se asume el mejor ni el peor caso.
```

Nunca se afirma recoverability por la sola existencia de un backup set (`# 10`).

## Health Model

Por dimensión, nunca un score único opaco:

```text
CONFIGURATION
DATABASE BACKUP
ARCHIVELOG BACKUP
CONTROLFILE
SPFILE
RETENTION
FRA
CHANNELS
MEDIA MANAGER
RAC
DATAGUARD
MULTITENANT
RESTORE READINESS
RECOVERY READINESS
```

Estados: `HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE`.

## Evidence model

```text
backup_type
device_type
start_time
completion_time
status
thread
sequence
source
query_id
collector_id
variant_id
validation_status
sanitization
```

Trazabilidad: `EVD → FND → REC → CHG` (mismo modelo que el resto del e-stack).

## Sanitización / tokenización

```text
backup piece handles
filesystem paths
ASM paths
SBT labels
vendor job IDs
catalog names
DB_UNIQUE_NAME
hostnames
services
```

## Context/token policy

Nunca se envían miles de rows. Preferir: last successful full/level0, last incremental, last archivelog backup, failed jobs, longest jobs, top anomalies, readiness blockers, evidence refs (`# 37`).

## Archivelog coverage

```text
generated
backed up
deleted
applied
thread
sequence
destination
```

RAC: siempre `THREAD# + SEQUENCE#`, nunca threads mezclados (`# 17`). Distingue `not backed up` / `not applied` / `not archived` — nunca colapsado en un solo booleano.

## FRA

```text
SPACE_LIMIT
SPACE_USED
SPACE_RECLAIMABLE
NUMBER_OF_FILES
```

Correlacionado con: archivelog generation, backup cadence, retention, deletion policy, flashback logs, restore points, Data Guard (`# 18`). Nunca borra archivos.

## Obsolete vs. expired

```text
OBSOLETE
EXPIRED
UNAVAILABLE
DELETED
```

Sólo disponible vía ingest de `REPORT OBSOLETE`/`CROSSCHECK` ya ejecutados por el DBA — nunca ejecutados por el e-stack (`# 19`).

## Duration / throughput

Calculado cuando existe evidencia (`V$RMAN_BACKUP_JOB_DETAILS`): `elapsed`, `input bytes`, `output bytes`, `aggregate MB/s`. Distingue aggregate/per-channel/media-manager throughput. Correlaciona con CPU/I/O/canales/SBT/compresión sin inferir root cause por una sola métrica (`# 11`).
