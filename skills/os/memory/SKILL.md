---
name: memory
id: os/memory
version: 2.0.0
domain: os
status: active
---

# Purpose

Evalúa memoria física, disponible, usada, cache y su alineación con el sizing de SGA/PGA. Nunca
interpreta el page cache de Linux como memoria "desperdiciada".

**Fase 9 — reemplaza y absorbe** el skill Foundation `os/linux/memory.md` (única implementación
materializada previa) — su contenido se fusiona aquí como base Linux, ampliado con Windows/
Solaris.

# Supported Oracle versions

N/A directo — aplica a cualquier versión Oracle sobre el host analizado.

# Supported OS/platforms

Linux (`/proc/meminfo` vía collector, `free`): `SUPPORTED`. Solaris (`prtconf`/`kstat`):
`SUPPORTED`. Windows (`get_windows_memory_summary`): `SUPPORTED`.

# Supported architectures

Standalone y RAC (por nodo).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_memory_summary`

# Optional evidence

- collector `get_hugepages_status` (correlación, detalle propio en `os/hugepages`)

# Read-only operations

Lectura de memoria vía collector semántico (`/proc/meminfo`, `free`, `vmstat`, equivalentes).

# Forbidden operations

Nunca ejecuta `sysctl -w`, nunca edita `/etc/sysctl.conf`, nunca modifica configuración de
memoria.

# Decision logic

1. Reportar `physical_memory`, `available_memory`, `used_memory`, `cache`, correlacionado con
   `os/swap`.
2. **Nunca** interpretar `cache`/`buffers` de Linux como memoria "wasted" — page cache se libera
   bajo presión real, no es un indicador de agotamiento por sí solo (`# 14` del prompt).
3. Correlacionar memoria disponible con SGA total configurada (`os/hugepages`) — memoria
   disponible insuficiente para la SGA total es `HIGH`, no sólo `MEDIUM`.

# Normal state

Memoria disponible suficiente para SGA/PGA configuradas + overhead de OS, sin swapping sostenido.

# Abnormal patterns

Memoria disponible por debajo del sizing de SGA total, swap activo sostenido (correlacionar con
`os/swap`/`os/memory-pressure`).

# False positives

Alto uso de `cache`/`buffers` en Linux no es indicador de presión de memoria — sólo `available`
real importa.

# Correlation rules

Alimenta `os/swap`, `os/memory-pressure`, `os/hugepages`, `performance` (SGA/PGA sizing).

# Confidence model

`FACT` para métricas leídas directamente. `PROBABLE_CAUSE` cuando memoria insuficiente coincide
temporalmente con degradación reportada por `oracle-performance-analyst`.

# Severity

`HIGH` si memoria disponible < SGA total requerida; `MEDIUM`/`LOW` para presión parcial.

# Output schema

```yaml
memory:
  physical_memory_bytes: int
  available_memory_bytes: int|null
  used_memory_bytes: int|null
  cache_bytes: int|null
  findings: [{metric: string, value: string, severity: string, confidence: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/swap`, `os/memory-pressure`, `os/hugepages`, `os/numa`.

# Escalation

Memoria insuficiente sostenida escala a `oracle-performance-analyst` (impacto) y a
`os/manual-hardening-plan` (dimensionamiento).

# Manual remediation guidance

`manual_action` sugiere aumentar RAM/ajustar SGA — siempre `NOT_EXECUTED`.

# Security

`hostname_token` → MASK por defecto.

# Tests

`tests/test_memory_summary.sh`.

# Documentation requirements

Alimenta `memory-swap.md`.

# Change history

v1.0.0 — Foundation (`os/linux/memory.md`, sólo Linux).
v2.0.0 — Fase 9: fusionado en `os/memory` domain-wide, ampliado con Solaris/Windows.
