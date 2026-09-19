# Phase 12 — estructura estable de documentos (referencia)

El motor `change_documentation_knowledge/documents.py` renderiza estos documentos con **orden de secciones estable**, valores en una sola línea, Markdown/HTML escapado y etiqueta epistemológica por ítem
(`observed`, `inferred`, `proposed`, `unknown`, `not_applicable`, `not_verified`, `human_reported`). Este archivo documenta el orden; el código es la fuente de verdad.

| Tipo (`document_type`) | Audiencia | Secciones (en orden) |
|---|---|---|
| `INCIDENT_RCA_TECHNICAL_REPORT` | TECHNICAL | Context · Timeline (UTC) · Evidence · Findings (observed) · Hypotheses (for and against) · Root cause · Contributing factors · Impact · Recommendations and change proposals · Limitations |
| `EXECUTIVE_SUMMARY` | EXECUTIVE | Headline · Uncertainty and open questions · Risk of proposed actions · Proposed next steps · Limitations |
| `CHANGE_ADVISORY_REPORT` | TECHNICAL_AND_CHANGE_REVIEW | Summary · una sección por CHG (objetivo, prerrequisitos, acciones manuales, validación, rollback, impacto, riesgos, gates, bloqueos, aprobación) · Limitations |
| `ASSESSMENT_REPORT` | TECHNICAL | Scope · Coverage (SUPPORTED/UNSUPPORTED/UNKNOWN) · Findings · Licensing · Exceptions · Pending items · Limitations |
| `POST_INCIDENT_REVIEW` | TECHNICAL_AND_MANAGEMENT | Summary · Actions reported by people (not verified) · Actions proposed by the analysis · Follow-ups · Lessons learned (blameless) · Metrics · Limitations |

Estado de sección: `PRESENT`, `NOT_PROVIDED_BY_SOURCE` (la fuente no lo ofrece; p. ej. factores contribuyentes o impacto en el resultado de `rca_engine`) o `MISSING` (dato esencial ausente => `content_status: PARTIAL` con warning estructurado).
Ningún documento incluye evidencia raw, secretos, rutas internas, valores originales de firmas desconocidas (sólo tokens de Phase 11), métricas inventadas (MTTR/SLA) ni resultados de ejecución.
