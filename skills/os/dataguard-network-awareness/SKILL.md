---
name: dataguard-network-awareness
id: os/dataguard-network-awareness
version: 1.0.0
domain: os
status: active
---

# Purpose

Correlaciona evidencia OS/red (routing, DNS, socket pressure, buffers TCP) con transport lag/
timeouts reportados por `oracle-dataguard-analyst` — nunca ejecuta cambios.

# Supported Oracle versions

N/A directo — Data Guard existe desde 10g.

# Supported OS/platforms

Linux/Solaris/Windows: `SUPPORTED`.

# Supported architectures

Standalone y RAC (por sitio primary/standby).

# Prerequisites

`os/routing`, `os/dns`, `os/tcp-socket-awareness` ya ejecutados.

# Required evidence

- evidencia de `os/routing`, `os/dns`, `os/tcp-socket-awareness` para el destino
  primary/standby declarado

# Optional evidence

- `os/time-sync` (desync severo puede confundir análisis de lag)

# Read-only operations

Ninguna adicional — consolida evidencia ya recolectada.

# Forbidden operations

Nunca modifica routing/DNS/firewall entre sitios (`# 48` del prompt).

# Decision logic

1. Confirmar ruta y resolución DNS válidas hacia el `db_unique_name` del sitio remoto (primary o
   standby, según el rol del host analizado) — ausencia de ruta/resolución es causa directa de
   transport failure, reportado con `HIGH`.
2. `rmem`/`wmem` insuficientes correlacionados con lag de transporte sostenido sobre WAN de alta
   latencia → `MEDIUM`/`HIGH`, correlación con `oracle-dataguard-analyst`.
3. Nunca concluir que la causa del lag es de red sin al menos un hallazgo OS concreto — si
   routing/DNS/socket están sanos, el lag se reporta como fuera del alcance de este skill,
   dejando la investigación de causa a `oracle-dataguard-analyst` (posible causa de aplicación:
   apply lag, no transport lag).

# Normal state

Ruta y DNS válidos hacia el sitio remoto, buffers TCP suficientes para el volumen de redo
esperado.

# Abnormal patterns

Ruta/DNS faltante hacia el sitio remoto, buffers insuficientes correlacionados con lag
sostenido.

# False positives

Lag de aplicación (apply lag) en el standby no es un hallazgo de este skill — es competencia de
`oracle-dataguard-analyst`, nunca atribuido a la red sin evidencia de transport lag específica.

# Correlation rules

Consolida `os/routing`, `os/dns`, `os/tcp-socket-awareness`, `os/time-sync`. Alimenta
`oracle-dataguard-analyst`.

# Confidence model

`PROBABLE_CAUSE` cuando un hallazgo OS concreto coincide con lag de transporte reportado;
`OBSERVATION` en ausencia de esa correlación.

# Severity

`HIGH` si falta ruta/DNS hacia el sitio remoto.

# Output schema

```yaml
dataguard_network_os:
  route_to_remote_site: present|missing|unknown
  dns_resolution_remote_site: ok|failed|unknown
  tcp_buffer_adequacy: adequate|insufficient|unknown
  findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/routing`, `os/dns`, `os/tcp-socket-awareness`, `os/time-sync`.

# Escalation

Cualquier hallazgo escala a `oracle-dataguard-analyst` con evidence_refs.

# Manual remediation guidance

Consolida las `manual_action` de los skills individuales — siempre `NOT_EXECUTED`.

# Security

Hereda la sanitización de cada skill consolidado (destinos → `TOKENIZE`).

# Tests

`tests/test_os_dataguard_network_awareness.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
