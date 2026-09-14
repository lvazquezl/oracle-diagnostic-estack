---
name: oracle-processes
id: os/oracle-processes
version: 1.0.0
domain: os
status: active
---

# Purpose

Resume conteo de procesos, owners, familias principales (PMON/LGWR/DBWn/SMON/LMS/LMD/LMON en
RAC) y awareness de procesos zombie — nunca envía command-line arguments completos por defecto.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`ps` filtrado por owner/familia vía collector): `SUPPORTED`. Solaris (`ps -ef`
equivalente): `SUPPORTED`. Windows (`tasklist`/servicios OracleService): `SUPPORTED`.

# Supported architectures

Standalone y RAC (RAC tiene procesos adicionales LMS/LMD/LMON por instancia).

# Prerequisites

`os/oracle-groups` recomendado.

# Required evidence

- collector `get_oracle_process_summary`

# Optional evidence

Ninguna.

# Read-only operations

Lectura de resumen de procesos vía collector semántico — `ps`/`tasklist` filtrado, nunca un
volcado completo de todos los procesos del sistema.

# Forbidden operations

Nunca envía señales a procesos (`kill`, incluso `SIGTERM`), nunca termina ningún proceso.

# Decision logic

1. Reportar `process_count` por familia (PMON/LGWR/DBWn/SMON/ARCn, y LMS/LMD/LMON en RAC),
   `owner` (tokenizado), y awareness de procesos zombie.
2. **Nunca envía command-line arguments completos por defecto** (`# 44`/`# 58` del prompt) —
   podrían contener passwords/connection strings/tokens/wallet paths; se prefiere
   `process_family`/`name`. Argumentos completos sólo tras sanitización explícita, cuando el
   diagnóstico específico lo requiera y el DBA lo autorice.
3. Proceso crítico ausente (ej. `PMON` no encontrado para una instancia declarada activa) →
   `CRITICAL`. Zombie awareness es informativo salvo acumulación sostenida (`WARNING`).

# Normal state

Todos los procesos de familia crítica presentes para cada instancia activa, sin acumulación de
zombies.

# Abnormal patterns

Proceso crítico ausente, acumulación sostenida de procesos zombie.

# False positives

Un zombie transitorio único no es un hallazgo — sólo acumulación sostenida.

# Correlation rules

Alimenta `os/grid-processes`, `os/process-limits`, `os/oracle-groups`.

# Confidence model

`FACT` para conteo/presencia leídos directamente.

# Severity

`CRITICAL` si falta un proceso crítico de una instancia activa; `WARNING` para acumulación de
zombies.

# Output schema

```yaml
oracle_processes:
  process_count_by_family: {pmon: int, lgwr: int, dbwn: int, smon: int, lms: int|null}
  zombie_count: int|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/grid-processes`, `os/process-limits`, `os/oracle-groups`.

# Escalation

Proceso crítico ausente escala a `oracle-dba-analyst`/`oracle-rac-analyst`.

# Manual remediation guidance

N/A directa — ningún reinicio/kill de proceso ejecutado por este skill.

# Security

Command-line arguments completos nunca se envían por defecto; owners → `TOKENIZE`.

# Tests

`tests/test_oracle_process_summary.sh`, `tests/test_os_process_args_sanitization.sh`.

# Documentation requirements

Alimenta `oracle-processes.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
