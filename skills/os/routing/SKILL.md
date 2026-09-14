---
name: routing
id: os/routing
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza ruta por defecto y rutas específicas relevantes (asociación con interfaz) — formaliza
como skill completo el collector `get_routes`, ya certificado desde Fase 4
(`docs/GI_READONLY_COLLECTORS.md#os-network-collectors`).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`ip route`): `SUPPORTED`. Solaris (`netstat -rn`): `SUPPORTED`. Windows (`route print`
vía collector): `SUPPORTED`.

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/network-interfaces` ya ejecutado.

# Required evidence

- collector `get_routes` (ya certificado desde Fase 4 — mismo `collector_id`, nunca duplicado)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de tabla de rutas vía collector semántico.

# Forbidden operations

Nunca modifica rutas.

# Decision logic

1. Reportar ruta por defecto y su interfaz asociada, más rutas específicas relevantes a
   destinos Oracle conocidos (standby Data Guard, SCAN de otro cluster) cuando el Target Profile
   los declare.
2. Ausencia de ruta hacia un destino Data Guard/RAC conocido → `HIGH`, correlacionado con
   `os/dataguard-network-awareness`/`oracle-rac-analyst`.
3. Ruta por defecto ausente o apuntando a una interfaz inesperada → `MEDIUM`/`HIGH` según el
   contexto.

# Normal state

Ruta por defecto presente y consistente, rutas específicas hacia destinos Oracle conocidos
presentes.

# Abnormal patterns

Ruta ausente hacia un destino Data Guard/RAC conocido, ruta por defecto en interfaz inesperada.

# False positives

Ausencia de una ruta específica no declarada en el Target Profile no es un hallazgo — nunca se
inventa un destino esperado.

# Correlation rules

Alimenta `os/dataguard-network-awareness`, `os/rac-interconnect-awareness`.

# Confidence model

`FACT` para tabla de rutas leída directamente.

# Severity

`HIGH` si falta ruta hacia un destino Data Guard/RAC conocido y declarado.

# Output schema

```yaml
routing:
  default_route: {gateway: string, interface: string}|null   # TOKENIZE
  specific_routes: [{destination: string, interface: string}]   # TOKENIZE
findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/network-interfaces`, `os/dataguard-network-awareness`, `os/rac-interconnect-awareness`.

# Escalation

Ruta faltante hacia destino Oracle conocido escala al agente correspondiente.

# Manual remediation guidance

`manual_action` para intervención de red — siempre `NOT_EXECUTED`.

# Security

Gateways/destinos → `TOKENIZE` por defecto.

# Tests

`tests/test_routing_awareness.sh`, `tests/test_no_network_change_execution.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial (formaliza `get_routes`, collector ya certificado desde
Fase 4).
