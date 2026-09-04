---
name: node-membership
id: rac/node-membership
version: 1.0.0
domain: rac
status: active
---

# Purpose

Confirmar qué nodos son miembros activos del cluster Clusterware (independiente de si tienen una instancia de base de datos asociada), vía `olsnodes`.

# Supported Oracle versions

11gR2–23ai (`olsnodes` es un comando GI, no depende de la versión de base de datos individual).

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Ninguno adicional al Target Profile con `cluster_mode` RAC.

# Required evidence

- collector `get_cluster_nodes` (`olsnodes`, ver `docs/GI_READONLY_COLLECTORS.md` y `parsers/rac/olsnodes_parser.py`)

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `olsnodes` (sin flags de cambio) vía collector semántico, nunca shell arbitrario.

# Forbidden operations

No agrega/quita nodos del cluster.

# Decision logic

1. Parsear la lista de nodos y su estado de membership.
2. Cruzar contra `rac/topology` (instancias por nodo) — un nodo miembro sin ninguna instancia asociada se reporta como observación (puede ser GI-only, un nodo de quorum, o una instancia caída).
3. Si `INSUFFICIENT_PRIVILEGES` impide ejecutar el collector, generar `MANUAL COLLECTION INSTRUCTION` — nunca escalar privilegios.

# Confidence model

`FACT` para membership leído directamente. `INSUFFICIENT_EVIDENCE` cuando el collector no puede ejecutarse.

# Output schema

```yaml
findings:
  - node: string
    membership_status: string
    has_db_instance: bool
    evidence_refs: [EVD-...]
```

# Related skills

`rac/topology`, `rac/gi-node-status`, `rac/instance-eviction`.

# Escalation

Nodo esperado pero ausente de la lista de membership → escala a `incident-root-cause-analyst`.

# Data sensitivity

Media — nombres de nodo enmascarados.

# Context budget

Bajo.

# Tests

`tests/test_rac_node_membership.sh`, `tests/test_olsnodes_parser.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

Nuevas opciones de `olsnodes` por versión vía `/change compatibility`.
