---
name: hard-parse
display_name: "Hard Parse"
id: performance/hard-parse
version: 1.0.0
domain: performance
status: active
---

# Purpose

Evaluar parse count total/hard, session cursor cache hits y su correlación con library cache/shared pool y executions — sin recomendar `cursor_sharing` sin contexto.

# Scope

**En alcance:** `parse count (total)`, `parse count (hard)`, `session cursor cache hits`, `execute count` de instancia.
**Fuera de alcance:** cambio de `cursor_sharing`/parámetros de parsing (siempre recomendación manual con contexto completo).

# Supported Oracle versions

10g–23ai. `V$SYSSTAT` estable en todo el rango para estos nombres de estadística.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB. Primary.

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-HARDPARSE-001`

# Optional evidence

- `Q-PERF-TOPSQL-CURRENT-001`/`Q-PERF-TOPSQL-001` (correlación con SQL de alta frecuencia)

# Data collection

Lectura de `V$SYSSTAT`.

# Diagnostic logic / Decision tree

```text
1. Leer parse_count_total, parse_count_hard, session_cursor_cache_hits, execute_count.
2. hard_parse_ratio = parse_count_hard / NULLIF(parse_count_total, 0).
3. IF hard_parse_ratio alto AND execute_count alto → HYPOTHESIS: posible ausencia de bind variables o cursor_sharing subóptimo — nunca recomendar cursor_sharing sin ver el patrón de SQL real (literales vs. binds) vía performance/top-sql.
4. Correlacionar con performance/library-cache (reloads altos correlacionan con hard parse alto).
```

# Normal behavior

`hard_parse_ratio` bajo respecto al total de parses, `session_cursor_cache_hits` alto (cursores reutilizados eficientemente).

# Abnormal patterns

`hard_parse_ratio` sostenidamente alto con alto volumen de ejecuciones — candidato de investigación de literales no parametrizados.

# Root cause patterns

Ninguno confirmado sin inspeccionar SQL real (`performance/top-sql` con múltiples `sql_id` similares por texto — fuera de alcance sin SQL text habilitado explícitamente).

# Correlation rules

Cruzar siempre con `performance/library-cache` (reloads) antes de escalar severidad.

# False positives

Un `hard_parse_ratio` alto en una ventana de arranque de instancia (cache frío) no es un problema sostenido — se requiere persistencia.

# Confidence model

`FACT` para los contadores leídos directamente. `HYPOTHESIS` para cualquier interpretación de causa (literales, cursor_sharing) sin evidencia de SQL real.

# Output schema

```yaml
findings:
  - parse_count_total: number
    parse_count_hard: number
    hard_parse_ratio: number
    session_cursor_cache_hits: number
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|HYPOTHESIS
    evidence_refs: [EVD-...]
```

# Related skills

`performance/library-cache`, `performance/shared-pool`, `performance/db-cpu`, `performance/top-sql`.

# Escalation

Recomendación de `cursor_sharing`/cambio de aplicación → siempre manual con contexto completo (nunca "cambiar cursor_sharing" sin ver el patrón real de SQL).

# Examples

Ver `tests/fixtures/19c-high-cpu.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA. Presupuesto bajo.

# Tests

Sin test dedicado adicional — cubierto por `tests/test_query_cost_low.sh` (contrato de la query).

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — nunca recomienda cursor_sharing sin evidencia del patrón real de SQL. |
