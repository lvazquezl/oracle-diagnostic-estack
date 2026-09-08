---
name: standby-redo-logs
id: dataguard/standby-redo-logs
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Analizar número de SRLs, tamaño, asignación de thread, estado, topología de online redo del primary, conteo de threads, y awareness RAC — sin aplicar una fórmula rígida sin contexto (`# 17`, `# 18` del prompt de Fase 5).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

`dataguard/topology` resuelto (para conocer threads/RAC en ambos sitios).

# Required evidence

- `Q-DG-SRL-001` (`V$STANDBY_LOG`, `V$LOG` para comparación con online redo del primary)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-SRL-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$STANDBY_LOG`, `V$LOG`.

# Forbidden operations

No crea/elimina SRL (`# 17`: "No crear/drop SRL automáticamente").

# Decision logic

1. Contar grupos de SRL por thread y compararlos contra grupos de online redo del thread correspondiente en el primary.
2. **SRL Readiness Rule (`# 18`)**: la regla estándar documentada es `SRL groups per thread >= online redo groups per thread + 1` — pero esto se valida contra el contexto real (tamaño de redo, threads RAC, versión), nunca aplicado ciegamente. La regla empleada y su versión se documentan explícitamente en el finding.
3. Detectar: SRL faltante para un thread, grupos insuficientes, tamaño de SRL distinto al de online redo (`SIZE_MISMATCH`), mismatch de threads entre primary y standby.

# Normal state

`group_count >= required_minimum` por thread, `size_mb` coincide con el online redo del primary.

# Abnormal patterns

Thread del primary sin SRL correspondiente en el standby; `size_mb` distinto al online redo (puede impedir real-time apply eficiente).

# False positives

Standby recién agregado en proceso de configuración inicial — correlacionar con ventana de setup conocida antes de escalar.

# Correlation rules

Cruza con `dataguard/real-time-apply` (SRL insuficiente puede forzar archived-log apply en vez de real-time) y `dataguard/switchover-readiness` (SRL es un prerequisito de readiness).

# Confidence model

`FACT` para conteo/tamaño leídos directamente. `PROBABLE_CAUSE` para "SRL insuficiente explica ausencia de real-time apply" cuando se correlaciona con `dataguard/real-time-apply`.

# Severity

Thread sin SRL → `HIGH` (bloquea real-time apply completamente para ese thread); `SIZE_MISMATCH` → `MEDIUM`.

# Output schema

```yaml
findings:
  - thread: number
    group_count: number
    required_minimum: number
    size_mb: number
    size_matches_online_redo: bool
    status: SUFFICIENT|INSUFFICIENT|SIZE_MISMATCH|UNKNOWN
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/real-time-apply`, `dataguard/switchover-readiness`.

# Escalation

Thread sin SRL en un ambiente que requiere real-time apply → `change-advisor` (propuesta de creación manual).

# Manual remediation guidance

Creación de SRL es `manual_action` (`ALTER DATABASE ADD STANDBY LOGFILE ...`), `execution_status: NOT_EXECUTED`.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_srl_inventory.sh`, `tests/test_srl_thread_awareness.sh`, `tests/test_srl_size_awareness.sh`, `tests/test_srl_insufficient_groups.sh`, `tests/test_no_srl_create_execution.sh`, `tests/test_no_srl_drop_execution.sh`, `tests/test_dataguard_srl_query.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `readiness.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
