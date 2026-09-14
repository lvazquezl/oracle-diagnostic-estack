---
name: tcp-socket-awareness
id: os/tcp-socket-awareness
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza únicamente los parámetros TCP/socket relevantes a Oracle (`somaxconn`,
`tcp_max_syn_backlog`, `net.core.rmem/wmem_default/max`) — deliberadamente NO se convierte en
tuning genérico de red (`# 28` del prompt).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`sysctl -n`, `ss`/`get_socket_summary` ya certificado desde Fase 4): `SUPPORTED`. Solaris:
`PARTIALLY_SUPPORTED`. Windows: `PARTIALLY_SUPPORTED` (parámetros TCP equivalentes vía registro,
awareness únicamente).

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_socket_summary` (ya certificado desde Fase 4, `docs/GI_READONLY_COLLECTORS.md`)

# Optional evidence

- `somaxconn`, `tcp_max_syn_backlog`, `rmem`/`wmem` (`sysctl -n` allowlisted)

# Read-only operations

Lectura de `ss`/`sysctl -n` de claves específicas allowlisted — nunca `sysctl -a` completo.

# Forbidden operations

Nunca modifica ningún parámetro TCP.

# Decision logic

1. Reportar sólo el subconjunto de parámetros con impacto documentado en conexiones Oracle
   (listener backlog, buffers de red para Data Guard/RMAN sobre red) — deliberadamente acotado,
   nunca un dump completo de tuning TCP genérico (`# 28`).
2. `somaxconn`/`tcp_max_syn_backlog` bajo correlacionado con `LISTENER` rechazando conexiones
   bajo carga alta → `MEDIUM`/`HIGH`, correlacionado con `oracle-network-analyst`.
3. `rmem`/`wmem` bajos correlacionados con throughput insuficiente en transporte de redo Data
   Guard sobre WAN → correlación con `os/dataguard-network-awareness`, nunca conclusión aislada.

# Normal state

Parámetros dentro de rangos consistentes con la carga de conexiones/transporte observada.

# Abnormal patterns

`somaxconn` bajo con `LISTENER` rechazando conexiones bajo pico de carga; `rmem`/`wmem`
insuficientes con degradación de transporte Data Guard reportada.

# False positives

Ninguno propio cuando la correlación con el síntoma reportado es explícita.

# Correlation rules

Alimenta `os/ephemeral-ports`, `os/dataguard-network-awareness`, `oracle-network-analyst`.

# Confidence model

`FACT` para parámetros leídos. `PROBABLE_CAUSE` cuando correlaciona con síntoma reportado.

# Severity

`MEDIUM`/`HIGH` según correlación con síntoma real — nunca alta sin esa correlación.

# Output schema

```yaml
tcp_socket:
  somaxconn: int|null
  tcp_max_syn_backlog: int|null
  rmem_default: int|null
  rmem_max: int|null
  wmem_default: int|null
  wmem_max: int|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/ephemeral-ports`, `os/network-interfaces`, `os/dataguard-network-awareness`.

# Escalation

Correlación con LISTENER/Data Guard escala al agente Oracle correspondiente.

# Manual remediation guidance

`manual_action` sugiere ajustar el parámetro vía `sysctl` — siempre `NOT_EXECUTED`.

# Security

`socket_summary` nunca expone IPs de cliente sin tokenizar.

# Tests

`tests/test_network_interfaces.sh`, `tests/test_no_network_change_execution.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
