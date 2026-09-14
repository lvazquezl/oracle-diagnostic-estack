---
name: vlan
id: os/vlan
version: 1.0.0
domain: os
status: active
---

# Purpose

Detecta VLAN ID, interfaz padre, estado y MTU de interfaces VLAN — correlaciona con errores de
GI/interconnect. Nunca crea una VLAN.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`ip -d link show`, formato `<if>.<vlan>`): `SUPPORTED`. Solaris (`dladm show-vlan`):
`SUPPORTED`. Windows: `PARTIALLY_SUPPORTED`.

# Supported architectures

Standalone y RAC (interconnect frecuentemente segmentado por VLAN dedicada).

# Prerequisites

`os/network-interfaces` ya ejecutado.

# Required evidence

- collector `get_vlan_summary`

# Optional evidence

Ninguna.

# Read-only operations

Lectura de configuración VLAN vía collector semántico.

# Forbidden operations

Nunca crea/modifica/elimina una VLAN.

# Decision logic

1. Reportar `vlan_id`, interfaz padre, estado, MTU de la interfaz VLAN.
2. Mismatch de `vlan_id`/MTU entre nodos RAC en la misma red lógica (interconnect/pública) →
   `HIGH` — causa documentada de errores de comunicación intermitentes.
3. Correlacionar con `os/mtu` — MTU inconsistente en una VLAN es un hallazgo de ambos skills,
   reportado una sola vez con referencia cruzada, nunca duplicado.

# Normal state

VLAN ID/MTU consistentes entre todos los nodos que comparten la misma red lógica.

# Abnormal patterns

Mismatch de VLAN ID o MTU entre nodos, interfaz VLAN sin interfaz padre activa.

# False positives

Ninguno conocido cuando la comparación es entre nodos que realmente deberían compartir
configuración.

# Correlation rules

Alimenta `os/mtu`, `os/rac-interconnect-awareness`.

# Confidence model

`FACT` para configuración leída directamente.

# Severity

`HIGH` si hay mismatch entre nodos RAC en la misma red lógica.

# Output schema

```yaml
vlan:
  - interface: string
    vlan_id: int|null
    parent_interface: string|null
    state: up|down
    mtu: int|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/network-interfaces`, `os/mtu`, `os/rac-interconnect-awareness`.

# Escalation

Mismatch entre nodos RAC escala a `oracle-rac-analyst`.

# Manual remediation guidance

`manual_action` para intervención de red — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_vlan_awareness.sh`, `tests/test_no_network_change_execution.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
