---
name: load-profile
display_name: "Load Profile"
id: performance/load-profile
version: 1.0.0
domain: performance
status: active
---

# Purpose

Ensamblar el Load Profile de una ventana (DB Time, DB CPU, top wait classes, top SQL resumido) como la vista de entrada de `oracle-performance-analyst` antes de profundizar en un área específica.

# Scope

**En alcance:** composición del Load Profile a partir de la evidencia ya recolectada por `performance/db-time`, `performance/db-cpu`, `performance/wait-events`, `performance/top-sql` — no introduce evidencia propia.
**Fuera de alcance:** profundización en cualquiera de esas áreas (delegada a su skill específico).

# Supported Oracle versions

10g–23ai (hereda de los skills que compone).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary (foco principal).

# Licensing

Ninguna propia — hereda el licenciamiento de cada fuente que compone (AWR licenciado, ruta estándar sin licencia).

# Prerequisites

Al menos `performance/db-time` y `performance/wait-events` ya ejecutados en la misma sesión (evidencia reutilizada, no re-consultada).

# Required evidence

Ninguna propia — reutiliza `evidence_refs` de `performance/db-time`, `performance/db-cpu`, `performance/wait-events`, `performance/top-sql`.

# Optional evidence

`performance/io`, `performance/sga`, `performance/pga` si el DBA pide un Load Profile extendido con memoria/I/O.

# Data collection

Ninguna — este skill es puramente de composición/presentación sobre evidencia ya recolectada.

# Diagnostic logic / Decision tree

```text
1. Componer: {db_time_sec, db_cpu_sec, top_wait_class, top_wait_pct, top_sql_id, top_sql_pct}.
2. No agrega interpretación nueva más allá de la ya producida por cada skill fuente — es una vista consolidada.
3. Si algún skill fuente reportó UNDETERMINED/LICENSE_RESTRICTED, el Load Profile lo refleja explícitamente en esa dimensión, sin ocultarlo.
```

# Normal behavior

N/A — este skill no evalúa normal/anormal por sí mismo, delega esa evaluación a los skills fuente.

# Abnormal patterns

N/A — ver skills fuente.

# Root cause patterns

N/A — ver `agents/oracle-performance-analyst/AGENT.md#correlation-model`.

# Correlation rules

Ninguna adicional — es el punto de entrada que dirige hacia la correlación detallada de cada área.

# False positives

N/A.

# Confidence model

Hereda la confianza más baja entre las fuentes compuestas (si una fuente es `UNDETERMINED`, el Load Profile lo declara, no lo omite).

# Output schema

```yaml
load_profile:
  db_time_sec: number
  db_cpu_sec: number
  top_wait_class: string
  top_wait_pct_db_time: number
  top_sql_id: string
  top_sql_pct_db_time: number
  sources_status: {db_time: string, db_cpu: string, wait_events: string, top_sql: string}
```

# Related skills

`performance/db-time`, `performance/db-cpu`, `performance/wait-events`, `performance/top-sql`, `performance/awr-analysis`, `performance/statspack-analysis`.

# Escalation

Ninguna propia — hereda la de los skills fuente.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad hereda de las fuentes (MEDIA típicamente). Presupuesto bajo (composición, no recolección nueva).

# Tests

Cubierto por los tests de los skills fuente; sin tests propios adicionales.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — vista de composición del Load Profile, sin evidencia propia. |
