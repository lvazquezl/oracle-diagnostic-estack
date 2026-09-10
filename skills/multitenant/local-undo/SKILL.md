---
name: local-undo
id: multitenant/local-undo
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Detectar el modo de undo del CDB (shared/local) y sus efectos diagnósticos — nunca asumido en 12.1, nunca cambiado por el e-stack (`# 19`, `# 20` del prompt de Fase 6).

# Supported Oracle versions

12.2–23ai para el modo local (`local_undo`, columna real de `V$PDBS`, introducida en 12.2). 12.1 se reporta siempre `undo_mode: SHARED` por diseño de versión (Local Undo no existe en ese release).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

- `Q-CDB-PDB-STATE-001` (`V$PDBS.local_undo`, variante 12.2+)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-CDB-PDB-STATE-001`.

# Collector IDs

Ninguno propio.

# Read-only operations

Lectura de `V$PDBS.local_undo`.

# Forbidden operations

Nunca ejecuta ninguna conversión de modo undo ni cambia `LOCAL_UNDO_ENABLED` (`# 20`).

# Decision logic

1. Si la versión es 12.1: `undo_mode = SHARED` por definición de versión, sin consultar `local_undo` (esa columna no existe ahí).
2. Si la versión es 12.2+: leer `local_undo` directamente (`1` = local, `0` = shared) — nunca inferido.
3. Publicar el modo para que `multitenant/pdb-undo` lo consuma sin re-determinarlo.

# Normal state

Modo consistente con la configuración esperada por el DBA (declarada en `constraints` si aplica).

# Abnormal patterns

Modo inesperado (ej. el DBA esperaba local undo pero el CDB reporta shared) — señal de investigar configuración, nunca de corregir automáticamente.

# False positives

Ninguno — es una lectura directa de un flag booleano real.

# Correlation rules

Alimenta `multitenant/pdb-undo` directamente.

# Confidence model

`FACT` siempre.

# Severity

N/A — este skill no asigna severidad por sí solo; la presión de UNDO real la evalúa `multitenant/pdb-undo`.

# Output schema

```yaml
local_undo_enabled: bool|null
undo_mode: SHARED|LOCAL
evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-undo`.

# Escalation

N/A.

# Manual remediation guidance

Conversión de modo undo se entrega vía Manual Action Contract sólo si el DBA lo solicita explícitamente, `execution_status: NOT_EXECUTED` — nunca sugerido proactivamente sin justificación operativa clara.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_local_undo_version_awareness.sh`, `tests/test_122_local_undo_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.
