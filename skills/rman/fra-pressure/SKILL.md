---
name: fra-pressure
id: rman/fra-pressure
version: 1.0.0
domain: rman
status: active
---

# Purpose

Correlación de presión de FRA con generación de archivelog, cadencia de backup, retención, deletion policy, flashback logs, restore points y Data Guard — nunca borra archivos (`# 18` del prompt de Fase 7).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`rman/fra` resuelto.

# Required evidence

- `Q-RMAN-FRA-USAGE-001`
- `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`
- `Q-RMAN-CONFIGURATION-001`

# Optional evidence

Contexto Data Guard vía `oracle-dataguard-analyst` (archivelog deletion policy consciente de standby).

# Licensing requirements

Ninguno.

# Query IDs

`Q-RMAN-FRA-USAGE-001`, `Q-RMAN-ARCHIVED-LOG-COVERAGE-001`, `Q-RMAN-CONFIGURATION-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de las vistas ya certificadas.

# Forbidden operations

Nunca borra archivos ni ejecuta `DELETE OBSOLETE`.

# Decision logic

1. `SPACE_USED/SPACE_LIMIT` alto (`>85%` orientativo, ajustable por el sitio) sin `SPACE_RECLAIMABLE` suficiente → `HIGH`/`CRITICAL`.
2. Correlacionar la causa: archivelogs sin backup (`rman/archivelog-backup`) que no pueden liberarse bajo la deletion policy configurada; retención larga (`rman/retention-policy`); flashback logs activos; restore points guardados; standby con apply lag (Data Guard) que retiene archivelogs.
3. `pressure: LOW|MEDIUM|HIGH|CRITICAL` siempre acompañado de `correlated_with` — nunca un solo número sin explicación.

# Normal state

`SPACE_USED` estable, con `SPACE_RECLAIMABLE` liberándose tras cada backup exitoso de archivelog.

# Abnormal patterns

`SPACE_USED` creciente sostenido sin `SPACE_RECLAIMABLE` correspondiente.

# False positives

Presión alta transitoria durante una ventana de backup con `ARCHIVELOG DELETION POLICY` que espera confirmación de aplicación en standby no es un problema si se resuelve tras el apply.

# Correlation rules

Correlaciona con `rman/archivelog-backup`, `rman/retention-policy`, `rman/dataguard-awareness`, delega a `oracle-asm-storage-analyst` si la presión sugiere capacidad ASM subyacente insuficiente.

# Confidence model

`OBSERVATION` para la presión medida. `PROBABLE_CAUSE` sólo con correlación confirmada de al menos una causa.

# Severity

`CRITICAL` cuando `SPACE_LIMIT` está a punto de alcanzarse sin espacio reclamable — riesgo de detener backups o (en `NOARCHIVELOG` insuficiente) la base misma.

# Output schema

```yaml
fra:
  pressure: LOW|MEDIUM|HIGH|CRITICAL|UNKNOWN
  correlated_with: [string]
  evidence_refs: [EVD-...]
```

# Related skills

`rman/fra`, `rman/archivelog-backup`, `rman/retention-policy`, `rman/dataguard-awareness`.

# Escalation

`CRITICAL` en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

Ajuste de retención/backup de archivelog pendiente se entrega como recomendación manual — nunca se borra nada automáticamente.

# Security

Ninguna exposición adicional.

# Tests

`tests/test_fra_healthy.sh`, `tests/test_fra_warning.sh`, `tests/test_fra_critical.sh`, `tests/test_fra_correlates_archivelogs.sh`, `tests/test_fra_no_auto_delete.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/fra-analysis.md`.

# Change history

v1.0.0 — Fase 7, creación inicial.
