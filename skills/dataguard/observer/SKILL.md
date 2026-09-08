---
name: observer
id: dataguard/observer
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Sólo visibilidad de observer: configurado, conectado, estado — nunca ejecuta `START OBSERVER` (`# 27` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY, sólo relevante cuando FSFO está habilitado.

# Prerequisites

`dataguard/fsfo` resuelto.

# Required evidence

- collector `get_fsfo_status` (incluye estado de observer dentro de `SHOW FAST_START FAILOVER`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna.

# Collector IDs

`get_fsfo_status`.

# Read-only operations

Lectura del estado de observer ya incluido en la salida de `get_fsfo_status`.

# Forbidden operations

No ejecuta `START OBSERVER`, no configura el observer.

# Decision logic

1. Leer si el observer está configurado y conectado.
2. Si no puede verse con privilegios read-only disponibles → `INSUFFICIENT_EVIDENCE`, nunca se asume su estado (`# 27`).

# Normal state

Observer `CONFIGURED` y `CONNECTED` cuando FSFO está habilitado.

# Abnormal patterns

Observer `CONFIGURED` pero `DISCONNECTED`.

# False positives

Desconexión momentánea durante reinicio planificado del host del observer.

# Correlation rules

Cruza con `dataguard/fsfo` (FSFO sin observer conectado es de alto riesgo) y `dataguard/failover-readiness` (observer es un insumo de esa readiness).

# Confidence model

`FACT` cuando el estado es visible con los privilegios disponibles. `INSUFFICIENT_EVIDENCE` explícito cuando no lo es — nunca se rellena con una suposición.

# Severity

Observer desconectado con FSFO habilitado → `HIGH`.

# Output schema

```yaml
findings:
  - observer_status: CONFIGURED|CONNECTED|DISCONNECTED|UNKNOWN|INSUFFICIENT_EVIDENCE
    observer_host: string|null
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/fsfo`, `dataguard/failover-readiness`.

# Escalation

Observer desconectado con FSFO habilitado → `incident-root-cause-analyst`.

# Manual remediation guidance

Iniciar el observer es `manual_action` (`START OBSERVER`), `execution_status: NOT_EXECUTED` — nunca ejecutado.

# Security

`observer_host` enmascarado por defecto.

# Tests

`tests/test_broker_fsfo_parser.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `readiness.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
