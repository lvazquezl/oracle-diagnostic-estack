---
name: interconnect
id: network/interconnect
version: 1.0.0
domain: network
status: active
---

# Purpose

Evidencia de interconnect a nivel de red pura del host (interfaz/bonding/VLAN vía collectors OS) — complementa `rac/interconnect` (que correlaciona con `GV$CLUSTER_INTERCONNECTS`/Cache Fusion). Este skill es el que `oracle-network-analyst` usa cuando delega hacia/recibe de `os-platform-analyst`.

# Supported Oracle versions

11gR2–23ai (interconnect dedicado es un concepto RAC).

# Supported OS/platforms

Todas — evidencia obtenida vía `os-platform-analyst`.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/interconnect` ya identificó una posible discrepancia de interfaz.

# Required evidence

- collector `get_interfaces` (vía `os-platform-analyst`: `ip`/equivalente por plataforma, allowlisted)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de configuración de interfaz/bonding/VLAN a nivel OS.

# Forbidden operations

No cambia bonding, VLAN, route, MTU, firewall ni sysctl (`# 34` del prompt de Fase 4).

# Decision logic

1. Confirmar bonding/VLAN/MTU de la interfaz declarada como interconnect.
2. Cruzar contra lo que `rac/interconnect` reportó como activo en Oracle — una discrepancia aquí es la evidencia que faltaba para escalar de `HYPOTHESIS` a `PROBABLE_CAUSE` en `rac/interconnect`.

# Confidence model

`FACT` para configuración OS leída directamente.

# Output schema

```yaml
findings:
  - interface: string
    bonding_mode: string|null
    vlan: string|null
    mtu: number|null
    evidence_refs: [EVD-...]
```

# Related skills

`rac/interconnect`, `rac/gi-network-interfaces`.

# Escalation

Discrepancia confirmada (MTU mismatch, bonding degradado) → recomendación manual al equipo de red/sysadmin, nunca corregida automáticamente.

# Data sensitivity

Alta — interfaces/VLANs/IPs enmascaradas por defecto.

# Context budget

Media.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_no_network_change.sh`.

# Documentation requirements

Alimenta `network-analysis.md`.

# Evolution via `/change`

Nuevos comandos allowlisted por plataforma vía `/change compatibility`.
