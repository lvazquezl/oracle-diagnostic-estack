---
name: healthcheck-report
id: documentation/healthcheck-report
version: 1.0.0
domain: documentation
status: active
---

# Purpose

Generar el reporte Markdown canónico de un health check (`analysis/ANA-*`) consolidando los `findings`/`recommendations` de todos los especialistas activados, y — sólo bajo demanda — derivar un entregable binario (DOCX/PDF) desde ese Markdown sin repetir el análisis.

# Supported Oracle versions

N/A directo — documenta lo que los especialistas ya concluyeron sobre cualquier versión soportada.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

Requiere que el workflow `/healthcheck` haya cerrado con al menos un Result Package consolidado por el orquestador.

# Required evidence

- Ninguna evidencia cruda nueva — consume exclusivamente `findings`/`recommendations`/`evidence_refs` ya producidos.

# Optional evidence

N/A.

# Read-only operations

Lectura de los Result Packages consolidados y de `analysis/_TEMPLATE/` para estructura.

# Forbidden operations

No genera un binario (DOCX/PDF) sin que exista primero `analysis.md`/`findings.md` de origen. No inventa hallazgos no presentes en los Result Packages.

# Decision logic

1. Crear `analysis/ANA-YYYYMMDD-NNN/` (si no existe ya para esta sesión) con `analysis.md, context.md, evidence.md, findings.md, recommendations.md, proposed-changes.md, metadata.yaml, evidence-manifest.json`.
2. `context.md` ← output de `core/context-discovery`.
3. `findings.md` ← consolidado de todos los `findings` por dominio, agrupados por severidad.
4. `recommendations.md` ← consolidado de `recommendations`, marcando `LICENSE_CHECK_REQUIRED` donde aplique.
5. `evidence-manifest.json` ← lista de todos los `EVD-*` referenciados, con su clasificación (raw/sanitized/derived).
6. Si el DBA invoca `/document healthcheck --format docx|pdf|all`, generar el binario a partir de estos Markdown usando el template correspondiente de `templates/reports/`, sin reprocesar evidencia.

# Confidence model

N/A — no genera confianza propia; transcribe la de cada finding tal como la reportó su especialista de origen.

# Output schema

```yaml
documents_generated:
  - path: analysis/ANA-YYYYMMDD-NNN/analysis.md
    format: markdown
  - path: reports/ANA-YYYYMMDD-NNN-healthcheck.docx
    format: docx
    source_analysis_id: ANA-YYYYMMDD-NNN
```

# Related skills

`documentation/assessment-report`, `documentation/technical-findings`, `documentation/word-generator`, `documentation/pdf-generator`, `documentation/document-validator`.

# Escalation

Si se solicita `/document healthcheck --format docx` sin un `ANA-*` correspondiente en la sesión, rechaza y explica `NO ANALYSIS WITHOUT EVIDENCE RECORD`.

# Data sensitivity

Refleja la sensibilidad ya sanitizada de los `findings` de origen; nunca incorpora evidencia raw.

# Context budget

Bajo: opera sobre datos ya estructurados, no evidencia cruda.

# Tests

`tests/test_document_traceability.sh`, `tests/test_no_binary_without_source.sh`.

# Documentation requirements

Este skill ES la implementación de la obligación de documentación para el workflow `/healthcheck`.

# Evolution via `/change`

Nuevos templates o secciones del reporte vía `/change documentation`.
