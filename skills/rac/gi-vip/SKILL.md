---
name: gi-vip
id: rac/gi-vip
version: 1.0.0
domain: rac
status: active
---

# Purpose

Estado del recurso VIP por nodo (`srvctl config vip`, estado vía `rac/cluster-resources`) — visibilidad de recurso Clusterware únicamente.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/topology` resuelto.

# Required evidence

- collector `get_vip_configuration` (`srvctl config vip`)

# Optional evidence

- `rac/cluster-resources` para el estado ONLINE/OFFLINE del recurso VIP.

# Read-only operations

Ejecución allowlisted de `srvctl config vip`.

# Forbidden operations

No modifica configuración de VIP.

# Decision logic

1. Leer IP/subnet configurada del VIP por nodo.
2. Cruzar con `rac/cluster-resources` para el estado actual (ONLINE en el nodo esperado, o relocalizado a otro nodo tras un failover del nodo original).
3. VIP relocalizado a otro nodo sin evento de nodo caído conocido → observación, correlacionar con `rac/instance-eviction`.

# Confidence model

`FACT` para configuración/estado leído directamente.

# Output schema

```yaml
findings:
  - node: string
    vip_configured_ip: string      # MASK
    current_status: string
    current_node: string
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-scan`, `rac/cluster-resources`, `rac/instance-eviction`.

# Escalation

VIP relocalizado sin evento conocido de nodo caído → `incident-root-cause-analyst`.

# Data sensitivity

Alta — IPs se enmascaran por defecto.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_no_network_change.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

N/A — comando estable desde 11gR2.
