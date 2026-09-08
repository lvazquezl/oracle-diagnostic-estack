---
name: processes
id: dataguard/processes
version: 3.0.0
domain: dataguard
status: active
---

# Purpose

Analizar procesos Data Guard según versión: MRP, RFS, LNS, LGWR, ARCH, DGRD, y otros realmente documentados — evita reglas obsoletas entre versiones (`# 20` del prompt de Fase 5). Complementa `dataguard/apply` (que se enfoca sólo en MRP).

# Supported Oracle versions

10g–23ai. `LNS` (log network server, ASYNC) reemplazado conceptualmente por procesos de transporte async modernos en versiones recientes — documentado por versión en `docs/DATAGUARD_READONLY_QUERIES.md`.

**PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING (v3.0.0)**: metadata y frontera de versiones corregidas contra la documentación oficial de Oracle Database Reference. `V$DATAGUARD_PROCESS` fue introducida en 12.2.0.1 — NO 11.2 como se declaró incorrectamente en el hardening anterior. `V$MANAGED_STANDBY` está oficialmente deprecada desde esa misma versión. `Q-DG-MANAGED-PROCESS-001` queda con una partición real sin solapamiento: variante legacy (`V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY`, 10.2–12.1, única opción en ese rango) y variante moderna (`V$DATAGUARD_PROCESS`/`GV$DATAGUARD_PROCESS`, 12.2–23.0, única opción en ese rango — ya no "on-demand" sobre un default legacy deprecado). El skill consume el modelo lógico `dataguard_process` (ver query), nunca columnas de una vista específica.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY y PRIMARY (procesos de transporte corren en el primary; RFS/MRP en el standby).

# Prerequisites

`dataguard/role` resuelto.

# Required evidence

- `Q-DG-MANAGED-PROCESS-001` (`V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-MANAGED-PROCESS-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY`.

# Forbidden operations

No inicia/detiene ningún proceso Data Guard.

# Decision logic

1. Enumerar procesos activos vía el modelo lógico `dataguard_process` (`process_name`, `process_role`, `process_action`, `client_pid`) — la versión certificada del target determina la variante (10.2–12.1 → legacy exclusivamente; 12.2–23.0 → moderna exclusivamente), nunca una elección arbitraria ni un fallback silencioso entre ambas.
2. Verificar `V$MANAGED_STANDBY`/`V$DATAGUARD_PROCESS` compatibility por versión — `V$MANAGED_STANDBY` está deprecada desde 12.2.0.1, nunca se usa como default universal para versiones donde la vista moderna ya es la recomendada.
3. `process_role` queda `NOT_AVAILABLE` cuando la variante activa es la legacy — `V$MANAGED_STANDBY` no tiene columna equivalente, nunca se infiere desde `PROCESS`/`STATUS`. `thread`/`sequence` están soportados en ambas variantes.
4. Ausencia de un proceso esperado (ej. sin `RFS` activo en el standby cuando el primary reporta transporte activo) es una señal de investigar, correlacionada con `dataguard/transport`.

# Normal state

Procesos esperados según rol (`ARCH`/transporte en primary; `RFS`/`MRP0` en standby) presentes y en estado activo.

# Abnormal patterns

`RFS` ausente en el standby con transporte activo reportado en el primary.

# False positives

Ausencia temporal de `LNS`/proceso ASYNC entre reconexiones — correlacionar duración.

# Correlation rules

Cruza con `dataguard/apply` (MRP) y `dataguard/transport` (procesos del lado primary).

# Confidence model

`FACT` para procesos/estado leídos directamente.

# Severity

Proceso crítico ausente sin explicación → `MEDIUM`/`HIGH` según impacto en transporte/apply.

# Output schema

```yaml
findings:
  - process_name: string          # PROCESS (legacy) | NAME (modern)
    process_role: string|NOT_AVAILABLE   # NOT_AVAILABLE en variante legacy
    process_action: string        # STATUS (legacy) | ACTION (modern)
    client_pid: string|null
    thread: int|null              # soportado en ambas variantes
    sequence: int|null            # soportado en ambas variantes
    source_view: string           # V$MANAGED_STANDBY|GV$MANAGED_STANDBY|V$DATAGUARD_PROCESS|GV$DATAGUARD_PROCESS
    source_variant: legacy|modern
    evidence_refs: [EVD-...]
```

# Related skills

`dataguard/apply`, `dataguard/transport`.

# Escalation

Proceso crítico ausente correlacionado con gap creciente → `incident-root-cause-analyst`.

# Manual remediation guidance

Inicio/detención de cualquier proceso es `manual_action`.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_dataguard_managed_process_query.sh`, `tests/test_no_write_operations.sh`, `tests/test_dataguard_process_legacy_variant.sh`, `tests/test_dataguard_process_modern_variant.sh`, `tests/test_dataguard_process_legacy_does_not_use_modern_view.sh`, `tests/test_dataguard_process_modern_does_not_use_legacy_default.sh`, `tests/test_dataguard_process_modern_uses_supported_columns.sh`, `tests/test_v_dataguard_process_columns_match_dictionary_model.sh`, `tests/test_dataguard_process_variant_resolution_11g.sh`, `tests/test_dataguard_process_variant_resolution_121.sh`, `tests/test_dataguard_process_variant_resolution_122.sh`, `tests/test_dataguard_process_variant_resolution_19c.sh`, `tests/test_dataguard_process_variant_resolution_23ai.sh`.

# Documentation requirements

Alimenta `apply-analysis.md`/`transport-analysis.md`.

# Change history

v1.0.0 — Fase 5, creación inicial.
v2.0.0 — PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING: consumo del modelo legacy/modern de `Q-DG-MANAGED-PROCESS-001` vía el modelo lógico `dataguard_process`.
v3.0.0 — PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING: metadata corregida contra Oracle Database Reference (V$DATAGUARD_PROCESS min_version real 12.2, no 11.2; STATUS/CLIENT_PROCESS no son columnas reales de esa vista); partición legacy(10.2–12.1)/modern(12.2–23.0) sin solapamiento; modelo lógico renombrado a process_name/process_role/process_action/client_pid/thread/sequence/source_view/source_variant — process_role NOT_AVAILABLE sólo en legacy, thread/sequence soportados en ambas.
