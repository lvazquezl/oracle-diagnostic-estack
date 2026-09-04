---
name: gi-resource-status
id: rac/gi-resource-status
version: 1.0.0
domain: rac
status: active
---

# Purpose

Drill-down de estado de **un recurso Clusterware específico** solicitado por nombre — reutiliza la misma evidencia de `rac/cluster-resources` (`crsctl stat res -t`) filtrada, sin query/collector propio, cuando el DBA pregunta por un recurso puntual en vez del resumen del cluster.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/cluster-resources` resuelto; requiere `resource_name` como parámetro.

# Required evidence

- collector `get_cluster_resources` (mismo que `rac/cluster-resources`), filtrado al `resource_name` solicitado.

# Optional evidence

Ninguna.

# Read-only operations

Lectura ya cubierta por `rac/cluster-resources`.

# Forbidden operations

No modifica el recurso.

# Decision logic

1. Filtrar la evidencia ya recolectada al `resource_name` solicitado.
2. Reportar `state`, `target`, `server` de cada instancia del recurso (algunos recursos son per-node).

# Confidence model

`FACT` para el estado leído directamente.

# Output schema

```yaml
findings:
  - resource: string
    instances: [{server: string, state: string, target: string}]
    evidence_refs: [EVD-...]
```

# Related skills

`rac/cluster-resources`, `rac/gi-resource-properties`.

# Escalation

Igual que `rac/cluster-resources`, acotado al recurso solicitado.

# Data sensitivity

Media — nombres de recurso/servidor enmascarados.

# Context budget

Bajo — un único recurso.

# Tests

`tests/test_crsctl_resource_parser.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md` cuando el análisis es específico de un recurso.

# Evolution via `/change`

Ninguna evolución propia — hereda la de `rac/cluster-resources`.
