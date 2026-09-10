---
name: application-containers
id: multitenant/application-containers
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Awareness de Application Containers (application root, application PDB, application seed) para versiones que los soportan — topología únicamente, nunca lifecycle/write operations (`# 28` del prompt de Fase 6).

# Supported Oracle versions

12.2–23ai (Application Containers introducidos en 12.2, junto con Local Undo — no existen en 12.1).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/pdb-inventory` resuelto.

# Required evidence

- `Q-CDB-PDB-STATE-001` (`V$PDBS.application_root`/`application_pdb`/`application_seed`, variante 12.2+)

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

Nunca crea/instala/actualiza/desinstala una application — sólo visibilidad de topología.

# Decision logic

1. Clasificar cada contenedor: `APPLICATION_ROOT`/`APPLICATION_PDB`/`APPLICATION_SEED` según los flags de `V$PDBS`.
2. Si el catálogo no certifica el detalle completo de sincronización de la application (versión instalada, estado de sync), declarar `capability_status: PARTIALLY_SUPPORTED` — nunca fingir soporte completo (`# 28`, `# 80`).

# Normal state

Topología de Application Containers consistente con el diseño (roots con sus PDBs asociadas).

# Abnormal patterns

Una PDB reportando `application_pdb=YES` sin un `application_root` correspondiente visible — posible desincronización de topología.

# False positives

Ninguno — es visibilidad directa de flags reales.

# Correlation rules

Correlaciona con `multitenant/proxy-pdb` cuando ambos flags coexisten en el mismo análisis.

# Confidence model

`FACT` para los flags leídos directamente.

# Severity

N/A — awareness informativo; una desincronización real se reporta `MEDIUM` si afecta a la aplicación.

# Output schema

```yaml
application_containers:
  - container_token: string
    role: APPLICATION_ROOT|APPLICATION_PDB|APPLICATION_SEED
    evidence_refs: [EVD-...]
capability_status: SUPPORTED|PARTIALLY_SUPPORTED
```

# Related skills

`multitenant/proxy-pdb`, `multitenant/pdb-inventory`.

# Escalation

N/A salvo desincronización con impacto reportado por el DBA.

# Manual remediation guidance

Sincronización de application se entrega vía Manual Action Contract sólo si el DBA lo solicita, `execution_status: NOT_EXECUTED`.

# Security

`container_token` tokenizado.

# Tests

`tests/test_21c_application_container_awareness.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/cdb-topology.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
