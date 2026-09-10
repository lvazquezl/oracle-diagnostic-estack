---
name: pdb-state
id: multitenant/pdb-state
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Clasificar el estado de cada PDB (`MOUNTED|READ WRITE|READ ONLY|MIGRATE|UNKNOWN`, `restricted: YES|NO|UNKNOWN`) y save state visibility, distinguiendo intención/mantenimiento conocido de un problema real (`# 11`, `# 12` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/pdb-inventory` resuelto.

# Required evidence

- `Q-CDB-PDB-STATE-001` (`V$PDBS`: `open_mode`, `restricted`)

# Optional evidence

- `Q-CDB-PDB-SAVED-STATE-001` (`DBA_PDB_SAVED_STATES`, 12.1.0.2+) — sólo visibilidad de save state.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-PDB-STATE-001`, `Q-CDB-PDB-SAVED-STATE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$PDBS`, `DBA_PDB_SAVED_STATES`.

# Forbidden operations

Nunca ejecuta `ALTER PLUGGABLE DATABASE OPEN|CLOSE|SAVE STATE|DISCARD STATE` (`# 12`).

# Decision logic

1. Clasificar `open_mode` en `MOUNTED|READ WRITE|READ ONLY|MIGRATE|UNKNOWN` — `MOUNTED` NO es error por sí mismo (`# 11`), se evalúa contra ventanas de mantenimiento declaradas en `constraints` del Task Package e intención conocida.
2. Clasificar `restricted` en `YES|NO|UNKNOWN` — `RESTRICTED = YES` fuera de contexto de mantenimiento es señal `MEDIUM` (sólo usuarios con `RESTRICTED SESSION` pueden conectar).
3. Si hay save state visible, reportarlo — nunca ejecutar `SAVE STATE`, sólo puede generar una recomendación manual si el DBA la pide.
4. Un PDB `MOUNTED`/`RESTRICTED` inesperado en producción, sin explicación de mantenimiento, escala a `incident-root-cause-analyst`.

# Normal state

`open_mode = READ WRITE`, `restricted = NO`, salvo PDBs intencionalmente `READ ONLY` (ej. reporting) declaradas como tales por el DBA.

# Abnormal patterns

`MOUNTED`/`RESTRICTED` sin ventana de mantenimiento conocida; `MIGRATE` prolongado (posible operación de upgrade/plug estancada).

# False positives

Una PDB `READ ONLY` intencional (reporting/DR) no es un error — se reclasifica cuando el DBA lo declara vía `constraints`.

# Correlation rules

Correlaciona con `multitenant/pdb-services` (¿el servicio de esta PDB está afectado por el estado?) y con Data Guard (`dataguard/topology`) cuando el CDB participa en Data Guard.

# Confidence model

`FACT` para el estado leído directamente. `PROBABLE_CAUSE` sólo si el estado inesperado coincide con un síntoma reportado por el DBA (ej. "la aplicación X no puede conectar desde hace una hora").

# Severity

`MOUNTED`/`RESTRICTED` inesperado en producción → `HIGH`. `READ ONLY` no declarado → `MEDIUM`.

# Output schema

```yaml
findings:
  - pdb_token: string
    open_mode: MOUNTED|READ_WRITE|READ_ONLY|MIGRATE|UNKNOWN
    restricted: YES|NO|UNKNOWN
    save_state_visible: bool|null
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-inventory`, `multitenant/pdb-open-mode`, `multitenant/pdb-services`, `multitenant/troubleshooting`.

# Escalation

PDB crítica `MOUNTED`/`RESTRICTED` inesperada → `incident-root-cause-analyst`, severity HIGH.

# Manual remediation guidance

Apertura de PDB o `SAVE STATE`/`DISCARD STATE` se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

`pdb_token` tokenizado.

# Tests

`tests/test_pdb_state.sh`, `tests/test_no_open_close_pdb_execution.sh`, `tests/test_no_save_state_execution.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
