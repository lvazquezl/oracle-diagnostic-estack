---
name: architecture
id: multitenant/architecture
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Vista general de la arquitectura Multitenant de un target — CDB$ROOT, número de PDBs, si hay Application Containers presentes, si Local Undo está habilitado — punto de entrada del workflow Multitenant, alimenta el resto de skills sin re-determinar nada por su cuenta.

# Supported Oracle versions

12c–23ai. Nunca se activa en 10g/11g ni sobre un target NON-CDB (`# 6` del prompt de Fase 6).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`target_profile.architecture.multitenant_mode == cdb` ya publicado por `oracle-discovery-analyst`.

# Required evidence

- `Q-CDB-CONTAINERS-001` (`V$CONTAINERS`: topología CDB$ROOT + todas las PDBs)

# Optional evidence

Ninguna — el resto de dimensiones (inventario detallado, servicios, storage) las cubren los skills específicos.

# Licensing requirements

Ninguno — metadata core de arquitectura.

# Query IDs

`Q-CDB-CONTAINERS-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$CONTAINERS`.

# Forbidden operations

No crea/elimina/abre/cierra PDBs.

# Decision logic

1. Confirmar `target_profile.architecture.multitenant_mode == cdb` — nunca re-determinar CDB/NON-CDB por su cuenta, siempre reutilizar el Target Profile (`# 7` del prompt).
2. Contar PDBs (`con_id > 1`) para poblar `pdb_count`.
3. Publicar `architecture.cdb_name`/`root_container`/`pdb_count`/`local_undo_enabled`/`application_containers_present` como resumen inicial para el resto del análisis (no repetido por cada skill downstream).

# Normal state

CDB$ROOT abierto (`OPEN_MODE = READ WRITE`), al menos una PDB visible.

# Abnormal patterns

CDB$ROOT no `READ WRITE` (síntoma severo, correlacionar de inmediato con `multitenant/pdb-state` para CDB$ROOT específicamente).

# False positives

Ninguno específico de este skill — es un resumen, no una evaluación de salud por sí solo.

# Correlation rules

Alimenta todo el resto de skills `multitenant/*` con el resumen de arquitectura — nunca se vuelve a determinar `pdb_count`/`cdb_name` en otro skill.

# Confidence model

`FACT` para todo campo leído directamente de `V$CONTAINERS`.

# Severity

N/A — este skill no reporta findings de severidad, sólo contexto.

# Output schema

```yaml
architecture:
  multitenant_mode: cdb
  cdb_name: string|null
  root_container: string|null
  pdb_count: int
  local_undo_enabled: bool|null
  application_containers_present: bool|null
  evidence_refs: [EVD-...]
```

# Related skills

`multitenant/cdb-discovery`, `multitenant/pdb-inventory`.

# Escalation

N/A.

# Manual remediation guidance

Ninguna — puramente informativo.

# Security

`cdb_name`/`root_container` → MASK por defecto.

# Tests

`tests/test_multitenant_agent_manifest.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/cdb-topology.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
