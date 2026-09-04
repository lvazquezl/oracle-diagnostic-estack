---
name: awr-analysis
display_name: "AWR Analysis"
id: performance/awr-analysis
version: 1.1.0
domain: performance
status: active
---

# Purpose

Caracterizar el Load Profile completo de una ventana AWR (DB Time/DB CPU, wait classes/events, top SQL, memoria, I/O, parsing, redo/commit) y correlacionar sus secciones — nunca resumir el AWR sin cruzar hallazgos.

# Scope

**En alcance:** lectura estructurada de `DBA_HIST_*` (Diagnostics Pack) sobre una ventana explícita, correlación entre DB Time/DB CPU, wait events, top SQL, memoria e I/O de esa misma ventana; adicionalmente (desde Fase 3 Completion Hardening) ingesta de un reporte AWR HTML/texto ya generado por el DBA vía `parsers/performance/awr_parser.py` (ver `# Report ingest` más abajo).
**Fuera de alcance:** RAC Cache Fusion profundo; tuning automático; generación del reporte AWR en sí (siempre generado del lado Oracle, nunca por este stack).

# Report ingest

Cuando el DBA adjunta un reporte AWR (HTML o texto) en vez de/además de consulta en vivo: `FILE → type_detector → parsers/performance/awr_parser.py → ParsedReport (sections: db_time_cpu, load_profile, waits, sql, rac, memory, io, parsing, redo_commit) → sanitizer → evidence`. Primera versión funcional — no cubre perfectamente todos los formatos históricos de AWR; nunca finge una sección que el reporte concreto no contiene (`capability_status` por sección). SQL text y bind values nunca se extraen. Ver `parsers/performance/common.py` para el envelope y `agents/oracle-performance-analyst/AGENT.md#report-ingest-model`.

# Supported Oracle versions

10g–23ai. `DBA_HIST_*` disponible desde 10g con Diagnostics Pack. Sin diferencias estructurales relevantes en las columnas usadas por este skill — validado por `compatibility/oracle-dictionary/`.

# Supported OS/platforms

Todas — el análisis es lógico sobre el repositorio AWR.

# Supported architectures

Standalone y RAC (por instancia; agregación cross-instance básica sin promediar ingenuamente — ver `agents/oracle-performance-analyst/AGENT.md#multi-instance-awareness`). NON-CDB y CDB (distingue `CON_ID` cuando existe). ASM y Filesystem. Primary (foco principal — en standby, actividad de usuario mínima).

# Licensing

Requiere Diagnostics Pack. Sin confirmación, `capability_status: LICENSE_RESTRICTED` y fallback a `performance/statspack-analysis` (o vistas dinámicas si Statspack tampoco está disponible) — ver `agents/oracle-performance-analyst/AGENT.md#licensing-fallback-examples`.

# Prerequisites

Target Profile publicado, `constraints.time_window` explícito, `constraints.license_confirmed.diagnostics_pack: true`.

# Required evidence

- `Q-PERF-DBTIME-001` (DB Time/DB CPU)
- `Q-PERF-WAIT-AWR-001` (top wait events)
- `Q-PERF-TOPSQL-001` (top SQL)

# Optional evidence

- `Q-PERF-SGA-001`, `Q-PERF-PGA-001` (memoria — estructural, no requiere ventana)
- `Q-PERF-IO-001`, `Q-PERF-IO-FILESTAT-001` (I/O — snapshot actual, complementario)
- `Q-PERF-PLAN-HIST-001` (si se sospecha plan regression sobre un `sql_id` del top SQL)
- `parsers/performance/awr_parser.py` (reporte AWR HTML/texto adjunto por el DBA)

# Data collection

Lectura de `DBA_HIST_SYS_TIME_MODEL`, `DBA_HIST_SYSTEM_EVENT`, `DBA_HIST_SQLSTAT`, `DBA_HIST_SNAPSHOT` — todas `DBA_HIST_*` de AWR, ninguna tabla de aplicación.

# Diagnostic logic / Decision tree

```text
1. Leer DB Time/DB CPU de la ventana (Q-PERF-DBTIME-001) → Load Profile base.
2. Leer top wait events (Q-PERF-WAIT-AWR-001) → clasificar por wait_class.
3. Leer top SQL (Q-PERF-TOPSQL-001) → ordenar por elapsed/CPU/reads/gets/executions.
4. Correlacionar:
   IF db_cpu_pct(db_time) alto AND top_sql concentrado en pocos sql_id AND waits no-CPU bajos
        → HYPOTHESIS: CPU-bound workload concentrado
   IF wait dominante = User I/O AND db file sequential/scattered read
        → correlacionar con performance/io, posible escalar a oracle-asm-storage-analyst
   IF wait dominante = Concurrency (latch free, buffer busy waits)
        → correlacionar con performance/concurrency/performance/locking
   IF wait dominante = Cluster (gc *)
        → señalar next_skill_or_agent: oracle-rac-analyst
5. Si un sql_id del top SQL tiene múltiples plan_hash_value en la ventana → señalar performance/plan-regression.
```

# Normal behavior

DB Time proporcional al workload esperado, ningún wait class dominando de forma desproporcionada (>50% del DB Time no-idle en un solo wait class sin explicación de negocio), top SQL sin concentración extrema en un único `sql_id`.

# Abnormal patterns

Un wait class dominando >70% del DB Time no-idle sin correlación de workload esperado; un único `sql_id` responsable de >30% del DB Time total de la ventana; DB CPU alto con `parse count (hard)` desproporcionado (candidato a `performance/hard-parse`).

# Root cause patterns

Ver `agents/oracle-performance-analyst/AGENT.md#correlation-model` para los patrones certificados (CPU-bound, commit de aplicación, latencia de storage de redo). Ningún patrón de este skill produce `CONFIRMED_ROOT_CAUSE` por sí solo.

# Correlation rules

Cruzar siempre DB Time/DB CPU + wait events + top SQL de la misma ventana antes de reportar un finding. Nunca reportar un wait event aislado como "el problema" sin su contribución porcentual al DB Time total.

# False positives

Un wait class con tiempo total alto pero `DB Time %` bajo (ventana larga, actividad esporádica) no es automáticamente `HIGH` — la severidad depende de la proporción, no del tiempo absoluto (ver `# 17. WAIT ANALYSIS RULE` del prompt de Fase 3).

# Confidence model

`FACT` para DB Time/DB CPU/wait time leídos directamente. `HYPOTHESIS` para una correlación de 2 fuentes sin descartar alternativa. `PROBABLE_CAUSE` con 2+ fuentes correlacionadas + ventana temporal coincidente + ausencia de contradicción. Nunca `CONFIRMED_ROOT_CAUSE`.

# Output schema

```yaml
findings:
  - category: load-profile
    db_time_sec: number
    db_cpu_sec: number
    top_wait_class: string
    top_wait_pct_db_time: number
    top_sql_id: string
    severity: INFO|LOW|MEDIUM|HIGH|CRITICAL
    confidence: FACT|OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`performance/db-time`, `performance/db-cpu`, `performance/wait-events`, `performance/top-sql`, `performance/statspack-analysis` (fallback), `performance/trending`.

# Escalation

Wait dominante `Cluster` → `oracle-rac-analyst`. Wait dominante I/O con indicio de storage → `oracle-asm-storage-analyst`. Múltiples síntomas correlacionables → `incident-root-cause-analyst`.

# Examples

Ver `tests/fixtures/19c-high-cpu.yaml` (DB CPU dominante, top SQL concentrado → `HYPOTHESIS: CPU-bound`).

# Data sensitivity / Context budget

Sensibilidad MEDIA (`sql_id`, nombres de wait event; nunca SQL text/bind values). Presupuesto alto, estrictamente acotado por `time_window`.

# Tests

`tests/test_awr_requires_license_gate.sh`, `tests/test_awr_parsing.sh`, `tests/test_awr_db_time.sh`, `tests/test_awr_db_cpu.sh`, `tests/test_awr_wait_events.sh`, `tests/test_awr_top_sql.sh`, `tests/test_awr_no_sql_text_by_default.sh`, `tests/test_report_type_detection_awr_html.sh`, `tests/test_report_type_detection_awr_text.sh`, `tests/test_awr_html_parser.sh`, `tests/test_awr_text_parser.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — correlación DB Time/DB CPU + wait events + top SQL sobre ventana AWR. |
| 1.1.0 | Fase 3 Completion & Portability Hardening | Añadida ruta de ingesta de reporte AWR HTML/texto vía `parsers/performance/awr_parser.py` (primera versión funcional). |
