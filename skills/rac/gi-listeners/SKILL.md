---
name: gi-listeners
id: rac/gi-listeners
version: 1.0.0
domain: rac
status: active
---

# Purpose

Estado del recurso Clusterware "local listener" por nodo (`srvctl status listener`) — ONLINE/OFFLINE a nivel recurso. La configuración de registro de servicio/handlers/protocolo es responsabilidad de `network/listeners` (`oracle-network-analyst`) — ver boundary en `AGENT.md`.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/topology` resuelto.

# Required evidence

- collector `get_listener_configuration` (`srvctl status listener`)

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `srvctl status listener`.

# Forbidden operations

No reinicia el listener (`srvctl stop/start listener` prohibido).

# Decision logic

1. Confirmar estado ONLINE del recurso listener local en cada nodo.
2. Listener OFFLINE en un nodo con instancia activa → `HIGH`, remite a `network/listeners` para diagnóstico de causa.

# Confidence model

`FACT` para el estado leído directamente.

# Output schema

```yaml
findings:
  - node: string
    listener_resource_status: string
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-scan`, `network/local-listener`, `network/listeners`.

# Escalation

Listener OFFLINE con instancia activa en el mismo nodo → delega a `oracle-network-analyst` para diagnóstico de causa.

# Data sensitivity

Media.

# Context budget

Bajo.

# Tests

`tests/test_no_listener_stop.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

N/A — comando estable desde 11gR2.
