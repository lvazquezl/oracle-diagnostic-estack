---
name: trending
display_name: "Trending"
id: performance/trending
version: 1.0.0
domain: performance
status: active
---

# Purpose

Comparar múltiples snapshots/evidence points de la misma métrica (baseline comparison, before/after, period-over-period) — sin generar forecast complejo (eso es `capacity-analyst`).

# Scope

**En alcance:** comparación de 2+ mediciones de la misma métrica/query en distintos momentos, ya recolectadas por otros skills de `performance/*` en la misma sesión o en sesiones previas cacheadas.
**Fuera de alcance:** proyección/forecast de capacidad (delegado a `capacity-analyst`), recolección de evidencia propia — este skill compone evidencia ya existente.

# Supported Oracle versions

10g–23ai (hereda de las métricas que compara).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary y Standby (según la métrica comparada — estructural aplica a ambos, actividad de usuario sólo a Primary).

# Licensing

Ninguna propia — hereda de la fuente de cada snapshot comparado.

# Prerequisites

Al menos 2 evidence points de la misma métrica, con `time_window`/timestamp distinto cada uno.

# Required evidence

Ninguna propia — reutiliza `evidence_refs` de snapshots ya recolectados por otros skills `performance/*`.

# Optional evidence

Ninguna adicional.

# Data collection

Ninguna — composición sobre evidencia ya existente.

# Diagnostic logic / Decision tree

```text
1. Alinear 2+ evidence points de la misma métrica por timestamp/ventana.
2. Calcular delta absoluto y porcentual entre puntos.
3. baseline_comparison: comparar contra un punto de referencia designado explícitamente por el DBA (nunca inferido automáticamente).
4. before_after: comparar una ventana antes y después de un cambio conocido (deploy, cambio de parámetro, etc.).
5. period_over_period: comparar el mismo horario en distintos días/semanas.
6. No generar proyección/forecast — eso es exclusivo de capacity-analyst.
```

# Normal behavior

Métricas estables entre snapshots comparables (mismo horario/carga esperada).

# Abnormal patterns

Degradación sostenida entre snapshots comparables sin cambio de workload conocido — candidato de investigación más profunda en el skill correspondiente (ej. `performance/db-time`, `performance/top-sql`).

# Root cause patterns

Ninguno propio — señala la tendencia, la causa de fondo se investiga en el skill de la métrica específica.

# Correlation rules

Nunca comparar snapshots que no sean genuinamente comparables (distinto workload esperado, distinta arquitectura, distinto rol de base de datos) — declarar explícitamente si la comparación no es válida.

# False positives

Comparar una ventana de horario pico contra una de horario valle sin ajustar por eso produce una "degradación" espuria — este skill exige que el DBA confirme que los períodos son comparables.

# Confidence model

`FACT` para los deltas calculados directamente. `HYPOTHESIS` para cualquier interpretación de causa detrás de la tendencia observada.

# Output schema

```yaml
findings:
  - metric: string
    point_a: {timestamp: string, value: number}
    point_b: {timestamp: string, value: number}
    delta_pct: number
    comparison_type: baseline_comparison|before_after|period_over_period
    evidence_refs: [EVD-...]
```

# Related skills

Todos los `performance/*` que producen una métrica comparable en el tiempo; `capacity-analyst` (forecast, fuera de este skill).

# Escalation

Tendencia de degradación sostenida y significativa → el skill de la métrica específica para profundizar; forecast de capacidad → `capacity-analyst`.

# Examples

Ninguna fixture dedicada — depende de al menos 2 evidence points provistos en la sesión.

# Data sensitivity / Context budget

Hereda de las métricas comparadas. Presupuesto bajo (composición, no recolección nueva).

# Tests

Sin test dedicado adicional en esta fase — cubierto conceptualmente por los tests de las métricas fuente.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — comparación baseline/before-after/period-over-period sin forecast, delegado a capacity-analyst. |
