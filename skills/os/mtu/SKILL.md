---
name: mtu
id: os/mtu
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza consistencia de MTU entre interfaz física, bond y VLAN, y entre nodos del interconnect —
nunca recomienda jumbo frames sin evidencia end-to-end.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux/Solaris/Windows: `SUPPORTED` (lectura de MTU es universal en todas las plataformas
soportadas).

# Supported architectures

Standalone y RAC (interconnect es el caso de mayor impacto de un mismatch de MTU).

# Prerequisites

`os/network-interfaces`, `os/bonding`, `os/vlan` ya ejecutados.

# Required evidence

- collector `get_mtu_summary` (o derivado de `os/network-interfaces`/`os/bonding`/`os/vlan`)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de MTU vía collector semántico.

# Forbidden operations

Nunca cambia MTU de ninguna interfaz.

# Decision logic

1. Verificar consistencia de MTU a través de la cadena física → bond → VLAN — un mismatch en
   cualquier capa efectivamente limita el MTU real al valor más bajo (fragmentación silenciosa).
2. Comparar MTU entre nodos del interconnect RAC — mismatch entre nodos es `HIGH`, causa
   documentada de degradación intermitente de Cache Fusion.
3. **Nunca recomendar jumbo frames (`MTU 9000`) sin evidencia end-to-end** de que toda la ruta
   (switch, todos los nodos) lo soporta (`# 38` del prompt) — una recomendación de jumbo frames
   sin esa verificación puede empeorar la situación (fragmentación/pérdida de paquetes).

# Normal state

MTU consistente en toda la cadena física/bond/VLAN y entre todos los nodos relevantes.

# Abnormal patterns

Mismatch de MTU en cualquier capa o entre nodos RAC.

# False positives

MTU 1500 (estándar) en todos los nodos no es un hallazgo — jumbo frames no es un requisito, es
una optimización condicional a evidencia end-to-end.

# Correlation rules

Alimenta `os/rac-interconnect-awareness`.

# Confidence model

`FACT` para MTU leído directamente.

# Severity

`HIGH` si hay mismatch entre nodos del interconnect; `MEDIUM`/`LOW` para mismatch en capas locales
sin impacto reportado.

# Output schema

```yaml
mtu:
  - interface: string
    mtu: int
    layer: physical|bond|vlan
consistency_across_nodes: bool|null
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/network-interfaces`, `os/bonding`, `os/vlan`, `os/rac-interconnect-awareness`.

# Escalation

Mismatch entre nodos escala a `oracle-rac-analyst`.

# Manual remediation guidance

`manual_action` para intervención de red — siempre `NOT_EXECUTED`; jumbo frames sólo se sugiere
tras confirmación explícita de soporte end-to-end en el `manual_action`, nunca por defecto.

# Security

Sin datos sensibles.

# Tests

`tests/test_mtu_awareness.sh`, `tests/test_no_network_change_execution.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
