---
name: wait-classes
display_name: "Wait Classes"
id: performance/wait-classes
version: 1.0.0
domain: performance
status: active
---

# Purpose

Agregar wait events por `wait_class` para dar una vista de alto nivel de dónde se concentra el tiempo de espera no-idle antes de profundizar evento por evento.

# Scope

**En alcance:** agregación de `performance/wait-events` por `wait_class` (`User I/O`, `System I/O`, `Concurrency`, `Commit`, `Configuration`, `Network`, `Application`, `Cluster`, `Administrative`, `Scheduler`, `Other`, `CPU`).
**Fuera de alcance:** desglose por evento individual (delegado a `performance/wait-events`).

# Supported Oracle versions

10g–23ai — hereda de `performance/wait-events`.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary.

# Licensing

Hereda de la fuente usada por `performance/wait-events` (AWR/ASH licenciado, Statspack/dinámico sin licencia).

# Prerequisites

`performance/wait-events` ya ejecutado en la misma sesión (evidencia reutilizada).

# Required evidence

Ninguna propia — reutiliza `evidence_refs` de `performance/wait-events`.

# Optional evidence

Ninguna adicional.

# Data collection

Ninguna — composición sobre evidencia ya recolectada.

# Diagnostic logic / Decision tree

```text
1. Agrupar wait events por wait_class, sumar total_wait_time_sec.
2. Ordenar por tiempo total descendente.
3. IF top wait_class = Cluster AND arquitectura no es RAC → error de datos, nunca reportar Cluster como causa fuera de RAC (ver # 16 del prompt de Fase 3).
4. Reportar la distribución completa (no sólo el top-1) para dar contexto proporcional.
```

# Normal behavior

Distribución sin un único `wait_class` dominando de forma desproporcionada respecto al workload esperado.

# Abnormal patterns

Un `wait_class` representando >70% del tiempo de espera no-idle total sin explicación de workload.

# Root cause patterns

Ninguno propio — delega a `performance/wait-events` para el evento específico dentro del `wait_class` dominante.

# Correlation rules

Siempre reportar `pct_db_time` de cada `wait_class`, no sólo el tiempo absoluto.

# False positives

Un `wait_class` con tiempo total alto en una ventana larga puede ser normal si `pct_db_time` es bajo — ver `# 17. WAIT ANALYSIS RULE`.

# Confidence model

`FACT` — es agregación directa de datos ya leídos por `performance/wait-events`.

# Output schema

```yaml
findings:
  - wait_class: string
    total_wait_time_sec: number
    pct_db_time: number
    evidence_refs: [EVD-...]
```

# Related skills

`performance/wait-events`, `performance/db-time`.

# Escalation

Igual que `performance/wait-events` según el `wait_class` dominante.

# Examples

Ver `tests/fixtures/19c-high-cpu.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA (sólo nombres de clase y agregados). Presupuesto bajo.

# Tests

`tests/test_awr_wait_events.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — agregación por wait_class sobre evidencia de performance/wait-events. |
