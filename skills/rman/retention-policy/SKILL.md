---
name: retention-policy
id: rman/retention-policy
version: 1.0.0
domain: rman
status: active
---

# Purpose

Análisis de política de retención (`REDUNDANCY`/`RECOVERY WINDOW OF ... DAYS`) frente al RPO declarado y a la frescura real observada — nunca ejecuta `CONFIGURE RETENTION POLICY`.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/configuration` resuelto.

# Required evidence

- `Q-RMAN-CONFIGURATION-001`

# Optional evidence

`Q-RMAN-BACKUP-SET-001` para contrastar retención declarada vs. backups realmente disponibles.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`, `Q-RMAN-BACKUP-SET-001`.

# Collector IDs

`get_rman_configuration`.

# Read-only operations

Lectura de `V$RMAN_CONFIGURATION`.

# Forbidden operations

Nunca ejecuta `CONFIGURE RETENTION POLICY`.

# Decision logic

1. `RECOVERY WINDOW OF N DAYS` → comparar N contra `rpo_minutes_target` del Target Profile (`recovery_objectives`) cuando esté declarado.
2. `REDUNDANCY N` → comparar contra el número real de backups disponibles por punto de restore.
3. Sin `recovery_objectives` declarado → `INSUFFICIENT_REQUIREMENTS`, nunca se inventa un RPO objetivo (`# 31` del prompt).

# Normal state

Retención configurada explícitamente y alineada al RPO declarado (o ausencia de requisito documentada como tal).

# Abnormal patterns

Retención en el default (`REDUNDANCY 1`) sin decisión documentada, en producción.

# False positives

`REDUNDANCY 1` no es un problema por sí solo en un ambiente no productivo de bajo RPO.

# Correlation rules

Correlaciona con `rman/backup-freshness`, `rman/fra-pressure` (retención más larga implica más presión de FRA).

# Confidence model

`FACT` para la política leída. `OBSERVATION` para la alineación con RPO.

# Severity

Retención por debajo del RPO declarado en producción → `HIGH`.

# Output schema

```yaml
configuration:
  retention_policy: string|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/configuration`, `rman/backup-freshness`, `rman/fra-pressure`.

# Escalation

Retención insuficiente confirmada contra RPO declarado en producción → `change-advisor` (vía DBA).

# Manual remediation guidance

`CONFIGURE RETENTION POLICY` se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_rman_configuration_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/rman-configuration.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
