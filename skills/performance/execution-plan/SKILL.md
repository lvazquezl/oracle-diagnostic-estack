---
name: execution-plan
display_name: "Execution Plan"
id: performance/execution-plan
version: 1.1.0
domain: performance
status: active
---

# Purpose

Analizar el plan de ejecución de un `SQL_ID` específico — operaciones, join methods, access paths, cardinalidad, costo — sin declarar patrones categóricamente malos por definición (ej. un Full Table Scan no es malo por sí solo).

# Scope

**En alcance:** plan actual en shared pool (`V$SQL_PLAN`) para un `sql_id`/`plan_hash_value` ya identificado (típicamente por `performance/top-sql`); adicionalmente (desde Fase 3 Completion Hardening) ingesta de un plan pegado como texto (`DBMS_XPLAN.DISPLAY` u origen equivalente) vía `parsers/performance/execution_plan_parser.py`.
**Fuera de alcance:** generación/modificación de planes, SQL Tuning Advisor, SQL Plan Baselines de escritura.

# Report ingest

`FILE → type_detector (requiere firma "| Id  | Operation" — si no está presente, UNSUPPORTED_FORMAT, nunca se adivina) → parsers/performance/execution_plan_parser.py → ParsedReport (sections: plan_operations, predicates)`. Predicados enmascarados (literales entre comillas reemplazados por `'<MASKED_LITERAL>'`, nombres de objeto tokenizados); nunca se extrae SQL text.

# Supported Oracle versions

10g–23ai. `V$SQL_PLAN` estable en todo el rango; operaciones paralelas/adaptativas presentes según la versión (adaptive plans desde 12c, declarado `NOT_APPLICABLE` en versiones previas cuando corresponda).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary (el shared pool de un standby refleja su propia actividad, no comparable 1:1).

# Licensing

Ninguna — `V$SQL_PLAN` no requiere Diagnostics/Tuning Pack.

# Prerequisites

`constraints.sql_id` y `constraints.plan_hash_value` (o el más reciente si no se especifica), típicamente obtenidos de `performance/top-sql`.

# Required evidence

- `Q-PERF-PLAN-001`

# Optional evidence

- `parsers/performance/execution_plan_parser.py` (plan pegado como texto por el DBA)

# Data collection

Lectura de `V$SQL_PLAN` para el `sql_id`/`plan_hash_value` solicitado — nunca exploratorio sobre todo el shared pool.

# Diagnostic logic / Decision tree

```text
1. Leer las operaciones del plan (id, parent_id, operation, options, object_name, object_type, cardinality, cost, predicates).
2. Reconstruir el árbol de ejecución (parent_id → id).
3. Identificar: full scans, index access, joins (hash/nested loops/sort merge), sort operations, operaciones paralelas.
4. NO declarar un Full Table Scan malo por definición — evaluar en contexto (tamaño de tabla, selectividad, si es esperado por diseño).
5. Si cardinalidad estimada difiere drásticamente de lo esperado por el DBA → candidato a HYPOTHESIS de estadísticas desactualizadas (nunca se recomienda un ANALYZE/gather stats sin evidencia adicional del contexto).
```

# Normal behavior

Plan consistente con el diseño de la query y los índices/particiones disponibles; cardinalidad estimada razonablemente cercana al volumen real de datos conocido.

# Abnormal patterns

Full Table Scan sobre una tabla grande donde existe un índice selectivo aplicable y no se usa (candidato de investigación, no una recomendación automática de hint); Nested Loops sobre conjuntos grandes sin índice en el lado interno (candidato de alto costo).

# Root cause patterns

Ninguno confirmado sin `performance/plan-regression` (si hay múltiples planes) y sin contexto adicional del DBA sobre el diseño esperado de la query.

# Correlation rules

Cruzar predicados con estadísticas de la tabla/índice cuando estén disponibles (fuera de alcance directo de este skill — se declara como evidencia adicional requerida si no está disponible).

# False positives

Un plan con `cost` alto no es automáticamente un problema — el costo del optimizador es una estimación relativa, no un tiempo real; se correlaciona con `elapsed_per_exec` real de `performance/top-sql` antes de juzgar.

# Confidence model

`FACT` para las operaciones/predicados leídos directamente. `HYPOTHESIS` para cualquier interpretación de eficiencia del plan sin datos reales de ejecución correlacionados.

# Output schema

```yaml
findings:
  - sql_id: string
    plan_hash_value: number
    operations: [{id: number, operation: string, options: string, object_name: string, cardinality: number, cost: number}]
    full_scans_detected: [string]
    evidence_refs: [EVD-...]
```

# Related skills

`performance/top-sql`, `performance/plan-regression`.

# Escalation

Múltiples planes detectados para el mismo `sql_id` → `performance/plan-regression`. Recomendación de índice/hint → siempre manual, `manual_execution_required: true`, nunca ejecutado.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA-BAJA (predicados pueden contener literales de aplicación — enmascarados; nunca SQL text completo). Presupuesto bajo — acotado a un `sql_id` específico.

# Tests

`tests/test_plan_regression.sh` (compartido con `performance/plan-regression`), `tests/test_report_type_detection_execution_plan.sh`, `tests/test_execution_plan_parser.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — análisis de plan actual, nunca declara Full Table Scan malo por definición. |
| 1.1.0 | Fase 3 Completion & Portability Hardening | Añadida ruta de ingesta de plan en texto vía `parsers/performance/execution_plan_parser.py`, predicados enmascarados. |
