---
name: gi-node-status
id: rac/gi-node-status
version: 1.0.0
domain: rac
status: active
---

# Purpose

Confirmar que el stack Clusterware está activo en cada nodo (`crsctl check cluster -all`/`crsctl check crs`) — distinto de `rac/node-membership` (¿es miembro?): este skill responde ¿el stack CRS está corriendo en ese nodo ahora?

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/node-membership` resuelto.

# Required evidence

- collector `get_cluster_nodes` extendido con `crsctl check cluster -all`/`crsctl check crs` por nodo.

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `crsctl check cluster -all`/`crsctl check crs`.

# Forbidden operations

No inicia/detiene el stack CRS (`crsctl start/stop crs` prohibido).

# Decision logic

1. Por nodo, confirmar `CRS-4537`/`CRS-4529`/`CRS-4533` (todos los daemons UP) o el equivalente moderno.
2. Un nodo miembro (`rac/node-membership`) con stack CRS no completamente UP → `HIGH`, candidato a `incident-root-cause-analyst`.

# Confidence model

`FACT` para el estado del stack leído directamente.

# Output schema

```yaml
findings:
  - node: string
    crs_stack_status: string
    all_daemons_up: bool
    evidence_refs: [EVD-...]
```

# Related skills

`rac/node-membership`, `rac/topology`, `rac/cluster-resources`.

# Escalation

Stack CRS no completamente UP en un nodo miembro → `incident-root-cause-analyst`, severity `HIGH`.

# Data sensitivity

Media — nombres de nodo enmascarados.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_no_crsctl_modify.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

Nuevos códigos CRS-4xxx por versión vía `/change compatibility`.
