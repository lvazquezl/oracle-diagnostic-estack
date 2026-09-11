---
name: multitenant-awareness
id: rman/multitenant-awareness
version: 1.0.0
domain: rman
status: active
---

# Purpose

Distingue CDB backup, cobertura de datafile por PDB, PDB PITR, scope de controlfile/archivelog — nunca trata una PDB como base de datos física independiente (`# 29` del prompt de Fase 7).

# Supported Oracle versions

12.1–23ai (`CON_ID` en `V$BACKUP_SET` sólo 12.1+; `NOT_APPLICABLE` en 10g/11g/12c NON-CDB).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Target Profile `multitenant.cdb = true`.

# Required evidence

- `Q-RMAN-BACKUP-SET-001` (variante V2, 12.1+)

# Optional evidence

Delegación a `oracle-multitenant-analyst` para topología PDB/local undo.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-BACKUP-SET-001`.

# Collector IDs

`get_backup_inventory`.

# Read-only operations

Lectura de `V$BACKUP_SET` con `CON_ID`.

# Forbidden operations

Nunca ejecuta `BACKUP PLUGGABLE DATABASE`.

# Decision logic

1. `CON_ID = 1` → backup a nivel CDB$ROOT (incluye metadata compartida). `CON_ID = n` → backup específico de esa PDB.
2. Un backup `CON_ID = 1` (whole database, ejecutado desde root) puede cubrir todas las PDBs sin filas `CON_ID = n` individuales — comportamiento normal de `BACKUP DATABASE` a nivel CDB, no un gap de cobertura PDB.
3. PDB-level RMAN backup/restore existe desde 12.1 con mejoras en 12.2 — sin evidencia certificada del detalle completo por versión, `capability_status: PARTIALLY_SUPPORTED` (nunca se asume soporte completo sin verificación, mismo principio que Fase 6).
4. Nunca tratar una PDB como base de datos físicamente independiente — su recuperabilidad depende siempre del contexto CDB (controlfile, archivelog compartido).

# Normal state

Cobertura de backup coherente con la estrategia declarada (whole-CDB vs. PDB-level explícito).

# Abnormal patterns

Una PDB específica sin cobertura de datafile en ningún backup CDB ni PDB-level, mientras otras PDBs sí la tienen.

# False positives

Ausencia de filas `CON_ID = n` individuales no es un gap si la estrategia es `BACKUP DATABASE` a nivel CDB (cubre todo).

# Correlation rules

Delega a `oracle-multitenant-analyst` para contexto de topología/local undo; correlaciona con `rman/pdb-pitr-awareness`.

# Confidence model

`FACT` para `CON_ID` leído. `PARTIALLY_SUPPORTED` explícito donde el catálogo no certifica el detalle completo.

# Severity

PDB sin cobertura de datafile en ningún backup → `HIGH`.

# Output schema

```yaml
multitenant_awareness:
  cdb_backup_scope: string|null
  pdb_datafile_coverage: [{pdb_token: string, covered: bool|null}]
  capability_status: SUPPORTED|PARTIALLY_SUPPORTED|INSUFFICIENT_EVIDENCE
  evidence_refs: [EVD-...]
```

# Related skills

`rman/backup-inventory`, `rman/pdb-pitr-awareness`, `rman/dataguard-awareness`.

# Escalation

PDB crítica sin cobertura de backup → `oracle-multitenant-analyst` → `incident-root-cause-analyst`.

# Manual remediation guidance

`BACKUP PLUGGABLE DATABASE` se entrega como recomendación manual — nunca ejecutado.

# Security

`pdb_token` siempre tokenizado (mismo esquema que `oracle-multitenant-analyst`).

# Tests

`tests/test_cdb_backup_awareness.sh`, `tests/test_pdb_backup_scope.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/backup-inventory.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
