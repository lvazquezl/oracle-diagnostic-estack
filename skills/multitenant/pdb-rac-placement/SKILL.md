---
name: pdb-rac-placement
id: multitenant/pdb-rac-placement
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Distinguir configured placement, actual open placement y service placement de cada PDB en RAC — nunca asumir que una PDB debe estar abierta en todas las instancias (`# 13` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

RAC/RAC One Node exclusivamente — nunca se activa sobre Standalone.

# Prerequisites

`multitenant/pdb-open-mode` y `multitenant/pdb-services` resueltos.

# Required evidence

- `Q-CDB-PDB-STATE-001` (open mode por PDB)
- `Q-CDB-SERVICES-001` (instancias activas por servicio)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-PDB-STATE-001`, `Q-CDB-SERVICES-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$PDBS`/`GV$SERVICES`.

# Forbidden operations

No relocaliza servicios, no abre/cierra PDBs en ninguna instancia.

# Decision logic

1. Comparar configured placement (diseño declarado por el DBA, si se provee en `constraints`), actual open placement (`multitenant/pdb-open-mode`) y service placement (`multitenant/pdb-services`).
2. `placement_status: MATCHES_DESIGN` cuando los tres coinciden; `PARTIAL` cuando hay diferencias explicables (afinidad intencional); `MISMATCH` cuando no hay explicación; `INSUFFICIENT_EVIDENCE` cuando falta el diseño declarado.
3. Nunca reportar `MISMATCH` sólo porque una PDB no está abierta en todas las instancias — correlacionar primero con el diseño de servicio real (`# 13`).

# Normal state

`placement_status: MATCHES_DESIGN` o `PARTIAL` con explicación conocida.

# Abnormal patterns

`MISMATCH` sin explicación — posible fallo de apertura automática en una instancia, o servicio mal configurado.

# False positives

Afinidad de servicio intencional a un subconjunto de instancias.

# Correlation rules

Delega a `oracle-rac-analyst` cuando el mismatch requiere contexto de topología/threads RAC más amplio (`# 34`).

# Confidence model

`OBSERVATION` para el placement leído; `PROBABLE_CAUSE` sólo con evidencia de diseño declarado que contradiga el estado actual.

# Severity

`MISMATCH` en producción sin explicación → `HIGH`.

# Output schema

```yaml
pdb_rac_placement:
  - pdb_token: string
    configured_instances: [string]|null
    actual_open_instances: [string]|null
    service_instances: [string]|null
    placement_status: MATCHES_DESIGN|PARTIAL|MISMATCH|INSUFFICIENT_EVIDENCE
    evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-services`, `multitenant/pdb-open-mode`.

# Escalation

`MISMATCH` crítico → delega a `oracle-rac-analyst` con evidence_refs; si afecta disponibilidad → `incident-root-cause-analyst`.

# Manual remediation guidance

Apertura de PDB en una instancia específica se entrega vía Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

`pdb_token`/nombres de instancia tokenizados.

# Tests

`tests/test_pdb_rac_open_state.sh`, `tests/test_pdb_service_instance_distribution.sh`, `tests/test_pdb_not_required_on_all_instances.sh`, `tests/test_pdb_rac_delegation.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
