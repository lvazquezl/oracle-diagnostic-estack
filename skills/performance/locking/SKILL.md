---
name: locking
display_name: "Locking"
id: performance/locking
version: 1.0.0
domain: performance
status: active
---

# Purpose

Analizar enqueue locks activos por tipo/modo (`TX`, `TM`, `UL`, etc.) — complemento de `performance/blocking` con el detalle de tipo de lock, no la relación sesión-a-sesión.

# Scope

**En alcance:** `V$LOCK` — tipo, modo, `id1`/`id2`, si el lock está bloqueando a otros (`block`).
**Fuera de alcance:** relación waiter/blocker sesión-a-sesión (`performance/blocking`).

# Supported Oracle versions

10g–23ai. `V$LOCK` estable en todo el rango.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary.

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-LOCKS-001`

# Optional evidence

- `Q-PERF-BLOCKING-001` (relación sesión-a-sesión)

# Data collection

Lectura de `V$LOCK` join `V$SESSION`.

# Diagnostic logic / Decision tree

```text
1. Leer locks activos con lmode > 0 (Q-PERF-LOCKS-001).
2. Identificar locks con block = 1 (bloqueando activamente a otra sesión).
3. Clasificar por type: TX (transacción/row lock), TM (DML/tabla), UL (definido por usuario), otros.
4. Correlacionar con performance/blocking para la relación waiter/blocker completa.
```

# Normal behavior

Locks `TX`/`TM` transitorios asociados a transacciones activas normales, sin locks de larga duración con `block = 1`.

# Abnormal patterns

Un lock `TM` (nivel tabla) sostenido con `block = 1` — puede indicar DDL en curso o modo de lock de tabla inesperado (`LOCK TABLE` explícito de la aplicación).

# Root cause patterns

Ninguno confirmado sin correlacionar con `performance/blocking`/`performance/top-sql` para identificar la transacción responsable.

# Correlation rules

Cruzar siempre con `performance/blocking` para la cadena completa waiter→blocker.

# False positives

Locks `TX` de corta duración son el funcionamiento normal de cualquier transacción — no son un finding por sí solos.

# Confidence model

`FACT` para los locks leídos directamente. `HYPOTHESIS` para la causa de fondo.

# Output schema

```yaml
findings:
  - sid: number
    lock_type: string
    lock_mode: string
    blocking: bool
    sql_id: string|null
    evidence_refs: [EVD-...]
```

# Related skills

`performance/blocking`, `performance/concurrency`, `performance/top-sql`.

# Escalation

Igual que `performance/blocking`.

# Examples

Ver `tests/fixtures/19c-blocking.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (`sql_id`, `sid`/`serial#`). Presupuesto medio.

# Tests

`tests/test_locking_analysis.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — detalle de tipo/modo de lock, complementario a performance/blocking. |
