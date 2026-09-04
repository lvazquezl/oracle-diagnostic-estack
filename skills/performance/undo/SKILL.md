---
name: undo
display_name: "UNDO (Performance)"
id: performance/undo
version: 1.0.0
domain: performance
status: active
---

# Purpose

Analizar rendimiento de UNDO — tuned undo retention, max query length, unexpired/expired, indicios de `ORA-01555` cuando exista evidencia — reutilizando por completo la evidencia de `oracle/undo` (Oracle Core), sin duplicar query.

# Scope

**En alcance:** interpretación de rendimiento sobre `V$UNDOSTAT` ya recolectado por `oracle/undo`.
**Fuera de alcance:** cambio de `UNDO_RETENTION` (siempre recomendación manual); capacidad del undo tablespace (ya cubierta por `oracle/undo`, no reconsultada).

# Supported Oracle versions

10g–23ai (hereda de `oracle/undo`).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (cada instancia tiene su propio undo tablespace en RAC, o comparten uno según configuración — Oracle Core ya lo distingue). NON-CDB y CDB. Primary.

# Licensing

Ninguna.

# Prerequisites

`oracle/undo` (Oracle Core) ya ejecutado en la misma sesión.

# Required evidence

Ninguna propia — reutiliza `evidence_refs` de `Q-ORA-UNDO-001` (Oracle Core).

# Optional evidence

Ninguna adicional materializada — ver `# Known limitations` para `ORA-01555` (requiere evidencia de alert log/incidente, fuera de esta query).

# Data collection

Ninguna propia — interpretación sobre `V$UNDOSTAT` ya leído por `oracle/undo`.

# Diagnostic logic / Decision tree

```text
1. Reutilizar V$UNDOSTAT de oracle/undo: MAXQUERYLEN, UNDOBLKS, TUNED_UNDORETENTION.
2. IF MAXQUERYLEN se acerca a UNDO_RETENTION configurado → HYPOTHESIS de riesgo de ORA-01555 para queries largas.
3. Si el DBA reporta un ORA-01555 real → correlacionar con la ventana en que ocurrió (requiere timestamp del error, evidencia externa al catálogo actual).
4. Nunca cambiar UNDO_RETENTION — sólo recomendación manual con evidencia.
```

# Normal behavior

`MAXQUERYLEN` consistentemente por debajo de `TUNED_UNDORETENTION`, sin reportes de `ORA-01555`.

# Abnormal patterns

`MAXQUERYLEN` cercano o superior a `TUNED_UNDORETENTION` de forma repetida.

# Root cause patterns

`ORA-01555` confirmado requiere correlación con evidencia externa (alert log/incidente reportado) — este skill sólo evalúa el riesgo estructural, no confirma la causa de un error ya ocurrido sin esa evidencia.

# Correlation rules

Cruzar con `performance/trending` si hay múltiples snapshots de `V$UNDOSTAT` para evaluar tendencia de `MAXQUERYLEN`.

# False positives

Un `MAXQUERYLEN` puntualmente alto en una ventana con una query batch larga conocida no es un problema sistémico.

# Confidence model

`FACT` para los valores leídos (heredados de `oracle/undo`). `HYPOTHESIS` para el riesgo de `ORA-01555` sin un error real reportado.

# Output schema

```yaml
findings:
  - max_query_len_sec: number
    tuned_undo_retention_sec: number
    risk_of_ora_01555: bool
    confidence: FACT|HYPOTHESIS
    evidence_refs: [EVD-...]
```

# Related skills

`oracle/undo`, `performance/trending`.

# Escalation

Riesgo confirmado con `ORA-01555` real reportado → `incident-root-cause-analyst`. Recomendación de `UNDO_RETENTION`/tamaño de undo tablespace → siempre manual.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA. Presupuesto bajo (sin evidencia propia).

# Tests

Sin test dedicado adicional — cubierto por los tests de `oracle/undo`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — interpretación de rendimiento sobre evidencia ya recolectada por oracle/undo, sin query propia. |
