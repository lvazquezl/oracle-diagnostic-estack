---
name: rac-interconnect-awareness
id: os/rac-interconnect-awareness
version: 1.0.0
domain: os
status: active
---

# Purpose

Consolida evidencia OS del interconnect RAC — interfaz, bonding, VLAN, MTU, routing, errores de
socket, ephemeral ports, time sync — en un único juicio para `oracle-rac-analyst`. Nunca modifica
GI/red.

# Supported Oracle versions

11gR2+ (arquitectura RAC moderna con interconnect dedicado certificado).

# Supported OS/platforms

Linux/Solaris: `SUPPORTED`. Windows: `PARTIALLY_SUPPORTED` (RAC en Windows existe pero con menor
profundidad de collector en esta fase).

# Supported architectures

RAC/RAC One Node exclusivamente.

# Prerequisites

`os/network-interfaces`, `os/bonding`, `os/vlan`, `os/mtu`, `os/routing`, `os/ephemeral-ports`,
`os/time-sync` ya ejecutados.

# Required evidence

- evidencia consolidada de los 7 skills de red/tiempo listados arriba, acotada a la(s)
  interfaz(ces) del interconnect

# Optional evidence

- historial de `link_failures` de `os/bonding`

# Read-only operations

Ninguna adicional — consolida evidencia ya recolectada.

# Forbidden operations

Nunca modifica bonding/VLAN/MTU/routing/firewall/sysctl del interconnect (`# 47` del prompt).

# Decision logic

1. Consolidar mismatch de MTU entre nodos, slaves de bond degradados, VLAN inconsistente, ruta
   faltante entre nodos, ephemeral ports agotados, o desync de tiempo — cualquiera de estos por
   sí solo ya es reportado por su skill individual; este skill agrega el **juicio combinado**
   sobre el interconnect específicamente.
2. Reportar a `oracle-rac-analyst` con `evidence_refs` a cada skill individual — nunca duplica
   la evidencia cruda, sólo el juicio consolidado.
3. Nunca asume que un síntoma de Cache Fusion degradado es causado por el OS sin al menos un
   hallazgo concreto de los skills consolidados — si todos están `HEALTHY`, este skill reporta
   `capability_status: SUPPORTED` con `interconnect_os_status: HEALTHY`, dejando la investigación
   en manos de `oracle-rac-analyst` (capa Clusterware/Cache Fusion).

# Normal state

Todos los skills consolidados `HEALTHY` para la(s) interfaz(ces) del interconnect.

# Abnormal patterns

Cualquier combinación de mismatch de MTU/VLAN, bond degradado, ruta faltante, agotamiento de
puertos o desync de tiempo en la interfaz del interconnect.

# False positives

Ninguno propio — hereda la disciplina anti-falso-positivo de cada skill consolidado.

# Correlation rules

Consolida `os/network-interfaces`, `os/bonding`, `os/vlan`, `os/mtu`, `os/routing`,
`os/ephemeral-ports`, `os/time-sync`. Alimenta `oracle-rac-analyst`.

# Confidence model

`PROBABLE_CAUSE` cuando un hallazgo OS concreto coincide temporalmente con degradación de Cache
Fusion reportada por `oracle-rac-analyst`; `OBSERVATION` en ausencia de esa correlación.

# Severity

Heredada del hallazgo individual más severo entre los consolidados.

# Output schema

```yaml
rac_interconnect_os:
  interconnect_os_status: HEALTHY|WARNING|DEGRADED|CRITICAL
  contributing_findings: [EVD-...]
  confidence: string
```

# Related skills

`os/network-interfaces`, `os/bonding`, `os/vlan`, `os/mtu`, `os/routing`, `os/ephemeral-ports`,
`os/time-sync`.

# Escalation

Cualquier estado distinto de `HEALTHY` escala a `oracle-rac-analyst` con evidence_refs completos.

# Manual remediation guidance

Consolida las `manual_action` de los skills individuales — siempre `NOT_EXECUTED`.

# Security

Hereda la sanitización de cada skill consolidado.

# Tests

`tests/test_os_rac_interconnect_awareness.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
