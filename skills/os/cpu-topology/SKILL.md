---
name: cpu-topology
id: os/cpu-topology
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza CPUs lógicas, cores físicos, sockets, threads/core, arquitectura y estado online/offline
— correlaciona con `cpu_count`/paralelismo Oracle, colocación de instancias RAC y virtualización.
Nunca cambia CPU affinity.

# Supported Oracle versions

N/A directo — correlaciona con `V$PARAMETER.cpu_count`/`parallel_max_servers` de cualquier
versión.

# Supported OS/platforms

Linux (`lscpu`): `SUPPORTED`. Solaris (`psrinfo`): `SUPPORTED`. Windows
(`get_windows_cpu_topology`): `SUPPORTED`.

# Supported architectures

Standalone y RAC (por nodo — topología puede diferir entre nodos).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_cpu_topology` (Linux: `lscpu`; Solaris: `psrinfo -pv`; Windows:
  `get_windows_cpu_topology`)

# Optional evidence

- `V$PARAMETER.cpu_count`/`parallel_max_servers` (delegado a `oracle-performance-analyst` para
  correlación, nunca re-consultado por este skill)

# Read-only operations

Lectura de topología de CPU vía collector semántico.

# Forbidden operations

Nunca cambia CPU affinity, nunca offline/online un CPU.

# Decision logic

1. Reportar `logical_cpus`, `physical_cores`, `sockets`, `threads_per_core`, `numa_nodes`
   (referencia cruzada a `os/numa`), `architecture`, `cpu_online`/`cpu_offline` cuando aplique.
2. Correlacionar `logical_cpus` con `cpu_count` de Oracle — un `cpu_count` mayor al real es un
   finding (`MEDIUM`, licencia/parallelism mal dimensionado), nunca asumido intencional sin
   contexto.
3. En virtualización (vCPU vs. pCPU), reportar la distinción cuando sea observable — nunca tratar
   vCPU como equivalente 1:1 a core físico sin evidencia del hypervisor.

# Normal state

`logical_cpus` consistente con `cpu_count`/`parallel_max_servers` configurados, sin CPUs offline
inesperadas.

# Abnormal patterns

CPUs offline no explicadas, `cpu_count` de Oracle mayor a `logical_cpus` real, asimetría de
topología entre nodos RAC.

# False positives

Asimetría de topología entre nodos RAC no es intrínsecamente anómala en clusters heterogéneos
declarados — se reporta como observación, severidad depende de si el Target Profile declara
homogeneidad esperada.

# Correlation rules

Alimenta `os/numa`, `performance` (paralelismo), `rac` (colocación de instancias).

# Confidence model

`FACT` para topología leída directamente.

# Severity

`MEDIUM` si `cpu_count` de Oracle excede `logical_cpus` real; `LOW` para asimetría entre nodos sin
impacto reportado.

# Output schema

```yaml
cpu_topology:
  logical_cpus: int
  physical_cores: int|null
  sockets: int|null
  threads_per_core: int|null
  architecture: string
  cpu_online: int|null
  cpu_offline: int|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/numa`, `os/memory`, `os/platform-assessment`.

# Escalation

`cpu_count` mal dimensionado → correlación con `oracle-performance-analyst`, remediación como
`manual_action`.

# Manual remediation guidance

`manual_action` sugiere ajustar `cpu_count`/`parallel_max_servers` vía `ALTER SYSTEM` — ejecución
delegada a `oracle-dba-analyst`/DBA, siempre `NOT_EXECUTED` desde este skill.

# Security

Ninguna exposición de datos sensibles.

# Tests

`tests/test_cpu_topology.sh`.

# Documentation requirements

Alimenta `cpu-numa.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
