---
name: semaphores
id: os/semaphores
version: 1.0.0
domain: os
status: active
---

# Purpose

Interpreta `SEMMSL`/`SEMMNS`/`SEMOPM`/`SEMMNI` (`kernel.sem`) correlacionado con el número de
procesos Oracle esperados — nunca recomienda valores sin ese contexto.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`sysctl -n kernel.sem`): `SUPPORTED`. Solaris (equivalentes `project`/`rctl`):
`PARTIALLY_SUPPORTED`. Windows: `NOT_APPLICABLE`.

# Supported architectures

Standalone y RAC (RAC requiere más semáforos por instancias/procesos adicionales).

# Prerequisites

`os/oracle-processes` recomendado (conteo de procesos esperado).

# Required evidence

- collector `get_ipc_limits` (`SEMMSL`, `SEMMNS`, `SEMOPM`, `SEMMNI`)

# Optional evidence

- conteo de procesos Oracle esperado (`os/oracle-processes`)

# Read-only operations

Lectura de `sysctl -n kernel.sem` allowlisted.

# Forbidden operations

Nunca ejecuta `sysctl -w`, nunca edita `/etc/sysctl.conf`.

# Decision logic

1. `SEMMSL` (semáforos por set) debe ser >= `PROCESSES` de la instancia más grande + margen
   documentado por Oracle — evaluado contra el `PROCESSES` real configurado, nunca un valor
   genérico (`# 22` del prompt: "No recomendar valores sin contexto").
2. `SEMMNS` (total de semáforos en el sistema) debe cubrir la suma de todas las instancias
   activas.
3. `SEMMNI` (número de sets) insuficiente con múltiples instancias en el host es un hallazgo
   específico de ese escenario, nunca genérico.

# Normal state

Parámetros `sem` suficientes para el `PROCESSES` real de todas las instancias activas.

# Abnormal patterns

`SEMMSL`/`SEMMNS` insuficientes para el `PROCESSES` configurado — riesgo de fallo al iniciar
instancia.

# False positives

Ninguno cuando la comparación se hace contra el `PROCESSES` real — un valor "bajo" según una
tabla genérica sin ese contexto no es reportado.

# Correlation rules

Alimenta `os/shared-memory`, `os/oracle-processes`, `os/kernel-parameter-assessment`.

# Confidence model

`FACT` para valores leídos directamente.

# Severity

`HIGH` si insuficiente para `PROCESSES` real de alguna instancia; `LOW`/`MEDIUM` para márgenes
estrechos.

# Output schema

```yaml
semaphores:
  semmsl: int|null
  semmns: int|null
  semopm: int|null
  semmni: int|null
  max_processes_configured: int|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/shared-memory`, `os/oracle-processes`, `os/kernel-parameter-assessment`.

# Escalation

Insuficiencia escala a `os/manual-hardening-plan`.

# Manual remediation guidance

`manual_action` sugiere `sysctl -w kernel.sem="..."` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_semaphore_parameters.sh`, `tests/test_no_sysctl_execution.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
