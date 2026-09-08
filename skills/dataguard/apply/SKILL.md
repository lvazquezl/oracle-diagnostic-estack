---
name: apply
id: dataguard/apply
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Analizar estado de MRP (Managed Recovery Process): `recovery_mode`, `current_sequence`, `last applied`, `last received`, tasa de apply, real-time apply, estado del proceso, interrupciones — nunca ejecuta `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE ...` (`# 12` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY (foco). LOGICAL_STANDBY usa LSP en vez de MRP — reconocido, `PARTIALLY_SUPPORTED` en esta fase.

# Prerequisites

`dataguard/transport` resuelto.

# Required evidence

- `Q-DG-MANAGED-PROCESS-001` (`V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY` en 10.2–12.1, `V$DATAGUARD_PROCESS`/`GV$DATAGUARD_PROCESS` en 12.2–23.0 — ver el modelo lógico `dataguard_process` en la query, `process_action` reporta el estado MRP en ambas variantes)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-MANAGED-PROCESS-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY` (10.2–12.1) o `V$DATAGUARD_PROCESS`/`GV$DATAGUARD_PROCESS` (12.2–23.0) según versión certificada.

# Forbidden operations

No ejecuta `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE` (start/cancel), no reinicia MRP.

# Decision logic

1. Leer estado de proceso `MRP0` (o LSP para logical): `APPLYING_LOG`, `WAIT_FOR_LOG`, `IDLE`, ausente.
2. MRP ausente cuando se espera apply activo → `MRP stopped`, severidad según tiempo transcurrido desde la última aplicación.
3. Comparar `last_applied_sequence` vs. `last_received_sequence` — diferencia sostenida indica apply lento (correlacionar con `dataguard/lag`) vs. transporte lento (ya cubierto por `dataguard/transport`).
4. No asumir que ausencia de real-time apply es un defecto si no es requisito del diseño declarado (`# 19`).

# Normal state

MRP en `APPLYING_LOG` o `WAIT_FOR_LOG` (esperando el siguiente redo, comportamiento normal entre switches), `last_applied_sequence` cercano a `last_received_sequence`.

# Abnormal patterns

MRP ausente con redo recibido pendiente de aplicar; `last_applied_sequence` estancado por varias ventanas de observación.

# False positives

MRP en `WAIT_FOR_LOG` momentáneo entre log switches — no es "detenido", es el estado normal de espera.

# Correlation rules

Cruza con `dataguard/lag` (apply lag) y `dataguard/processes` (RFS/LNS del lado transporte). Correlaciona con `oracle-performance-analyst`/`oracle-asm-storage-analyst` cuando el apply lento coincide con presión de CPU/I/O (`# 42`, `# 41`) — nunca se activa por defecto.

# Confidence model

`FACT` para estado de proceso/secuencias leídos directamente. `HYPOTHESIS` para "apply detenido por presión de recursos" sin correlación de evidencia OS/performance.

# Severity

MRP ausente sin explicación con gap creciente → `HIGH`; `WAIT_FOR_LOG` prolongado sin nuevo redo esperado (transporte también sano) → `LOW`.

# Output schema

```yaml
findings:
  - mrp_state: string
    recovery_mode: string
    current_sequence: number
    last_applied_sequence: number
    last_received_sequence: number
    real_time_apply: bool
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/transport`, `dataguard/lag`, `dataguard/real-time-apply`, `dataguard/processes`.

# Escalation

MRP detenido sin explicación con gap creciente → `incident-root-cause-analyst`.

# Manual remediation guidance

Reinicio de MRP es siempre `manual_action` (`ALTER DATABASE RECOVER MANAGED STANDBY DATABASE ...`), `execution_status: NOT_EXECUTED`.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_apply_healthy.sh`, `tests/test_mrp_stopped.sh`, `tests/test_real_time_apply.sh`, `tests/test_received_not_applied.sh`, `tests/test_no_apply_start_execution.sh`, `tests/test_no_apply_stop_execution.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `apply-analysis.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
