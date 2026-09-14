---
name: open-files
id: os/open-files
version: 2.0.0
domain: os
status: active
---

# Purpose

Analiza `fs.file-max` (system-wide), `nofile` soft/hard **configurado** por usuario/systemd, el
límite **efectivo** real del PID Oracle/Grid, y uso actual de file descriptors por proceso —
correlaciona con Oracle/Grid/media manager (RMAN SBT). Distingue explícitamente 5 conceptos que
nunca se mezclan: `file-max` system-wide, límite configurado (PAM/systemd), límite efectivo del
PID, y uso actual de FDs (`# 106` del prompt de hardening: "os/open-files must distinguish
system-wide file-max, configured user limits, systemd service limits, effective process limits,
current FD usage").

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`/proc/sys/fs/file-max`, `ulimit -n`): `SUPPORTED`. Solaris (`ulimit -n`, `rctl`):
`SUPPORTED`. Windows (handle limits, modelo distinto): `PARTIALLY_SUPPORTED`.

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/oracle-groups` recomendado; PID objetivo descubierto vía
`os/oracle-processes`/`os/grid-processes` para el límite efectivo y el uso actual.

# Required evidence

- collector `get_open_files_limits` (`file_max` system-wide, `nofile` configurado por usuario)
- collector `get_process_effective_limits` (límite `nofile` efectivo del PID objetivo, cuando
  disponible — evidencia primaria del valor real, ver `os/process-limits`)

# Optional evidence

- collector `get_service_limit_configuration` (`LimitNOFILE` de systemd unit, cuando
  `launch_context.type == SYSTEMD` — ver `os/systemd-limits`)

# Read-only operations

Lectura de límites/uso vía collector semántico.

# Forbidden operations

Nunca edita `/etc/security/limits.conf`, nunca cambia `fs.file-max`.

# Decision logic

1. Reportar por separado los 5 conceptos distintos: `file_max` (system-wide), `nofile_soft`/
   `nofile_hard` **configurado** (PAM, cuando el `launch_context` lo confirme aplicable —
   consumido de `os/ulimits`/`os/systemd-limits`), `nofile` **efectivo** del PID objetivo
   (`get_process_effective_limits`, cuando disponible), y uso actual de FDs del proceso principal
   cuando sea observable de forma segura. Nunca colapsados en un único valor.
2. El límite relevante para el risk model es el **efectivo** (del PID) cuando esté disponible —
   nunca el configurado aislado. Uso actual > 80% del límite efectivo → `MEDIUM`; > 95% → `HIGH`.
   Sin evidencia de uso actual real, no se declara riesgo sólo por un valor configurado aislado
   (`# 100`-`# 101` del prompt de hardening).
3. Correlacionar con `os/rman-media-manager-awareness` cuando el proceso SBT del media manager
   esté cerca de su límite — RMAN con muchos canales paralelos puede agotar file descriptors.

# Normal state

Uso actual con margen amplio sobre el `nofile` efectivo del PID.

# Abnormal patterns

Uso cercano al límite efectivo, especialmente durante backups RMAN con múltiples canales o alta
concurrencia de conexiones.

# False positives

`file_max` system-wide alto no compensa un `nofile` efectivo por proceso bajo. Un valor
`nofile_soft` configurado bajo sin evidencia de uso actual real cercano no es, por sí solo, un
hallazgo `HIGH`/`MEDIUM`.

# Correlation rules

Alimenta `os/ulimits`, `os/rman-media-manager-awareness`, `os/oracle-processes`.

# Confidence model

`FACT` para límites leídos directamente (configurados o efectivos).

# Severity

`HIGH` si uso actual > 95% del límite efectivo; `MEDIUM` > 80%.

# Output schema

```yaml
open_files:
  file_max: int|null
  configured:
    nofile_soft: int|null
    nofile_hard: int|null
  systemd_limit_nofile: int|null   # sólo si launch_context.type == SYSTEMD
  effective:
    nofile: int|null
    collection_status: FACT_COLLECTED|INSUFFICIENT_PRIVILEGES|NOT_APPLICABLE
  current_usage: int|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/ulimits`, `os/process-limits`, `os/systemd-limits`, `os/rman-media-manager-awareness`,
`os/oracle-processes`.

# Escalation

Uso cercano al límite durante RMAN escala a `oracle-backup-recovery-analyst`.

# Manual remediation guidance

`manual_action` sugiere ajustar `nofile` en `/etc/security/limits.conf` — `NOT_EXECUTED`.

# Security

Sin datos sensibles.

# Tests

`tests/test_open_files_limits.sh`, `tests/test_no_limits_change_execution.sh`,
`tests/test_open_files_effective_limit.sh`, `tests/test_open_files_current_usage_headroom.sh`,
`tests/test_open_files_systemwide_vs_process_scope.sh`.

# Documentation requirements

Alimenta `kernel-limits.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
v2.0.0 — PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING: distingue
explícitamente `file_max`/configurado/systemd/efectivo/uso actual; el límite efectivo del PID
objetivo (`get_process_effective_limits`) pasa a ser la evidencia primaria del risk model.
