---
name: shared-memory
id: os/shared-memory
version: 1.0.0
domain: os
status: active
---

# Purpose

Evalúa `kernel.shmmax`/`kernel.shmall`/`kernel.shmmni` contra el page size, memoria física real y
los requisitos de SGA de Oracle — nunca usa fórmulas obsoletas de forma universal.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`sysctl -n kernel.shmmax/shmall/shmmni`, lectura): `SUPPORTED`. Solaris (`project`/`rctl`
equivalentes): `PARTIALLY_SUPPORTED`. Windows: `NOT_APPLICABLE`.

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/memory` ya ejecutado (memoria física real).

# Required evidence

- collector `get_ipc_limits` (`shmmax`, `shmall`, `shmmni`)

# Optional evidence

- SGA total del host (de `os/hugepages`)

# Read-only operations

Lectura de `sysctl -n` de claves allowlisted específicas — nunca `sysctl -a` completo ni
concatenación de parámetros no validados.

# Forbidden operations

Nunca ejecuta `sysctl -w`, nunca edita `/etc/sysctl.conf`.

# Decision logic

1. `shmmax` debe ser >= el segmento de shared memory más grande requerido (típicamente el
   tamaño de una SGA individual, no la suma — a diferencia de HugePages) — evaluado contra la SGA
   real de cada instancia, nunca contra una fórmula fija tipo "50% de RAM física" aplicada
   ciegamente (`# 21` del prompt: "No usar fórmulas obsoletas universalmente").
2. `shmall` (en páginas) debe cubrir la suma de todos los segmentos shared memory activos
   simultáneamente — correlacionado con memoria física real, nunca un valor arbitrario.
3. `shmmni` insuficiente (pocos segmentos permitidos) es relevante sólo cuando hay múltiples
   instancias/ASM compartiendo el host — reportado en ese contexto, no genérico.
4. Nota arquitectónica: en releases modernos de Oracle Database, HugePages puede reducir la
   dependencia de `shmmax`/`shmall` tradicional (segmentos respaldados por HugePages se
   gestionan distinto) — el skill correlaciona con `os/hugepages` antes de emitir severidad alta
   por `shmmax` bajo si HugePages ya cubre el caso.

# Normal state

`shmmax`/`shmall` suficientes para la SGA real configurada, sin fórmula genérica aplicada sin
contexto.

# Abnormal patterns

`shmmax` menor al tamaño de SGA de alguna instancia — riesgo real de fallo al iniciar la
instancia (`ORA-27102` u equivalente).

# False positives

`shmmax` "bajo" según una tabla genérica de internet no es un hallazgo si la SGA real está
respaldada por HugePages y el segmento tradicional no es el mecanismo activo.

# Correlation rules

Alimenta `os/semaphores`, `os/hugepages`, `os/kernel-parameter-assessment`.

# Confidence model

`FACT` para valores leídos directamente. `PROBABLE_CAUSE` cuando `shmmax` insuficiente coincide
con fallo de arranque de instancia reportado.

# Severity

`HIGH` si `shmmax` < SGA de alguna instancia activa; `MEDIUM`/`LOW` para márgenes estrechos.

# Output schema

```yaml
shared_memory:
  shmmax_bytes: int|null
  shmall_pages: int|null
  shmmni: int|null
  largest_sga_bytes: int|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/semaphores`, `os/hugepages`, `os/memory`, `os/kernel-parameter-assessment`.

# Escalation

`shmmax` insuficiente escala a `os/manual-hardening-plan`.

# Manual remediation guidance

`manual_action` sugiere `sysctl -w kernel.shmmax=...`/edición de `/etc/sysctl.conf` — siempre
`NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_shared_memory_parameters.sh`, `tests/test_no_sysctl_execution.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
