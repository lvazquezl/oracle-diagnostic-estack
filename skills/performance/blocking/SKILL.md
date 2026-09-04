---
name: blocking
display_name: "Blocking"
id: performance/blocking
version: 1.0.0
domain: performance
status: active
---

# Purpose

Detectar cadenas de bloqueo activas (blocker/waiter) y su duración — nunca generando ni ejecutando `ALTER SYSTEM KILL SESSION`.

# Scope

**En alcance:** relación sesión bloqueante/bloqueada, evento de espera, duración, `sql_id` de la sesión bloqueada.
**Fuera de alcance:** ejecución de `KILL SESSION` (prohibido absolutamente), tipo de lock específico (`performance/locking`).

# Supported Oracle versions

10g–23ai. `V$SESSION.BLOCKING_SESSION` estable desde 10g.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (bloqueo cross-instance visible vía `GV$SESSION` — este skill usa `V$SESSION` por instancia; agregación cross-instance es responsabilidad de `oracle-rac-analyst` si se requiere). NON-CDB y CDB. Primary (bloqueo de aplicación no aplica en standby en mount).

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-BLOCKING-001`

# Optional evidence

- `Q-PERF-LOCKS-001` (tipo de lock específico)
- `Q-PERF-WAIT-ASH-001` (contexto histórico de la ventana de bloqueo)

# Data collection

Lectura de `V$SESSION` (`blocking_session`, `event`, `wait_class`, `seconds_in_wait`, `sql_id`).

# Diagnostic logic / Decision tree

```text
1. Leer cadenas waiter → blocker (Q-PERF-BLOCKING-001).
2. Agrupar por blocker_sid — un blocker puede tener múltiples waiters.
3. severity según seconds_in_wait: LOW (<10s), MEDIUM (10-60s), HIGH (>60s) — ajustable por baseline del ambiente.
4. Nunca generar un comando KILL SESSION ejecutable — sólo texto de recomendación NOT_EXECUTED/HUMAN_REVIEW_REQUIRED si el DBA lo solicita explícitamente.
```

# Normal behavior

Sin cadenas de bloqueo activas, o bloqueos transitorios de corta duración (<1-2 segundos, resueltos por el flujo normal de transacciones).

# Abnormal patterns

Un blocker con múltiples waiters sostenido por más de el umbral configurado; cadenas de bloqueo anidadas (un waiter que a su vez bloquea a otros).

# Root cause patterns

`PROBABLE_CAUSE` de contención de aplicación requiere identificar el `sql_id`/patrón de transacción del blocker (vía `performance/top-sql` si se correlaciona) — nunca `CONFIRMED_ROOT_CAUSE` sin validación de `incident-root-cause-analyst`.

# Correlation rules

Cruzar `blocker_sid` con `performance/top-sql`/`performance/locking` para entender qué transacción está reteniendo el lock.

# False positives

Bloqueos de milisegundos a segundos son parte del funcionamiento normal de cualquier base de datos transaccional — no se reportan como finding salvo que excedan el umbral configurado.

# Confidence model

`FACT` para la cadena de bloqueo leída directamente. `HYPOTHESIS`/`PROBABLE_CAUSE` para la causa de fondo (diseño de transacción, ausencia de índice, etc.) sólo con correlación adicional.

# Output schema

```yaml
findings:
  - blocker_sid: number
    waiter_sids: [number]
    event: string
    max_seconds_in_wait: number
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|HYPOTHESIS
    evidence_refs: [EVD-...]
recommendations:
  - manual_execution_required: true
    note: "NOT_EXECUTED — cualquier KILL SESSION es responsabilidad del DBA, nunca ejecutado por el e-stack"
```

# Related skills

`performance/locking`, `performance/concurrency`, `performance/top-sql`, `performance/ash-analysis`.

# Escalation

Bloqueo sostenido con impacto significativo → `incident-root-cause-analyst`. Recomendación de `KILL SESSION` → siempre `NOT_EXECUTED`, texto únicamente.

# Examples

Ver `tests/fixtures/19c-blocking.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (`sql_id`, `sid`/`serial#`). Presupuesto medio.

# Tests

`tests/test_blocking_detection.sh`, `tests/test_no_kill_session_execution.sh`, `tests/test_manual_kill_command_marked_not_executed.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — nunca ejecuta KILL SESSION, sólo texto NOT_EXECUTED. |
