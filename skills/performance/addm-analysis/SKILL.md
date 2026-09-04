---
name: addm-analysis
display_name: "ADDM Analysis"
id: performance/addm-analysis
version: 1.1.0
domain: performance
status: active
---

# Purpose

Interpretar hallazgos de ADDM (Automatic Database Diagnostic Monitor) como una fuente de evidencia adicional, correlacionada con AWR/wait events/SQL/memoria/I/O — nunca como causa confirmada automática.

# Scope

**En alcance:** correlación de recomendaciones ADDM ya generadas por Oracle con evidencia independiente del catálogo (AWR/wait events/top SQL).
**Fuera de alcance:** ejecución de ADDM bajo demanda (`DBMS_ADVISOR`), aceptación automática de cualquier recomendación ADDM sin correlación cruzada.

# Supported Oracle versions

10g–23ai. ADDM disponible desde 10g junto con AWR.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC. NON-CDB y CDB. Primary (foco principal — ADDM analiza actividad, mínima en standby).

# Licensing

Requiere Diagnostics Pack (ADDM es parte del mismo licenciamiento que AWR) — detrás del Licensing Gate. Sin confirmación, `capability_status: LICENSE_RESTRICTED`, sin fallback (no existe equivalente ADDM en Statspack ni vistas dinámicas — el análisis continúa con `awr-analysis`/`statspack-analysis` sin la capa de recomendación automática de Oracle).

# Prerequisites

Target Profile publicado, evidencia AWR de la misma ventana disponible (`constraints.license_confirmed.diagnostics_pack: true`), un snapshot ADDM ya generado por Oracle (este skill no lo genera — sólo lo interpreta, vía texto pegado por el DBA o vía `parsers/performance/addm_parser.py` sobre un reporte ADDM texto adjunto).

# Required evidence

Ninguna query certificada propia — ADDM se lee del ambiente cuando el DBA lo provee, ahora vía `parsers/performance/addm_parser.py` (findings + recommendations estructurados) desde Fase 3 Completion Hardening; este skill correlaciona ese insumo con evidencia AWR ya certificada (`Q-PERF-DBTIME-001`, `Q-PERF-WAIT-AWR-001`, `Q-PERF-TOPSQL-001`).

# Optional evidence

- `Q-PERF-DBTIME-001`, `Q-PERF-WAIT-AWR-001`, `Q-PERF-TOPSQL-001` (correlación cruzada)
- `parsers/performance/addm_parser.py` (reporte ADDM texto adjunto por el DBA)

# Report ingest

`FILE → type_detector → parsers/performance/addm_parser.py → ParsedReport (sections: findings, recommendations)`. Cada finding se clasifica `EVIDENCE_SOURCE`; cada recomendación lleva `manual_execution_required: true` — nunca se ejecuta `DBMS_ADVISOR.EXECUTE_TASK` ni ningún procedimiento de generación de ADDM, sólo se interpreta output ya existente.

# Diagnostic logic / Decision tree

```text
1. Recibir recomendación(es) ADDM del DBA como insumo (finding_type, impact, recommendation_text).
2. Clasificar cada recomendación como EVIDENCE_SOURCE, nunca como causa confirmada.
3. Buscar evidencia AWR independiente (wait events, top SQL, DB Time) que corrobore o contradiga la recomendación.
4. Si corrobora → HYPOTHESIS/PROBABLE_CAUSE (con la evidencia cruzada citada explícitamente).
5. Si contradice o no hay evidencia independiente → se reporta la recomendación ADDM tal cual, marcada EVIDENCE_SOURCE sin escalar confianza.
```

# Normal behavior

Recomendaciones ADDM consistentes con el wait profile/top SQL de la misma ventana observados independientemente.

# Abnormal patterns

Recomendación ADDM sin correlación en la evidencia AWR independiente disponible — se reporta igual (Oracle pudo ver algo que este catálogo acotado no cubre), pero explícitamente sin escalar a `PROBABLE_CAUSE`.

# Root cause patterns

Ninguno exclusivo — ADDM nunca es la única fuente de una causa reportada por este e-stack.

# Correlation rules

Toda recomendación ADDM se cruza obligatoriamente con al menos una fuente independiente (AWR wait events o top SQL) antes de asignar cualquier confianza superior a `OBSERVATION`.

# False positives

ADDM puede recomendar acciones basadas en umbrales genéricos de Oracle que no aplican al contexto específico del ambiente (ej. sugerir más memoria cuando el verdadero cuello es I/O) — nunca se transcribe la recomendación de ADDM como acción a ejecutar sin la validación cruzada de este skill.

# Confidence model

`OBSERVATION` para una recomendación ADDM aislada sin corroboración. `HYPOTHESIS`/`PROBABLE_CAUSE` sólo con evidencia AWR independiente que corrobore. Nunca `CONFIRMED_ROOT_CAUSE`.

# Output schema

```yaml
findings:
  - addm_finding_type: string
    addm_impact: string
    corroborating_evidence_refs: [EVD-...]|[]
    confidence: OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE
    classification: EVIDENCE_SOURCE
```

# Related skills

`performance/awr-analysis`, `performance/wait-events`, `performance/top-sql`.

# Escalation

Recomendación ADDM que implica cambio de parámetro/SQL Tuning → nunca ejecutado; se convierte en `recommendation` con `manual_execution_required: true`, escalable a `change-advisor` sólo tras aprobación del DBA.

# Examples

Ver `tests/fixtures/reports/addm-sample.txt` (2 findings, 2 recommendations) y `tests/fixtures/reports/addm-injection-attempt.txt` (prueba de que el contenido del reporte nunca se interpreta como instrucción).

# Data sensitivity / Context budget

Sensibilidad MEDIA (texto de recomendación de Oracle, puede mencionar `sql_id`/nombres de objeto; nunca SQL text/bind values). Presupuesto bajo — el insumo ADDM ya viene resumido por Oracle.

# Tests

`tests/test_addm_license_gate.sh`, `tests/test_report_type_detection_addm.sh`, `tests/test_addm_parser.sh`, `tests/test_parser_does_not_execute_embedded_instructions.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — clasificación EVIDENCE_SOURCE obligatoria, correlación cruzada con AWR antes de escalar confianza, nunca ejecuta DBMS_ADVISOR. |
| 1.1.0 | Fase 3 Completion & Portability Hardening | Añadida ruta de ingesta de reporte ADDM texto vía `parsers/performance/addm_parser.py` (findings + recommendations estructurados). |
