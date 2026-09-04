---
name: gi-scan
id: rac/gi-scan
version: 1.0.0
domain: rac
status: active
---

# Purpose

Estado del recurso Clusterware SCAN/SCAN listener (`srvctl status scan`/`srvctl config scan`) — **estado del recurso**, no resolución DNS ni registro de servicio (eso es `network/scan`/`network/scan-resolution`, propiedad de `oracle-network-analyst`). Ver boundary explícito en `agents/oracle-rac-analyst/AGENT.md#gi-workflow`.

# Supported Oracle versions

11gR2–23ai (SCAN no existe pre-11gR2).

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_scan_configuration` (`srvctl config scan`, `srvctl status scan`, `srvctl config scan_listener`, `srvctl status scan_listener`)

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `srvctl config/status scan`/`scan_listener`.

# Forbidden operations

No modifica configuración de SCAN (`srvctl modify scan` prohibido).

# Decision logic

1. Leer SCAN name, IPs configuradas, y estado ONLINE/OFFLINE de cada SCAN listener.
2. Si algún SCAN listener está OFFLINE, reportar `HIGH` — reduce la disponibilidad de conexión aunque no la elimina totalmente (los demás SCAN listeners siguen sirviendo).
3. Nunca resuelve DNS ni valida registro de servicio aquí — eso se delega explícitamente a `network/scan-resolution`/`network/service-registration`.

# Confidence model

`FACT` para el estado del recurso leído directamente.

# Output schema

```yaml
findings:
  - scan_name: string
    configured_ips: [string]
    scan_listeners: [{listener: string, status: string, node: string}]
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-vip`, `rac/gi-listeners`, `network/scan`, `network/scan-resolution` (dominio de `oracle-network-analyst`, citado por referencia, nunca reconstruido).

# Escalation

SCAN listener OFFLINE inesperado → `incident-root-cause-analyst`.

# Data sensitivity

Alta — SCAN name/IPs se enmascaran por defecto.

# Context budget

Bajo.

# Tests

`tests/test_srvctl_scan_parser.sh`, `tests/test_no_srvctl_modify_execution.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

N/A — comando estable desde 11gR2.
