---
name: gi-cluster-health
id: rac/gi-cluster-health
version: 1.0.0
domain: rac
status: active
---

# Purpose

`crsctl check cluster`/`crsctl check crs` a nivel cluster completo — señal rápida de salud global de Clusterware, complementaria (no sustituta) del detalle por nodo de `rac/gi-node-status`.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_cluster_nodes` extendido con `crsctl check cluster`

# Optional evidence

- `rac/cluster-resources` para detalle si la señal global reporta anomalía.

# Read-only operations

Ejecución allowlisted de `crsctl check cluster`.

# Forbidden operations

No inicia/detiene el cluster.

# Decision logic

1. Leer la señal global de salud.
2. Si reporta anomalía, delega el detalle a `rac/gi-node-status`/`rac/cluster-resources` — este skill no reconstruye ese análisis.

# Confidence model

`FACT` para la señal leída directamente.

# Output schema

```yaml
findings:
  - cluster_health_signal: string
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-node-status`, `rac/cluster-resources`, `rac/healthcheck`.

# Escalation

Señal global anómala → detalle vía `rac/gi-node-status`/`rac/cluster-resources`, luego `incident-root-cause-analyst` si corresponde.

# Data sensitivity

Media.

# Context budget

Media.

# Tests

`tests/test_no_crsctl_modify.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

N/A — comando estable desde 11gR2.
