---
name: fra
id: rman/fra
version: 1.0.0
domain: rman
status: active
---

# Purpose

Visibilidad de uso/límite/espacio reclamable de la Fast Recovery Area (`SPACE_LIMIT`, `SPACE_USED`, `SPACE_RECLAIMABLE`, `NUMBER_OF_FILES`) — base de `rman/fra-pressure`.

# Supported Oracle versions

10g–23ai (feature FRA introducida en 10g).

# Supported OS/platforms

Todas — filesystem o ASM.

# Supported architectures

Standalone y RAC (FRA puede ser compartida en RAC vía ASM).

# Prerequisites

Ninguno.

# Required evidence

- `Q-RMAN-FRA-USAGE-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-FRA-USAGE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$FLASH_RECOVERY_AREA_USAGE`/`V$RECOVERY_FILE_DEST`.

# Forbidden operations

Nunca borra archivos de FRA.

# Decision logic

1. `SPACE_USED / SPACE_LIMIT` por tipo de archivo (`file_type`) — reportado individualmente, nunca agregado en un solo número que oculte qué tipo de archivo domina el uso.
2. `SPACE_RECLAIMABLE` alto respecto a `SPACE_USED` → espacio recuperable existe pero no se recupera automáticamente (nunca se ejecuta la limpieza).

# Normal state

`SPACE_USED` por debajo de umbrales de alerta del sitio, con `SPACE_RECLAIMABLE` conocido.

# Abnormal patterns

`SPACE_USED` cerca de `SPACE_LIMIT` sin `SPACE_RECLAIMABLE` suficiente para absorber crecimiento.

# False positives

Un pico temporal de uso durante una ventana de backup activa no es crítico por sí solo si baja al finalizar.

# Correlation rules

Alimenta `rman/fra-pressure` — este skill es la fuente de datos cruda, la interpretación de presión/correlación vive ahí.

# Confidence model

`FACT` para el uso leído directamente.

# Severity

Ver `rman/fra-pressure` para clasificación de severidad.

# Output schema

```yaml
fra:
  space_limit_bytes: int|null
  space_used_bytes: int|null
  space_reclaimable_bytes: int|null
  number_of_files: int|null
  evidence_refs: [EVD-...]
```

# Related skills

`rman/fra-pressure`, `rman/archivelog-backup`, `rman/retention-policy`.

# Escalation

Ver `rman/fra-pressure`.

# Manual remediation guidance

Ninguna directa — ver `rman/fra-pressure`.

# Security

`dest_name` → MASK.

# Tests

`tests/test_fra_query.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/fra-analysis.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
