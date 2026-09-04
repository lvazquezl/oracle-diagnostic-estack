---
name: gi-resource-properties
id: rac/gi-resource-properties
version: 1.0.0
domain: rac
status: active
---

# Purpose

Leer propiedades declaradas de un recurso Clusterware (`crsctl stat res <resource> -p`: `START_DEPENDENCIES`, `STOP_DEPENDENCIES`, `RESTART_ATTEMPTS`, `CHECK_INTERVAL`, etc.) — visibilidad de configuración, nunca modificación.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/gi-resource-status` resuelto para el recurso en cuestión.

# Required evidence

- collector `get_cluster_resources` extendido a `-p` (propiedades) para el recurso solicitado.

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `crsctl stat res <resource> -p`.

# Forbidden operations

No modifica propiedades (`crsctl modify resource` prohibido).

# Decision logic

1. Leer dependencias declaradas del recurso.
2. Correlacionar con `rac/cluster-resources`: si un recurso está `OFFLINE` y su `START_DEPENDENCIES` incluye otro recurso también `OFFLINE`, reportar la dependencia como explicación probable antes de escalar el recurso dependiente por separado.

# Confidence model

`FACT` para propiedades leídas directamente. `PROBABLE_CAUSE` para "OFFLINE por dependencia".

# Output schema

```yaml
findings:
  - resource: string
    start_dependencies: [string]
    stop_dependencies: [string]
    restart_attempts: number
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-resource-status`, `rac/configuration-drift`.

# Escalation

Dependencia rota entre recursos críticos → `incident-root-cause-analyst`.

# Data sensitivity

Media — nombres de recurso enmascarados.

# Context budget

Bajo.

# Tests

`tests/test_no_crsctl_modify.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

Nuevas propiedades por versión vía `/change compatibility`.
