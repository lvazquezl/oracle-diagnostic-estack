---
name: archive-gaps
id: dataguard/archive-gaps
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Detectar rangos de secuencia faltantes, received-not-applied, y gaps específicos de thread — nunca compara secuencias entre threads como si fueran una sola serie (`# 15`, `# 58` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

`dataguard/lag` resuelto (el gap suele detectarse como parte del análisis de lag).

# Required evidence

- `Q-DG-ARCHIVE-GAP-001` (`V$ARCHIVE_GAP`)

# Optional evidence

- `Q-DG-ARCHIVED-LOG-001` (para el detalle de secuencias recibidas/aplicadas por thread, ventana acotada).

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-ARCHIVE-GAP-001`, `Q-DG-ARCHIVED-LOG-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$ARCHIVE_GAP`, `V$ARCHIVED_LOG` (ventana acotada).

# Forbidden operations

No registra archivelogs (`ALTER DATABASE REGISTER LOGFILE` prohibido), no fuerza resolución de gap.

# Decision logic

1. Leer `V$ARCHIVE_GAP` por `THREAD#` — en RAC, cada thread se evalúa de forma independiente (`# 15`).
2. Clasificar cada gap: `TRANSPORT_GAP` (rango nunca recibido), `RECEIVED_NOT_APPLIED` (recibido pero MRP no lo aplicó — correlacionar con `dataguard/apply`), `THREAD_SPECIFIC_GAP` (afecta sólo un thread en RAC, otros threads sanos), `TEMPORARY_GAP` (rango pequeño que se resuelve solo en la siguiente ventana de observación), `UNKNOWN_GAP` (no puede clasificarse con la evidencia disponible) (`# 58`).
3. Nunca mezclar clasificaciones — cada gap se reporta con exactamente una.

# Normal state

`V$ARCHIVE_GAP` sin filas — ausencia de gap es el estado esperado, no un hallazgo.

# Abnormal patterns

Gap persistente en 2+ ventanas de observación sucesivas sin reducirse.

# False positives

Gap pequeño y transitorio (`TEMPORARY_GAP`) que se resuelve en la siguiente observación — no requiere escalación.

# Correlation rules

`RECEIVED_NOT_APPLIED` correlaciona con `dataguard/apply` (¿MRP está corriendo?); `TRANSPORT_GAP` correlaciona con `dataguard/transport` (¿el destino tuvo error en la ventana del gap?).

# Confidence model

`FACT` para el gap leído directamente. `PROBABLE_CAUSE` para la clasificación cuando se correlaciona con `dataguard/apply`/`dataguard/transport`.

# Severity

`TRANSPORT_GAP`/`RECEIVED_NOT_APPLIED` persistente y creciente → `HIGH`; `TEMPORARY_GAP` → `LOW`; `UNKNOWN_GAP` → `MEDIUM` (falta de clasificación es en sí una señal de evidencia insuficiente).

# Output schema

```yaml
findings:
  - thread: number
    classification: TRANSPORT_GAP|RECEIVED_NOT_APPLIED|THREAD_SPECIFIC_GAP|TEMPORARY_GAP|UNKNOWN_GAP
    sequence_range: string
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/lag`, `dataguard/transport`, `dataguard/apply`.

# Escalation

Gap persistente y creciente sin resolverse solo → `incident-root-cause-analyst`.

# Manual remediation guidance

Resolución de gap (registro manual de archivelog, resincronización) es siempre `manual_action`.

# Security

`sequence_range`/thread no son sensibles; nombres de destino asociados se enmascaran.

# Tests

`tests/test_archive_gap.sh`, `tests/test_rac_thread_gap.sh`, `tests/test_gap_not_cross_thread_misclassified.sh`, `tests/test_gap_classification.sh`, `tests/test_dataguard_gap_query.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `lag-analysis.md`/`dataguard-topology.md` con el resumen de gaps por thread.

# Change history

v1.0.0 — Fase 5, creación inicial.
