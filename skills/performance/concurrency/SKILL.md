---
name: concurrency
display_name: "Concurrency"
id: performance/concurrency
version: 1.0.0
domain: performance
status: active
---

# Purpose

Vista consolidada de contención de concurrencia — composición de `performance/blocking` (relación sesión-a-sesión) y `performance/locking` (tipo/modo de lock) — sin evidencia propia adicional.

# Scope

**En alcance:** composición de blocking + locking en una sola vista de contención.
**Fuera de alcance:** detalle específico (delegado a los skills fuente).

# Supported Oracle versions

10g–23ai (hereda de `performance/blocking`/`performance/locking`).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary.

# Licensing

Ninguna.

# Prerequisites

`performance/blocking` y `performance/locking` ejecutados en la misma sesión.

# Required evidence

Ninguna propia — reutiliza `evidence_refs` de `performance/blocking`/`performance/locking`.

# Optional evidence

Ninguna adicional.

# Data collection

Ninguna propia.

# Diagnostic logic / Decision tree

```text
1. Componer la cadena de bloqueo (performance/blocking) con el detalle de tipo de lock (performance/locking) por blocker_sid.
2. Reportar una vista unificada: quién bloquea, con qué tipo de lock, a cuántas sesiones, por cuánto tiempo.
3. Enqueue waits (latch free, buffer busy waits) capturados por performance/wait-events se referencian aquí como contexto adicional de concurrencia, no re-evaluados.
```

# Normal behavior

Ninguna cadena de bloqueo sostenida más allá del umbral configurado.

# Abnormal patterns

Ver `performance/blocking`/`performance/locking`.

# Root cause patterns

Ver `performance/blocking`/`performance/locking`.

# Correlation rules

Composición directa, sin lógica adicional propia.

# False positives

Ver skills fuente.

# Confidence model

Hereda de los skills fuente.

# Output schema

```yaml
concurrency_summary:
  blocking_chains: [...]     # de performance/blocking
  lock_details: [...]        # de performance/locking
```

# Related skills

`performance/blocking`, `performance/locking`, `performance/wait-events`, `performance/parallelism`.

# Escalation

Hereda de `performance/blocking`.

# Examples

Ver `tests/fixtures/19c-blocking.yaml`.

# Data sensitivity / Context budget

Hereda de los skills fuente. Presupuesto bajo (composición).

# Tests

Cubierto por `tests/test_blocking_detection.sh`, `tests/test_locking_analysis.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — vista de composición de blocking + locking. |
