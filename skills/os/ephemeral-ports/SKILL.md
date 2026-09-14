---
name: ephemeral-ports
id: os/ephemeral-ports
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza `net.ipv4.ip_local_port_range` (Linux)/equivalentes, reserva de puertos y presión de
`TIME_WAIT` cuando observable — correlaciona con `ORA-27530`/`ORA-27501`/`ORA-27300`, RAC y
churn de conexiones de cliente. Nunca cambia el rango automáticamente.

# Supported Oracle versions

N/A directo — cualquier versión puede agotar puertos efímeros bajo alta concurrencia de
conexiones/reconexiones.

# Supported OS/platforms

Linux (`sysctl -n net.ipv4.ip_local_port_range`): `SUPPORTED`. Solaris (`ndd`/`ipadm`
equivalente): `SUPPORTED`. Windows (`netsh int ipv4 show dynamicport`, vía collector):
`SUPPORTED`.

# Supported architectures

Standalone y RAC (interconnect y conexiones cliente-servidor ambas consumen puertos efímeros).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_ephemeral_port_range`

# Optional evidence

- collector `get_socket_summary` (conteo de sockets en `TIME_WAIT`, ya certificado desde Fase 4)

# Read-only operations

Lectura de rango de puertos y resumen de sockets vía collector semántico.

# Forbidden operations

Nunca cambia `ip_local_port_range` ni ningún rango de puertos.

# Decision logic

1. Reportar el rango configurado y su amplitud (`range_size = max - min`).
2. Rango estrecho (`< 28232` es el default histórico en muchos Linux, pero el umbral real
   depende del volumen de conexiones esperado — nunca un umbral fijo sin contexto) correlacionado
   con alto churn de conexiones (connection pooling mal configurado, sin pooling en cliente) →
   `MEDIUM`/`HIGH`.
3. Correlacionar con errores conocidos: `ORA-27530` (no se pudo crear thread OS — puede incluir
   agotamiento de recursos de socket), `ORA-27501`/`ORA-27300` (fallo de proceso spawn,
   correlación indirecta con presión de recursos del host) — nunca atribuir el error
   automáticamente a puertos efímeros sin evidencia de `TIME_WAIT`/agotamiento real.
4. En RAC, correlacionar con `os/rac-interconnect-awareness` — interconnect y conexiones cliente
   compiten por el mismo pool de puertos efímeros del host.

# Normal state

Rango amplio con bajo conteo de sockets en `TIME_WAIT`, sin errores de agotamiento reportados.

# Abnormal patterns

Rango estrecho + alto conteo de `TIME_WAIT` + errores `ORA-27530`/`27501`/`27300` correlacionados
temporalmente.

# False positives

Rango "estrecho" según un valor por defecto histórico, sin evidencia de agotamiento real
(`TIME_WAIT` bajo, sin errores), no es un hallazgo.

# Correlation rules

Alimenta `os/tcp-socket-awareness`, `os/rac-interconnect-awareness`,
`oracle-network-analyst`/`oracle-rac-analyst` (vía escalada).

# Confidence model

`FACT` para rango leído directamente. `PROBABLE_CAUSE` cuando agotamiento correlaciona
temporalmente con errores `ORA-*` reportados.

# Severity

`HIGH` con evidencia de agotamiento real + errores correlacionados; `LOW`/`INFO` sin esa
correlación.

# Output schema

```yaml
ephemeral_ports:
  range_min: int|null
  range_max: int|null
  range_size: int|null
  time_wait_count: int|null
  known_errors_correlated: [string]
  findings: [{observation: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/tcp-socket-awareness`, `os/rac-interconnect-awareness`.

# Escalation

Agotamiento confirmado escala a `oracle-network-analyst`/`oracle-rac-analyst`.

# Manual remediation guidance

`manual_action` sugiere ampliar `ip_local_port_range` vía `sysctl` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_ephemeral_port_range.sh`, `tests/test_ephemeral_port_rac_awareness.sh`,
`tests/test_no_network_change_execution.sh`.

# Documentation requirements

Alimenta `network.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
