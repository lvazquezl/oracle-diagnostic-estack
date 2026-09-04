---
name: commit-redo
display_name: "Commit / Redo"
id: performance/commit-redo
version: 1.0.0
domain: performance
status: active
---

# Purpose

Analizar volumen de redo generado y comportamiento de commit, distinguiendo comportamiento de aplicación (commit frecuente) de latencia de storage de redo — como hipótesis separadas, nunca mezcladas.

# Scope

**En alcance:** `redo size`, `redo entries`, `user commits`, `user rollbacks` (`V$SYSSTAT`), correlacionados con `log file sync`/`log file parallel write` (`V$SYSTEM_EVENT`).
**Fuera de alcance:** configuración estructural de redo logs (`oracle/redo`, Oracle Core — reutilizado como contexto).

# Supported Oracle versions

10g–23ai. `V$SYSSTAT` estable en todo el rango para estos nombres de estadística.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB. Primary (redo de transacciones de aplicación es mínimo en standby, que aplica redo recibido — patrón distinto, fuera de alcance).

# Licensing

Ninguna.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-REDO-001`

# Optional evidence

- `Q-PERF-IO-001` (`log file sync`/`log file parallel write`)

# Data collection

Lectura de `V$SYSSTAT` y `V$SYSTEM_EVENT`.

# Diagnostic logic / Decision tree

```text
1. Leer redo_size_bytes, redo_entries, user_commits, user_rollbacks (Q-PERF-REDO-001).
2. Leer log file sync / log file parallel write (Q-PERF-IO-001).
3. IF log file sync alto AND user_commits alto AND log file parallel write normal
        → HYPOTHESIS: comportamiento de commit de aplicación (commit demasiado frecuente)
4. IF log file sync alto AND log file parallel write también alto
        → HYPOTHESIS: latencia de storage de redo (requiere evidencia OS/storage para PROBABLE_CAUSE)
5. redo_size_bytes / user_commits = redo promedio por transacción — útil para contexto, no para juzgar aisladamente.
```

# Normal behavior

`log file sync` proporcional al volumen de commits, sin latencia desproporcionada respecto a `log file parallel write`.

# Abnormal patterns

`user_rollbacks` desproporcionadamente alto respecto a `user_commits` (posible lógica de aplicación con reintentos/fallos frecuentes); `log file sync` alto sin explicación de volumen de commits ni latencia de storage evidente.

# Root cause patterns

Ver `agents/oracle-performance-analyst/AGENT.md#correlation-model` — los dos patrones certificados (commit de aplicación vs. latencia de storage) se mantienen como hipótesis separadas hasta validación cruzada.

# Correlation rules

Nunca reportar `log file sync` alto sin comparar contra `log file parallel write` de la misma ventana — es la distinción central de este skill.

# False positives

Un `user_rollbacks` alto durante pruebas de aplicación conocidas (ambiente no productivo) no es una anomalía relevante.

# Confidence model

`FACT` para los contadores leídos directamente. `HYPOTHESIS` para la distinción aplicación vs. storage. `PROBABLE_CAUSE` para latencia de storage sólo con evidencia OS/storage adicional.

# Output schema

```yaml
findings:
  - redo_size_bytes: number
    user_commits: number
    user_rollbacks: number
    log_file_sync_sec: number
    log_file_parallel_write_sec: number
    hypothesis: "application_commit_behavior"|"redo_storage_latency"|null
    confidence: FACT|HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`performance/io`, `oracle/redo`, `performance/trending`.

# Escalation

Latencia de storage sospechada → `os-platform-analyst`/`oracle-asm-storage-analyst`. Comportamiento de aplicación sospechado → recomendación manual (revisar patrón de commit), nunca ejecutado.

# Examples

Ver `tests/fixtures/19c-log-file-sync.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA. Presupuesto bajo.

# Tests

`tests/test_log_file_sync_vs_parallel_write_correlation.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — distingue comportamiento de aplicación de latencia de storage como hipótesis separadas. |
