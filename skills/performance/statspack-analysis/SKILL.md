---
name: statspack-analysis
display_name: "Statspack Analysis"
id: performance/statspack-analysis
version: 2.0.0
domain: performance
status: active
---

# Purpose

Diagnóstico de performance sin Diagnostics Pack — ruta de primera clase (no un fallback de segunda categoría) para 10g/11g legacy y cualquier ambiente sin licencia AWR/ASH confirmada. Desde v2.0.0 consume dos fuentes de evidencia complementarias: `Q-PERF-WAIT-STATSPACK-001` (waits en vivo vía SQL) y `parsers/performance/statspack_parser.py` (reporte Statspack de texto que el DBA provee, parseado localmente — ver `docs/PHASE_3_COMPLETION_HARDENING.md#statspack-parser`).

# Scope

**En alcance:** todo lo que el parser Statspack pueda extraer de un reporte real — Load Profile, Instance Efficiency, Top Wait Events, SQL ordered by (executions/CPU/elapsed/gets/reads), Instance Activity, Library Cache, Latch, Enqueue, I/O, Redo/Commit (derivado), Parsing (derivado), Memoria (Cache Sizes) — **sólo cuando el reporte específico contenga esa sección**; ver `# Statspack capability map` abajo.
**Fuera de alcance:** cualquier sección que el reporte no contenga (nunca fabricada — `PARTIALLY_SUPPORTED`/`UNSUPPORTED` explícito, ver `compatibility_status` en el output); ASH sampling (Statspack no lo provee, nunca); equivalencia 1:1 con AWR cuando Statspack no contiene la misma información (`# Statspack ≠ AWR`).

# Supported Oracle versions

10g–23ai. Statspack no requiere versión mínima particular más allá del piso del catálogo (10.2) — el paquete debe estar instalado manualmente por el DBA (`spcreate.sql`) en cualquier versión. El parser tolera variación de whitespace/layout entre versiones de reporte (# 8 STATSPACK PARSER ROBUSTNESS) — nunca depende de posiciones de columna fijas.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB (el esquema `PERFSTAT` se instala en `CDB$ROOT` o una PDB según decisión del DBA). Filesystem y ASM (el parser reconoce nombres de archivo estilo ASM, `+DATA/...`). Primary (foco principal).

# Licensing

Ninguna — esta es la ruta explícitamente diseñada para ambientes sin Diagnostics Pack (`license_requirements: none`). El parsing técnico del archivo tampoco requiere licencia y no elude el Licensing Gate de ninguna otra capability (# 17 AWR PARSER LICENSING, aplicado igual aquí por simetría).

# Prerequisites

Target Profile publicado. Para la ruta en vivo: `constraints.time_window` explícito y confirmación de que el paquete Statspack está instalado (`STATS$SYSTEM_EVENT`/`STATS$SNAPSHOT` existen) — si no, `capability_status: UNDETERMINED`, nunca `LICENSE_RESTRICTED`. Para la ruta de reporte: el DBA provee el archivo de texto Statspack (`spreport.sql` output).

# Required evidence

- `Q-PERF-WAIT-STATSPACK-001` (ruta en vivo, waits)

# Optional evidence

- Reporte Statspack de texto provisto por el DBA, ingresado vía `parsers/performance/ingest.py` → `parse_statspack_text()` (ruta de archivo, todas las demás secciones).

# Data collection

Ruta en vivo: lectura de `STATS$SYSTEM_EVENT`, `STATS$SNAPSHOT` — esquema `PERFSTAT`, ninguna tabla de aplicación. Ruta de archivo: parseo local del texto ya en disco — ningún acceso a la base de datos, ningún envío del archivo completo al modelo (`FILE → TYPE DETECTOR → LOCAL PARSER → STRUCTURED REPORT → SANITIZER → EVIDENCE`).

# Statspack capability map

Statspack **no es una copia de AWR** — cada sección declara su origen real, nunca universalidad falsa (# 6 STATSPACK ≠ AWR):

```yaml
statspack_capabilities:
  load_profile: supported
  instance_efficiency: supported
  wait_events: supported
  sql_metrics: supported            # executions/CPU/elapsed/gets/reads — nunca SQL text
  instance_activity: supported
  library_cache: supported
  latch: supported
  enqueue: supported
  io: supported
  redo_commit: supported            # derivado de Load Profile + Instance Activity, sin sección propia
  parsing: supported                # derivado de Load Profile + Instance Efficiency, sin sección propia
  memory: supported                 # Cache Sizes

  ash_sampling:
    status: unsupported
    reason: Not available from Statspack report — ASH sampling is AWR/Diagnostics-Pack-only.
  awr_specific_metrics:
    status: unsupported
    reason: Statspack has no equivalent of AWR's SQL Plan history, ADDM integration, or Time Model views.
```

`supported` aquí significa "el parser sabe extraer esta sección **si el reporte la contiene**" — la `completeness` real por reporte específico viene del envelope del parser (`SUPPORTED`/`PARTIALLY_SUPPORTED`/`UNSUPPORTED` por sección, ver `docs/PHASE_3_COMPLETION_HARDENING.md#parser-output-contract`), nunca de esta tabla estática.

# Diagnostic logic / Decision tree

```text
1. Si hay reporte de archivo: ingest_report(text) → structured report (completeness por sección).
   Si hay ventana en vivo: Q-PERF-WAIT-STATSPACK-001 → waits agregados.
2. Para cada sección con completeness SUPPORTED: analizar según # 11 STATSPACK CORRELATION.
3. Para cada sección UNSUPPORTED en el reporte: declarar explícitamente en `limitations`, nunca omitir en silencio.
4. Clasificar por wait_class_derived (aproximación por patrón de nombre — Statspack no tiene wait_class nativo).
5. Correlacionar (ver abajo) — nunca declarar root cause automática.
6. Si el DBA solicita comparación cruzada AWR↔Statspack explícitamente y ambas fuentes existen:
   → PARTIALLY_SUPPORTED, declarando qué secciones son comparables (waits, SQL metrics, memoria) y cuáles no (ASH, plan history).
```

# Normal behavior

Wait events distribuidos sin concentración extrema; `Soft Parse %`/`Library Hit %`/`Buffer Hit %` dentro de rangos saludables (Instance Efficiency); sin secciones `library_cache`/`latch` mostrando reloads/miss ratios elevados.

# Abnormal patterns

Igual criterio que `performance/wait-events`, con la salvedad de que `wait_class_derived` es una aproximación — un finding basado únicamente en esta clasificación se reporta con `confidence` no superior a `HYPOTHESIS` salvo corroboración adicional. `Soft Parse %` bajo (<80%) correlacionado con `library_cache` reloads altos → ver `# Statspack correlation` abajo.

# Root cause patterns

Ninguno exclusivo de Statspack — se apoya en los mismos patrones de `agents/oracle-performance-analyst/AGENT.md#correlation-model`, con menor granularidad que AWR/ASH. Nunca `CONFIRMED_ROOT_CAUSE` desde este skill.

# Statspack correlation

Patrones certificados (# 11 STATSPACK CORRELATION), cada uno `OBSERVATION`→`HYPOTHESIS`, nunca root cause automática:

```text
high parse activity (Load Profile: Parses/Hard parses altos)
+ high hard parse (Instance Efficiency: Soft Parse % bajo)
+ library cache pressure (library_cache: reloads/invalidations altos)
        ↓
HYPOTHESIS: parse/shared-pool pressure

high physical reads (Load Profile: Physical reads alto)
+ I/O wait concentration (waits: db file sequential/scattered read dominante)
        ↓
HYPOTHESIS: I/O-intensive workload

high commits (instance_activity: user commits alto)
+ log file sync concentration (waits: log file sync dominante)
        ↓
HYPOTHESIS: commit behavior — distinguir de latencia de storage cruzando con log file parallel write si el reporte lo incluye
```

# Correlation rules

Cruzar siempre `wait_events` con `sql_metrics`/`instance_activity` de la MISMA ventana antes de reportar un finding. Cruzar con `Q-PERF-TOPSQL-CURRENT-001`/`Q-PERF-DBTIME-CURRENT-001` (vistas dinámicas) cuando sólo se tenga la ruta en vivo (sin archivo de reporte) para compensar secciones no cubiertas por esa ruta.

# False positives

`wait_class_derived` puede clasificar erróneamente un evento no listado explícitamente como `Other` — un finding `HIGH` basado en `Other` sin desglose adicional se marca `UNDETERMINED` hasta identificar el evento real. Un `Soft Parse %` bajo en una ventana de arranque/deploy conocido no es un problema sostenido.

# Confidence model

`FACT` para valores leídos directamente de una sección `SUPPORTED`. `HYPOTHESIS` para correlaciones de `# Statspack correlation` con 2 fuentes. `PROBABLE_CAUSE` sólo con 2+ fuentes + ausencia de contradicción. Nunca `CONFIRMED_ROOT_CAUSE`. `UNDETERMINED` cuando la sección relevante es `UNSUPPORTED` en el reporte específico.

# Output schema

```yaml
findings:
  - category: string            # load_profile|waits|sql_metrics|instance_activity|library_cache|latch|enqueue|io|redo_commit|parsing|memory
    observation: string
    severity: INFO|LOW|MEDIUM|HIGH
    confidence: FACT|OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE|UNDETERMINED
    evidence_refs: [EVD-...]
hypotheses: [string]
recommendations:
  - summary: string
    manual_execution_required: true
limitations:
  - section: string
    reason: string               # ej. "sección ausente en este reporte específico"
capability_status: SUPPORTED|PARTIALLY_SUPPORTED|UNDETERMINED
```

# Related skills

`performance/wait-events`, `performance/awr-analysis` (comparación explícita, `PARTIALLY_SUPPORTED`), `performance/db-cpu` (vía `Q-PERF-DBTIME-CURRENT-001`), `performance/hard-parse`, `performance/library-cache`.

# Escalation

Si el DBA requiere una sección que ni el reporte ni el parser cubren (ej. ASH sampling), se declara `capability_status: UNSUPPORTED` con `alternative` explícita (`performance/ash-analysis` si Diagnostics Pack está confirmado) — nunca se inventa una consulta o extracción no certificada.

# Examples

Ver `tests/fixtures/10g-statspack.yaml`, `tests/fixtures/11g-statspack.yaml` (ruta en vivo), `tests/fixtures/reports/statspack-{10g,11g,partial,no-sql,high-parse,high-io,high-commit}.txt` (ruta de archivo).

# Data sensitivity / Context budget

Sensibilidad MEDIA (nombres de wait event, hostnames/db names sanitizados por el parser antes de convertirse en evidencia). Presupuesto medio — el reporte se parsea y agrega localmente antes de exponerse, nunca se envía el archivo completo.

# Tests

`tests/test_statspack_10g.sh`, `tests/test_statspack_11g.sh`, `tests/test_statspack_without_diagnostic_pack.sh`, `tests/test_statspack_waits.sh`, `tests/test_statspack_sql_metrics.sh`, `tests/test_statspack_parser_10g.sh`, `tests/test_statspack_parser_11g.sh`, `tests/test_statspack_missing_section_graceful.sh`, `tests/test_statspack_load_profile.sh`, `tests/test_statspack_instance_activity.sh`, `tests/test_statspack_library_cache.sh`, `tests/test_statspack_latch_enqueue.sh`, `tests/test_statspack_io.sh`, `tests/test_statspack_redo_commit.sh`, `tests/test_statspack_parsing.sh`, `tests/test_statspack_no_sql_text_by_default.sh`, `tests/test_statspack_partial_capability_status.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado como ruta de primera clase — Q-PERF-WAIT-STATSPACK-001 materializada (antes sólo registered). Gap de SQL/Load Profile/memoria/I/O detallado vía Statspack documentado explícitamente, no fingido como cubierto. |
| 2.0.0 | Fase 3 Completion & Portability Hardening | `performance/statspack-analysis` deja de estar limitado a waits — consume `parsers/performance/statspack_parser.py` para Load Profile, Instance Efficiency, SQL metrics, Instance Activity, Library Cache, Latch, Enqueue, I/O, Redo/Commit (derivado), Parsing (derivado), Memoria. Capability map explícito Statspack≠AWR. Correlación certificada (parse/shared-pool, I/O-intensive, commit behavior). |
