---
name: kernel-parameter-assessment
id: os/kernel-parameter-assessment
version: 1.0.0
domain: os
status: active
---

# Purpose

Consolida el assessment de parámetros de kernel relevantes a Oracle (`fs.aio-max-nr`,
`fs.file-max`, `kernel.shmmax/shmall/shmmni`, `kernel.sem`, `net.ipv4.ip_local_port_range`,
`net.core.rmem/wmem_default/max`) por plataforma/versión — nunca hardcodea una cifra universal
para todos los hosts.

# Supported Oracle versions

N/A directo — la guía de instalación de Oracle recomienda valores por versión/plataforma; este
skill cita la fuente aplicable, nunca una tabla genérica sin versión.

# Supported OS/platforms

Linux: `SUPPORTED`. Solaris: `PARTIALLY_SUPPORTED` (parámetros equivalentes vía `project`/`rctl`,
menor granularidad de mapeo directo). Windows: `NOT_APPLICABLE` (sin modelo `sysctl`
equivalente).

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/shared-memory`, `os/semaphores`, `os/aio` ya ejecutados (este skill consolida, no
re-recolecta).

# Required evidence

- evidencia de `os/shared-memory`, `os/semaphores`, `os/aio`, `os/tcp-socket-awareness`

# Optional evidence

Ninguna.

# Read-only operations

Ninguna adicional — consolida evidencia ya recolectada por los skills individuales.

# Forbidden operations

Nunca ejecuta `sysctl -w` de ningún parámetro.

# Decision logic

1. Consolidar los hallazgos de `os/shared-memory`, `os/semaphores`, `os/aio`,
   `os/tcp-socket-awareness` en una vista única de "kernel readiness para Oracle" — nunca
   duplica el análisis individual de cada skill.
2. Cada parámetro se evalúa contra su propio contexto (SGA, `PROCESSES`, concurrencia de I/O,
   conexiones de red esperadas) — nunca una tabla fija aplicada mecánicamente a cualquier host
   (`# 20` del prompt: "No hardcodear una cifra universal").
3. Reportar el conjunto completo de parámetros evaluados con su estado individual — nunca un
   score agregado que oculte cuál parámetro específico requiere atención.

# Normal state

Todos los parámetros de kernel relevantes dentro de los valores requeridos para la carga Oracle
real del host.

# Abnormal patterns

Cualquier combinación de los hallazgos individuales de `os/shared-memory`/`os/semaphores`/
`os/aio`/`os/tcp-socket-awareness`.

# False positives

Ninguno propio — hereda la disciplina anti-falso-positivo de cada skill consolidado.

# Correlation rules

Consolida `os/shared-memory`, `os/semaphores`, `os/aio`, `os/tcp-socket-awareness`. Alimenta
`os/platform-assessment`.

# Confidence model

`FACT` para cada parámetro individual (heredado).

# Severity

Heredada del hallazgo individual más severo entre los consolidados.

# Output schema

```yaml
kernel_parameter_assessment:
  parameters_evaluated: [string]
  findings: [{parameter: string, observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/shared-memory`, `os/semaphores`, `os/aio`, `os/tcp-socket-awareness`, `os/platform-assessment`.

# Escalation

Cualquier hallazgo `HIGH` escala a `os/manual-hardening-plan`.

# Manual remediation guidance

Consolida las `manual_action` de los skills individuales — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_no_sysctl_execution.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
