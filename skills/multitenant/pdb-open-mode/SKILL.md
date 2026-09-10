---
name: pdb-open-mode
id: multitenant/pdb-open-mode
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Complementa `multitenant/pdb-state` con foco específico en consistencia de open mode entre RAC instances y frente al open mode esperado por diseño (ej. PDB standby en `READ ONLY WITH APPLY` intencional vs. Data Guard).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/pdb-inventory` resuelto.

# Required evidence

- `Q-CDB-PDB-STATE-001` (`V$PDBS`: `open_mode`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-PDB-STATE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$PDBS`.

# Forbidden operations

Nunca ejecuta `ALTER PLUGGABLE DATABASE OPEN/CLOSE`.

# Decision logic

1. Sobre RAC, comparar `open_mode` de la misma PDB entre instancias — un mismatch (abierta en una instancia, cerrada en otra) es una señal para `multitenant/pdb-rac-placement`, nunca se asume automáticamente que todas las instancias deben coincidir sin correlacionar con el diseño de servicio (`# 13`).
2. Correlacionar con `target_profile.dataguard` cuando el CDB participa en Data Guard — un `open_mode` de PDB no determina el rol Data Guard del CDB (`# 37`).

# Normal state

`open_mode` consistente con el diseño declarado (todas las instancias RAC esperadas, o subconjunto intencional).

# Abnormal patterns

Mismatch de `open_mode` entre instancias RAC sin explicación de diseño.

# False positives

Una PDB intencionalmente abierta sólo en un subconjunto de instancias (ej. afinidad de servicio) no es un error.

# Correlation rules

Delega a `oracle-rac-analyst` cuando el mismatch correlaciona con service placement (`# 13`, `# 34`).

# Confidence model

`FACT` para el estado leído directamente. `PROBABLE_CAUSE` cuando el mismatch coincide con un síntoma de servicio reportado.

# Severity

Mismatch sin explicación de diseño → `MEDIUM`; si afecta disponibilidad de servicio → `HIGH`.

# Output schema

```yaml
findings:
  - pdb_token: string
    open_mode_by_instance: [{instance: string, open_mode: string}]
    consistent: bool
    severity: LOW|MEDIUM|HIGH
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-state`, `multitenant/pdb-rac-placement`.

# Escalation

Mismatch que afecta disponibilidad → `incident-root-cause-analyst`.

# Manual remediation guidance

Apertura/cierre se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

`pdb_token` tokenizado.

# Tests

`tests/test_pdb_state.sh`, `tests/test_no_open_close_pdb_execution.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
