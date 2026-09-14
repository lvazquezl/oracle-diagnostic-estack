---
name: grid-processes
id: os/grid-processes
version: 1.0.0
domain: os
status: active
---

# Purpose

Resume procesos Grid Infrastructure/Clusterware (`ohasd`, `crsd`, `cssd`, `evmd`, agentes) a
nivel OS — nunca envía command-line arguments completos por defecto, nunca reemplaza a
`oracle-rac-analyst` (que posee el estado de recursos Clusterware vía `crsctl`).

# Supported Oracle versions

11gR2+ (arquitectura GI moderna) — no aplica en 10g/11gR1 (`NOT_APPLICABLE`, Clusterware legacy
fuera de alcance).

# Supported OS/platforms

Linux (`ps` filtrado por familia GI vía collector): `SUPPORTED`. Solaris: `SUPPORTED`. Windows:
`NOT_APPLICABLE` (GI en Windows tiene un modelo de servicio distinto, fuera de alcance de esta
fase).

# Supported architectures

RAC/RAC One Node exclusivamente — `NOT_APPLICABLE` en standalone sin GI.

# Prerequisites

`os/oracle-processes` ya ejecutado; arquitectura RAC/GI confirmada por el Target Profile.

# Required evidence

- collector `get_grid_process_summary`

# Optional evidence

Ninguna.

# Read-only operations

Lectura de resumen de procesos GI vía collector semántico — nunca `crsctl`/`srvctl` de cambio
(eso es dominio de `oracle-rac-analyst`, y siempre read-only ahí también).

# Forbidden operations

Nunca envía señales a procesos GI, nunca ejecuta `crsctl start/stop`.

# Decision logic

1. Reportar presencia/conteo de procesos GI críticos (`ohasd`, `crsd`, `cssd`, `evmd`) — awareness
   a nivel OS, nunca sustituye el estado de recurso Clusterware real (`crsctl stat res -t`,
   propiedad de `oracle-rac-analyst`).
2. Proceso GI crítico ausente a nivel OS + recurso Clusterware reportado `OFFLINE` por
   `oracle-rac-analyst` → correlación fuerte, reportado con evidence_refs cruzados, nunca
   duplicado como dos hallazgos independientes sin relación.
3. Nunca envía command-line arguments completos por defecto — mismo principio que
   `os/oracle-processes`.

# Normal state

Todos los procesos GI críticos presentes para el nodo.

# Abnormal patterns

Proceso GI crítico ausente — correlacionar inmediatamente con `oracle-rac-analyst`.

# False positives

Ninguno conocido — ausencia de un proceso GI crítico es siempre un hallazgo relevante.

# Correlation rules

Alimenta `os/rac-interconnect-awareness`, `oracle-rac-analyst` (evidencia complementaria, nunca
sustituta).

# Confidence model

`FACT` para presencia/conteo leídos directamente.

# Severity

`CRITICAL` si un proceso GI crítico está ausente.

# Output schema

```yaml
grid_processes:
  applicable: bool
  process_count_by_family: {ohasd: int, crsd: int, cssd: int, evmd: int}
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/oracle-processes`, `os/rac-interconnect-awareness`.

# Escalation

Proceso GI crítico ausente escala inmediatamente a `oracle-rac-analyst`.

# Manual remediation guidance

N/A directa — ninguna acción de Clusterware ejecutada por este skill.

# Security

Command-line arguments completos nunca se envían por defecto.

# Tests

`tests/test_grid_process_summary.sh`, `tests/test_os_process_args_sanitization.sh`.

# Documentation requirements

Alimenta `oracle-processes.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
