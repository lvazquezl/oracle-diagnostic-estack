---
name: pdb-undo
id: multitenant/pdb-undo
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Awareness de UNDO por PDB — distingue shared undo (un único tablespace UNDO en CDB$ROOT compartido) de local undo (cada PDB con su propio tablespace UNDO), según versión y configuración real (`# 19` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai. Local Undo no existe en 12.1 (introducido en 12.2) — nunca asumido sin verificación (`# 19`).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/local-undo` resuelto (determina el modo).

# Required evidence

- `Q-CDB-TABLESPACES-001` (tablespace `contents = UNDO`, filtrado por el skill)
- `Q-CDB-PDB-STATE-001` (`local_undo` flag, 12.2+)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-TABLESPACES-001`, `Q-CDB-PDB-STATE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `CDB_TABLESPACES` (filtrado `contents=UNDO`), `V$PDBS.local_undo`.

# Forbidden operations

Nunca cambia `LOCAL_UNDO_ENABLED` ni realiza conversiones (`# 19`, `# 20`).

# Decision logic

1. Leer `local_undo` de `multitenant/local-undo` (evidencia ya publicada, nunca re-consultada).
2. Si `local_undo = 1` (12.2+): reportar el tablespace UNDO propio de cada PDB, con su uso.
3. Si `local_undo = 0` o versión 12.1: reportar el tablespace UNDO compartido de CDB$ROOT — nunca asumir que existe un UNDO por-PDB en ese caso.

# Normal state

Uso de UNDO dentro de umbrales normales, modo (shared/local) consistente con la versión/configuración real.

# Abnormal patterns

Presión de UNDO sostenida; modo local_undo inconsistente entre lo esperado por el DBA y lo observado.

# False positives

Un tablespace UNDO compartido con uso alto en un CDB con muchas PDBs activas no es automáticamente un problema de una PDB específica — requiere correlación con `multitenant/resource-usage`.

# Correlation rules

Correlaciona con `multitenant/local-undo` (modo) y `multitenant/pdb-tablespaces` (capacidad general).

# Confidence model

`FACT` para el modo y uso leídos directamente.

# Severity

Presión de UNDO sostenida con impacto en transacciones → `MEDIUM`/`HIGH`.

# Output schema

```yaml
pdb_undo:
  - pdb_token: string
    undo_mode: SHARED|LOCAL|UNKNOWN
    tablespace: string|null
    used_bytes: int|null
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/local-undo`, `multitenant/pdb-tablespaces`.

# Escalation

Presión de UNDO crítica con fallos de transacción → `incident-root-cause-analyst`.

# Manual remediation guidance

Resize de UNDO tablespace se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`. Nunca se recomienda conversión shared↔local sin evaluación explícita del DBA.

# Security

`pdb_token`/`tablespace` según política.

# Tests

`tests/test_pdb_undo.sh`, `tests/test_local_undo_version_awareness.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
