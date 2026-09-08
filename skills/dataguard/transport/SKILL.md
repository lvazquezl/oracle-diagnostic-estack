---
name: transport
id: dataguard/transport
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Analizar `LOG_ARCHIVE_DEST_n` por destino: estado, target, validez del rol de destino, modo de transporte (SYNC/ASYNC), AFFIRM/NOAFFIRM, `VALID_FOR`, error, estado de recovery, y clasificar la causa cuando el transporte no está sano (`# 11` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY (foco); aplica igual a LOGICAL_STANDBY como destino.

# Prerequisites

`dataguard/role`/`dataguard/topology` resueltos.

# Required evidence

- `Q-DG-DEST-001` (`V$ARCHIVE_DEST`, `V$ARCHIVE_DEST_STATUS`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-DEST-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$ARCHIVE_DEST`/`V$ARCHIVE_DEST_STATUS`.

# Forbidden operations

No modifica `LOG_ARCHIVE_DEST_n`/`LOG_ARCHIVE_DEST_STATE_n`, no difiere/habilita destinos.

# Decision logic

1. Por destino: leer `STATUS`, `TARGET`, `VALID_FOR` (validez del rol del destino en el rol actual de la base), `SYNC`/`ASYNC`, `AFFIRM`/`NOAFFIRM`, `ERROR`.
2. Clasificar: `HEALTHY` (STATUS=VALID sin error), `DEFERRED` (STATUS=DEFERRED, deliberado), `ERROR` (STATUS=ERROR con código específico), `NETWORK_DELAY_SUSPECTED` (transporte activo pero lag creciente sin error explícito, correlacionar con `dataguard/lag`), `DESTINATION_UNAVAILABLE` (error de conectividad), `CONFIGURATION_MISMATCH` (`VALID_FOR` no coincide con el rol actual).
3. Nunca concluir causa de red sin la clasificación explícita — un destino `DEFERRED` no es un problema si fue deliberado (correlacionar con ventana de mantenimiento conocida).

# Normal state

Todos los destinos requeridos `STATUS = VALID`, sin `ERROR`.

# Abnormal patterns

`STATUS = ERROR` con código Oracle específico; destino requerido en `DEFERRED` sin explicación de mantenimiento.

# False positives

Destino `DEFERRED` deliberadamente por el DBA para mantenimiento planificado.

# Correlation rules

Cruza con `dataguard/lag` (transport lag creciente) y, si se sospecha causa de red, delega a `oracle-network-analyst` — nunca afirma causa de red sin esa evidencia (`# 40`, `# 57`).

# Confidence model

`FACT` para `STATUS`/`ERROR` leídos directamente. `HYPOTHESIS` para clasificación de causa sin correlación adicional; `PROBABLE_CAUSE` con 2+ señales.

# Severity

Destino requerido en `ERROR` → `HIGH`; `DEFERRED` sin explicación → `MEDIUM`.

# Output schema

```yaml
findings:
  - destination: string
    status: string
    mode: SYNC|ASYNC
    affirm: bool
    valid_for: string
    error: string|null
    classification: HEALTHY|DEFERRED|ERROR|NETWORK_DELAY_SUSPECTED|DESTINATION_UNAVAILABLE|CONFIGURATION_MISMATCH
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/apply`, `dataguard/lag`, `dataguard/archive-destinations`.

# Escalation

Destino requerido en `ERROR` sostenido → `incident-root-cause-analyst`; hipótesis de red → `oracle-network-analyst`.

# Manual remediation guidance

Ajuste de `LOG_ARCHIVE_DEST_n`/`LOG_ARCHIVE_DEST_STATE_n` es siempre `manual_action` — nunca ejecutado.

# Security

Nombres de destino/service enmascarados por defecto (`docs/DATAGUARD_READONLY_QUERIES.md#sanitization`).

# Tests

`tests/test_transport_healthy.sh`, `tests/test_transport_error.sh`, `tests/test_transport_deferred.sh`, `tests/test_destination_configuration.sh`, `tests/test_no_write_operations.sh`, `tests/test_no_archive_dest_modify.sh`.

# Documentation requirements

Alimenta `transport-analysis.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
