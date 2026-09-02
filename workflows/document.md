---
name: document
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/document <tipo> --format <docx|xlsx|pdf|pptx|all>`. Solicitud explícita de un entregable binario derivado de un análisis Markdown ya existente.

# Prerequisites

Un `ANA-*`/`INC-*` existente que contenga el tipo de documento solicitado (`assessment`, `healthcheck`, `rca`, `executive`, etc.).

# Discovery requirements

Ninguna — no se toca el ambiente Oracle/OS en absoluto, sólo el repositorio del análisis.

# Minimum agents

`oracle-operations-orchestrator`, `technical-documentation-manager`.

# Optional agents

Ninguno adicional — este workflow es puramente documental.

# Activation conditions

N/A — siempre activa sólo `technical-documentation-manager`.

# Skills

`documentation/document-planner`, `documentation/table-builder`, `documentation/chart-builder`, y el generador específico del formato solicitado (`documentation/word-generator`, `documentation/excel-generator`, `documentation/pdf-generator`, `documentation/presentation-generator`), más `documentation/document-validator` al final.

# Evidence required

Ninguna evidencia cruda nueva — sólo lo ya registrado en `analysis/ANA-*`.

# Stop conditions

No existe `analysis/ANA-*` de origen para el tipo de documento solicitado — se rechaza la solicitud citando `NO ANALYSIS WITHOUT EVIDENCE RECORD` / `NO DELIVERABLE WITHOUT TRACEABILITY TO ITS SOURCE ANALYSIS`.

# Confidence threshold

N/A.

# Escalation

N/A.

# Documentation output

`reports/<ANA-id>-<tipo>.<formato>`, trazable al `ANA-*`/`INC-*` de origen.

# Token/context budget

Bajo — transforma datos ya estructurados, no reprocesa evidencia.

# Security constraints

Ningún documento generado incluye evidencia `raw` ni secretos — sólo `sanitized`/`derived` ya presente en el Markdown de origen.

# Gates

```yaml
gates:
  version:      no aplica — la generación documental es agnóstica de versión Oracle
  architecture: no aplica
  environment:  no aplica — no toca el ambiente Oracle/OS
  license:      no aplica directamente; LICENSE_CHECK_REQUIRED heredado del análisis de origen se preserva en el documento
  privilege:    no aplica — no requiere acceso al ambiente
  security:     el documento nunca incluye evidence/raw ni secretos, sólo sanitized/derived
  cost:         no aplica — no ejecuta queries
  evidence:     bloquea la generación si no existe analysis/ANA-*/INC-* de origen para el tipo de documento solicitado
```
