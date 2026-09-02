---
name: backup-status
id: rman/backup-status
version: 1.0.0
domain: rman
status: active
---

# Purpose

Determinar el estado del último backup full/incremental/archivelog y si la estrategia de backup vigente cumple la retención esperada, sin ejecutar ni proponer ejecución automática de ningún backup.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas — el estado se lee del catálogo RMAN (controlfile o recovery catalog), no depende del OS salvo para el SBT (media manager de terceros).

# Supported architectures

Standalone y RAC (canales por instancia). NON-CDB y CDB (backup a nivel CDB; PDB-level desde 12c se declara si se detecta). ASM y Filesystem. Primary y Physical Standby (backup-from-standby cuando aplica).

# Prerequisites

Requiere `core/context-discovery` confirmado.

# Required evidence

- query_id: `Q-RMAN-BACKUP-JOB-001` (`V$RMAN_BACKUP_JOB_DETAILS`)

# Optional evidence

- query_id: `Q-RMAN-BACKUPSET-001` (`V$BACKUP_SET`, detalle de piezas)

# Read-only operations

Lectura de `V$RMAN_BACKUP_JOB_DETAILS`, `V$BACKUP_SET`, `V$RMAN_STATUS`.

# Forbidden operations

No ejecuta `BACKUP`, `CROSSCHECK`, `DELETE OBSOLETE/EXPIRED`, ni cambia `CONFIGURE RETENTION POLICY`.

# Decision logic

1. Identificar el último backup exitoso por tipo (`FULL`, `INCREMENTAL LEVEL 0/1`, `ARCHIVELOG`).
2. Si no hay backup full/nivel 0 dentro de la ventana esperada por política de retención → `HIGH`.
3. Si el último job de archivelog backup falló (`STATUS != COMPLETED`) → `HIGH` (riesgo de gap de recuperación).
4. Si el job tardó significativamente más que su promedio histórico (evidencia opcional) → señalar como posible degradación de performance de backup, no como fallo de estrategia.

# Confidence model

`FACT` para estado/fecha del último backup leído directamente. `UNDETERMINED` para "recovery readiness" completo si falta evidencia de tamaño de base o banda de red hacia el SBT (esa síntesis la hace `rman/recovery-readiness`, no este skill).

# Output schema

```yaml
findings:
  - backup_type: FULL|INCREMENTAL_0|INCREMENTAL_1|ARCHIVELOG
    last_status: COMPLETED|FAILED|RUNNING
    last_completion: string|null
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|UNDETERMINED
    evidence_refs: [EVD-...]
```

# Related skills

`rman/backup-history`, `rman/fra`, `rman/recovery-readiness`, `rman/troubleshooting`.

# Escalation

Ausencia de backup full/archivelog dentro de ventana esperada escala a `incident-root-cause-analyst` si hay indicios de fallo activo, o a `change-advisor` si es un ajuste de configuración correctivo.

# Data sensitivity

Baja: metadata de jobs de backup, sin contenido de datos.

# Context budget

Bajo-medio: historial acotado por ventana de tiempo del Task Package.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_no_restore_recover.sh`.

# Documentation requirements

Alimenta `findings.md` con estado de backups por tipo.

# Evolution via `/change`

Ventana de retención esperada vía `/change policy`; nuevas queries vía `/change query`.
