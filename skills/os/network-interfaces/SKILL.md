---
name: network-interfaces
id: os/network-interfaces
version: 1.0.0
domain: os
status: active
---

# Purpose

Inventario de interfaces de red: estado, velocidad, duplex, MTU, direcciones (tokenizadas),
membresía de bond/team, VLAN. Formaliza como skill completo el collector `get_interfaces`, ya
certificado desde Fase 4 (`docs/GI_READONLY_COLLECTORS.md#os-network-collectors`, propiedad de
`os-platform-analyst`, invocado por `network/interconnect`/`rac/gi-network-interfaces`).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`ip addr`): `SUPPORTED`. Solaris (`ipadm`/`dladm`): `SUPPORTED`. Windows
(`get_windows_network_summary`): `SUPPORTED`.

# Supported architectures

Standalone y RAC (interconnect + red pública, distinguidas explícitamente).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_interfaces` (ya certificado desde Fase 4 — mismo `collector_id`, nunca duplicado)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `ip addr`/`ipadm`/equivalente vía collector semántico.

# Forbidden operations

Nunca crea/modifica/elimina una interfaz, nunca cambia dirección IP/estado.

# Decision logic

1. Reportar por interfaz: `state` (up/down), `speed`, `duplex` (cuando observable), `mtu`,
   direcciones (tokenizadas por defecto), membresía de bond/team, VLAN.
2. Nunca exponer IP real si la política de sanitización lo requiere (`# 35` del prompt) —
   `TOKENIZE` por defecto salvo autorización explícita del DBA.
3. Interfaz `down` inesperada (no explicada por diseño, ej. NIC de respaldo intencionalmente
   inactiva) → `MEDIUM`/`HIGH` según si es la interfaz del interconnect/pública.

# Normal state

Todas las interfaces esperadas `up`, velocidad/duplex consistentes con el diseño declarado.

# Abnormal patterns

Interfaz `down` no explicada, velocidad/duplex inconsistente (ej. half-duplex inesperado),
asimetría entre nodos RAC.

# False positives

Interfaces de respaldo intencionalmente `down` (failover pasivo) no son un hallazgo si el diseño
lo declara.

# Correlation rules

Alimenta `os/bonding`, `os/vlan`, `os/mtu`, `os/routing`, `os/rac-interconnect-awareness`.

# Confidence model

`FACT` para estado leído directamente.

# Severity

`HIGH` si la interfaz del interconnect/pública está `down`; `MEDIUM`/`LOW` para el resto.

# Output schema

```yaml
network_interfaces:
  - interface: string
    state: up|down
    speed: string|null
    duplex: string|null
    mtu: int|null
    addresses: [string]   # TOKENIZE por defecto
    bond_membership: string|null
    vlan: string|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/bonding`, `os/vlan`, `os/mtu`, `os/routing`, `os/rac-interconnect-awareness`.

# Escalation

Interfaz crítica `down` escala a `oracle-rac-analyst`/`oracle-network-analyst`.

# Manual remediation guidance

`manual_action` para intervención de red — siempre `NOT_EXECUTED`, dirigida al administrador de
red.

# Security

Direcciones IP/MAC → `TOKENIZE` por defecto.

# Tests

`tests/test_network_interfaces.sh`, `tests/test_no_network_change_execution.sh`,
`tests/test_os_ip_tokenization.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial (formaliza `get_interfaces`, collector ya certificado desde
Fase 4).
