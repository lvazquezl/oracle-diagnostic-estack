---
name: temp
display_name: "TEMP (Performance)"
id: performance/temp
version: 1.0.0
domain: performance
status: active
---

# Purpose

Analizar rendimiento de TEMP — quién está consumiendo TEMP ahora mismo (sorts/hashes con spill a disco) y por qué — extendiendo `oracle/temp` (capacidad) con la dimensión de rendimiento, sin duplicar esa query.

# Scope

**En alcance:** uso activo de TEMP por sesión/SQL_ID (`V$SORT_USAGE`).
**Fuera de alcance:** capacidad/configuración de tempfiles (`oracle/temp`, Oracle Core — reutilizado como contexto, no reconsultado).

# Supported Oracle versions

10g–23ai. `V$SORT_USAGE` estable en todo el rango.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB. Primary (uso activo refleja sesiones de usuario).

# Licensing

Ninguna.

# Prerequisites

`oracle/temp` (Oracle Core) ejecutado en la misma sesión para contexto de capacidad — este skill no lo re-consulta.

# Required evidence

- `Q-PERF-TEMP-001`

# Optional evidence

- `Q-ORA-TEMP-001` (Oracle Core, capacidad — reutilizado por referencia, no re-ejecutado)
- `Q-PERF-PGA-001` (correlación — over-allocation de PGA incrementa spill a TEMP)

# Data collection

Lectura de `V$SORT_USAGE` join `V$SESSION`.

# Diagnostic logic / Decision tree

```text
1. Leer sesiones activas usando TEMP (sid, serial#, sql_id, tablespace, bytes_used).
2. Ordenar por bytes_used descendente.
3. Correlacionar con performance/pga — over_allocation_count alto en PGA sugiere que el spill a TEMP es consecuencia de PGA insuficiente, no necesariamente un problema de la query en sí.
4. Correlacionar con oracle/temp (capacidad) — si el tempfile está cerca de su límite Y hay uso activo alto, escalar severidad.
```

# Normal behavior

Uso de TEMP puntual y distribuido, sin una única sesión/SQL_ID dominando el consumo de forma sostenida.

# Abnormal patterns

Un `sql_id` consumiendo una proporción desproporcionada de TEMP de forma repetida — candidato de revisión de plan (`performance/execution-plan`, posible sort/hash sin índice adecuado).

# Root cause patterns

Ninguno confirmado sin correlación con `performance/execution-plan` del `sql_id` responsable y `performance/pga` (over-allocation).

# Correlation rules

Cruzar siempre con `performance/pga` antes de concluir que un SQL específico es ineficiente — puede ser PGA subdimensionada para el workload agregado, no un problema de ese SQL en particular.

# False positives

Uso puntual y transitorio de TEMP durante una operación batch conocida (ETL, index rebuild) no es una anomalía.

# Confidence model

`FACT` para el uso leído directamente. `HYPOTHESIS` para atribuir el consumo a ineficiencia de plan vs. PGA insuficiente, sin correlación cruzada.

# Output schema

```yaml
findings:
  - sid: number
    sql_id: string|null
    tablespace: string
    bytes_used: number
    evidence_refs: [EVD-...]
```

# Related skills

`oracle/temp`, `performance/pga`, `performance/execution-plan`.

# Escalation

Consumo sostenido y desproporcionado → `performance/execution-plan` para el `sql_id` responsable.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (`sql_id`, `sid`/`serial#`). Presupuesto medio.

# Tests

Sin test dedicado adicional — cubierto por `tests/test_query_cost_medium.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — extiende oracle/temp con la dimensión de uso activo, sin duplicar su query de capacidad. |
