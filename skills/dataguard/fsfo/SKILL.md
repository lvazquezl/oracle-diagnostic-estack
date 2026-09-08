---
name: fsfo
id: dataguard/fsfo
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Awareness de Fast-Start Failover: enabled/disabled, target, threshold, observer visibility, requisitos de protección, flashback awareness, lag limit awareness, status — nunca habilita/deshabilita FSFO, nunca cambia thresholds (`# 26` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai (FSFO disponible desde 10gR2, maduro desde 11gR2).

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY (requiere `MAXIMUM AVAILABILITY` para operar como diseñado).

# Prerequisites

`dataguard/broker` resuelto; `target_profile.dataguard.fsfo_enabled = true`.

# Required evidence

- collector `get_fsfo_status` (`SHOW FAST_START FAILOVER`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno (FSFO es parte del core de Data Guard).

# Query IDs

Ninguna.

# Collector IDs

`get_fsfo_status`.

# Read-only operations

Ejecución allowlisted de `SHOW FAST_START FAILOVER`.

# Forbidden operations

No habilita/deshabilita FSFO, no cambia `Threshold`/`Target`.

# Decision logic

1. Leer `FastStartFailover` (enabled/disabled), target standby, threshold configurado.
2. Correlacionar threshold con `dataguard/protection` (FSFO requiere `MAXIMUM AVAILABILITY`) — FSFO habilitado en `MAXIMUM PERFORMANCE` es una inconsistencia de configuración a reportar.
3. Correlacionar con `dataguard/observer` — FSFO habilitado sin observer conectado es una condición de riesgo (no puede dispararse automáticamente).

# Normal state

FSFO enabled con protection mode `MAXIMUM AVAILABILITY`, observer conectado, threshold consistente con RPO declarado.

# Abnormal patterns

FSFO enabled sin observer conectado; protection mode inconsistente con requisito de FSFO.

# False positives

Observer desconectado durante una ventana de mantenimiento comunicada.

# Correlation rules

Cruza con `dataguard/broker`, `dataguard/observer`, `dataguard/protection`, `dataguard/failover-readiness` (FSFO status es un insumo directo de esa readiness).

# Confidence model

`FACT` para estado FSFO leído directamente.

# Severity

FSFO enabled sin observer conectado → `HIGH` (el failover automático no puede ocurrir pese a estar "habilitado").

# Output schema

```yaml
findings:
  - enabled: bool
    target: string|null
    threshold_seconds: number|null
    protection_mode_consistent: bool
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/broker`, `dataguard/observer`, `dataguard/failover-readiness`.

# Escalation

FSFO enabled sin observer conectado → `incident-root-cause-analyst`.

# Manual remediation guidance

Habilitar/deshabilitar FSFO o cambiar threshold es `manual_action`.

# Security

`target` (db_unique_name) enmascarado por defecto.

# Tests

`tests/test_broker_fsfo_parser.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `readiness.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
