---
name: plan-regression
display_name: "Plan Regression"
id: performance/plan-regression
version: 1.0.0
domain: performance
status: active
---

# Purpose

Detectar cuando un mismo `SQL_ID` presenta múltiples `PLAN_HASH_VALUE` en una ventana y correlacionar elapsed/CPU/reads/gets/executions entre planes para identificar regresión probable — sin recomendar SQL Plan Management automáticamente.

# Scope

**En alcance:** historial de `plan_hash_value` por `sql_id` sobre ventana AWR, comparación de métricas entre planes.
**Fuera de alcance:** creación/aceptación de SQL Plan Baselines, ejecución de cualquier cambio de plan.

# Supported Oracle versions

10g–23ai. `DBA_HIST_SQLSTAT` estable en todo el rango para las columnas usadas.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary.

# Licensing

Requiere Diagnostics Pack (`Q-PERF-PLAN-HIST-001`) — sin AWR histórico no hay forma confiable de reconstruir el historial de planes en el tiempo; sin fallback no licenciado (a diferencia de wait events/top SQL). Sin confirmación, `capability_status: LICENSE_RESTRICTED`.

# Prerequisites

`constraints.sql_id` (típicamente identificado por `performance/top-sql`), `constraints.time_window`, `constraints.license_confirmed.diagnostics_pack: true`.

# Required evidence

- `Q-PERF-PLAN-HIST-001`

# Optional evidence

- `Q-PERF-PLAN-001` (plan actual, para inspeccionar el más reciente en detalle)

# Data collection

Lectura de `DBA_HIST_SQLSTAT` agrupado por `plan_hash_value` para un `sql_id` específico.

# Diagnostic logic / Decision tree

```text
1. Agrupar por (sql_id, plan_hash_value): first_seen, last_seen, executions, elapsed_per_exec_sec.
2. IF más de un plan_hash_value en la ventana:
     comparar elapsed_per_exec_sec entre planes
     IF el plan más reciente tiene elapsed_per_exec_sec significativamente mayor que el anterior
          → HYPOTHESIS: plan regression probable
3. Sugerir al DBA investigar (nunca ejecutar): estadísticas, bind peeking, adaptive behavior, optimizer parameters, cambios de SQL, plan management — según versión/licensing.
4. Nunca recomendar SPM (SQL Plan Management) automáticamente — sólo señalar la posibilidad como investigación manual del DBA.
```

# Normal behavior

Un único `plan_hash_value` estable en la ventana, o múltiples planes con `elapsed_per_exec_sec` comparable entre sí (cambio de plan sin degradación).

# Abnormal patterns

Múltiples `plan_hash_value` con `elapsed_per_exec_sec` divergente (el más reciente notablemente peor) — candidato de plan regression.

# Root cause patterns

`PROBABLE_CAUSE` de plan regression requiere: múltiples planes confirmados + degradación medible de `elapsed_per_exec_sec` + ventana de degradación coincidente con el cambio de plan. Nunca `CONFIRMED_ROOT_CAUSE` sin validación del DBA sobre qué causó el cambio (estadísticas, parámetro, versión de Oracle, etc.).

# Correlation rules

Cruzar con `performance/execution-plan` para inspeccionar el detalle de cada `plan_hash_value` involucrado.

# False positives

Un cambio de plan no es regresión si `elapsed_per_exec_sec` mejora o se mantiene comparable — sólo se reporta cuando hay degradación medible.

# Confidence model

`FACT` para el historial de planes y sus métricas. `HYPOTHESIS` para "posible regresión" con un solo punto de comparación. `PROBABLE_CAUSE` con degradación medible + ventana coincidente + ausencia de contradicción (ej. cambio de volumen de datos legítimo que explicaría el aumento).

# Output schema

```yaml
findings:
  - sql_id: string
    plans: [{plan_hash_value: number, first_seen: string, last_seen: string, executions: number, elapsed_per_exec_sec: number}]
    regression_detected: bool
    severity: LOW|MEDIUM|HIGH
    confidence: HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`performance/top-sql`, `performance/execution-plan`, `performance/awr-analysis`.

# Escalation

Regresión confirmada con impacto significativo → recomendación manual al DBA (investigar SPM/estadísticas), nunca ejecutado automáticamente; escalable a `change-advisor` sólo tras aprobación explícita.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA (`sql_id`/`plan_hash_value`, sin SQL text). Presupuesto medio, acotado a un `sql_id` por invocación.

# Tests

`tests/test_plan_regression.sh`, `tests/test_multiple_plan_hashes.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — detección de múltiples plan_hash_value con degradación medible, nunca recomienda SPM automáticamente. |
