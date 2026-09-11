---
name: backup-optimization
id: rman/backup-optimization
version: 1.0.0
domain: rman
status: active
---

# Purpose

Visibilidad de `BACKUP OPTIMIZATION` (evita re-respaldar archivos ya respaldados sin cambios, según retención) — nunca ejecuta `CONFIGURE`.

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

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-CONFIGURATION-001`.

# Collector IDs

`get_rman_configuration`.

# Read-only operations

Lectura de `V$RMAN_CONFIGURATION`.

# Forbidden operations

Nunca ejecuta `CONFIGURE BACKUP OPTIMIZATION`.

# Decision logic

1. `BACKUP OPTIMIZATION ON` + archivelogs/datafiles read-only sin cambios → explica por qué ciertos objetos no aparecen en cada corrida (comportamiento esperado, no gap).
2. `OFF` en un ambiente con archivelogs duplicados hacia múltiples destinos → puede ser intencional (backup redundante) — nunca se reporta como error sin contexto.

# Normal state

Configuración explícita y consistente con la estrategia de backup del sitio.

# Abnormal patterns

Ninguno específico — este skill es principalmente contextual para interpretar correctamente `rman/backup-inventory`.

# False positives

Un archivo ausente en una corrida con `BACKUP OPTIMIZATION ON` no es un gap si ya tiene un backup válido reciente.

# Correlation rules

Correlaciona con `rman/backup-inventory`, `rman/archivelog-backup` (evita falsos positivos de "no backado").

# Confidence model

`FACT` para el valor de configuración leído.

# Severity

N/A — informativo, no genera hallazgos de severidad por sí solo.

# Output schema

```yaml
configuration:
  backup_optimization: ON|OFF|UNKNOWN
  evidence_refs: [EVD-...]
```

# Related skills

`rman/configuration`, `rman/backup-inventory`, `rman/archivelog-backup`.

# Escalation

Ninguna directa.

# Manual remediation guidance

`CONFIGURE BACKUP OPTIMIZATION` se entrega como recomendación manual — nunca ejecutado.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_rman_configuration_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/rman-configuration.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
