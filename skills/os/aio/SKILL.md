---
name: aio
id: os/aio
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza `fs.aio-max-nr` y, cuando observable de forma segura, el uso actual de AIO — detecta
riesgo de agotamiento sin modificar el parámetro.

# Supported Oracle versions

N/A directo — relevante para `disk_asynch_io=TRUE` (default en Linux moderno) en cualquier
versión.

# Supported OS/platforms

Linux (`sysctl -n fs.aio-max-nr`): `SUPPORTED`. Solaris (mecanismo de AIO distinto —
awareness): `PARTIALLY_SUPPORTED`. Windows: `NOT_APPLICABLE` (usa IOCP, no AIO POSIX).

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_aio_limits` (`fs.aio-max-nr`)

# Optional evidence

- uso actual de contextos AIO si observable de forma segura (`/proc/sys/fs/aio-nr`, sólo lectura)

# Read-only operations

Lectura de `sysctl -n fs.aio-max-nr`/`/proc/sys/fs/aio-nr` allowlisted.

# Forbidden operations

Nunca ejecuta `sysctl -w`, nunca modifica `disk_asynch_io` (parámetro Oracle, fuera de este
skill de todas formas).

# Decision logic

1. Reportar `aio-max-nr` configurado y, si disponible, `aio-nr` actual (contextos en uso).
2. `aio-nr` cerca de `aio-max-nr` (>80%) → `MEDIUM`/`HIGH` según margen — riesgo de fallos de
   I/O asíncrono bajo carga (`EAGAIN` a nivel de syscall, degradación silenciosa de performance
   si Oracle cae a I/O síncrono).
3. Múltiples instancias/ASM en el mismo host consumen contextos AIO compartidos — correlacionar
   antes de atribuir el consumo a una sola instancia.

# Normal state

`aio-nr` con margen amplio bajo `aio-max-nr`.

# Abnormal patterns

`aio-nr` cerca del límite, especialmente con múltiples instancias/ASM de alta concurrencia de
I/O.

# False positives

`aio-max-nr` "bajo" según una cifra genérica no es un hallazgo si el uso actual está muy por
debajo — sólo el uso real importa.

# Correlation rules

Alimenta `os/io-performance`.

# Confidence model

`FACT` para valores leídos directamente.

# Severity

`HIGH` si `aio-nr` > 95% de `aio-max-nr`; `MEDIUM` > 80%.

# Output schema

```yaml
aio:
  aio_max_nr: int|null
  aio_nr_current: int|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/io-performance`, `os/shared-memory`.

# Escalation

Riesgo de agotamiento escala a `os/manual-hardening-plan`.

# Manual remediation guidance

`manual_action` sugiere `sysctl -w fs.aio-max-nr=...` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_aio_limits.sh`, `tests/test_no_sysctl_execution.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
