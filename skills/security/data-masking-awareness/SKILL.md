---
name: data-masking-awareness
id: security/data-masking-awareness
version: 1.0.0
domain: security
status: active
---

# Purpose

Distingue explícitamente el producto "Data Masking and Subsetting" (Enterprise Manager Pack, no
introspectable vía SQL dentro de la base de datos) de `DBMS_REDACT` (Data Redaction, Advanced
Security Option) — nunca asume el mismo licenciamiento, nunca ejecuta masking (`# 42` del
prompt de Fase 8).

# Supported Oracle versions

10g–23ai (Data Masking and Subsetting Pack es un producto de Enterprise Manager, independiente
de la versión de Oracle Database del target).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/data-redaction-awareness` ya ejecutado (para la comparación explícita).

# Required evidence

Ninguna query directa — Data Masking and Subsetting es un producto de Enterprise Manager, no
introspectable desde la base de datos objetivo vía SQL certificado.

# Optional evidence

Evidencia de `security/data-redaction-awareness` para la nota comparativa.

# Licensing requirements

Oracle Data Masking and Subsetting Pack — licenciamiento separado del Advanced Security Option.

# Query IDs

Ninguna.

# Collector IDs

Ninguno — este skill es principalmente documentación/awareness conceptual, no un collector
técnico.

# Read-only operations

Ninguna — no hay vista SQL certificada para introspectar Enterprise Manager desde la base de
datos objetivo.

# Forbidden operations

Nunca ejecuta jobs de Data Masking/Subsetting.

# Decision logic

1. Siempre reporta `product: DATA_MASKING_AND_SUBSETTING|DBMS_REDACT|UNKNOWN` con la nota
   explícita de que son productos y licenciamientos distintos.
2. Sin evidencia de configuración de Enterprise Manager (fuera de alcance de este e-stack, que
   opera sobre la base de datos objetivo, no sobre EM), `capability_status: INSUFFICIENT_EVIDENCE`
   para el producto EM — el DBA debe confirmar manualmente si el pack está licenciado/en uso.
3. Nunca confunde la presencia de `DBMS_REDACT` (Data Redaction) con evidencia de que Data
   Masking and Subsetting también está licenciado.

# Normal state

`capability_status: INSUFFICIENT_EVIDENCE` es el estado esperado — este e-stack no tiene
visibilidad de Enterprise Manager.

# Abnormal patterns

N/A — no aplica un patrón anómalo técnico, sólo la distinción conceptual de licenciamiento.

# False positives

Confundir Data Redaction con Data Masking and Subsetting sería el error a evitar — este skill
existe específicamente para prevenirlo.

# Correlation rules

Consume `security/data-redaction-awareness`. Alimenta `security/licensing-gates`,
`security/compliance-mapping`.

# Confidence model

`OBSERVATION` — la distinción conceptual es un hecho documentado (`FACT`), la presencia real del
pack en el cliente es `INSUFFICIENT_EVIDENCE` sin confirmación externa.

# Severity

Informativo — es una nota de licenciamiento, no un hallazgo de seguridad técnico.

# Output schema

```yaml
data_masking:
  product: DATA_MASKING_AND_SUBSETTING|DBMS_REDACT|UNKNOWN
  note: "Data Masking and Subsetting (Enterprise Manager Pack) y Data Redaction (DBMS_REDACT, Advanced Security Option) son licenciamientos distintos — nunca se asume el mismo."
  license: {feature: "Oracle Data Masking and Subsetting", required: true, edition: string|null, pack: "Data Masking and Subsetting Pack", status: string, source: string}
  evidence_refs: [EVD-...]
```

# Related skills

`security/data-redaction-awareness`, `security/licensing-gates`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A — awareness/documentación de licenciamiento, sin capacidad técnica de ejecución en este
dominio.

# Security

Ninguna exposición de datos — este skill no accede a datos de aplicación.

# Tests

`tests/test_data_masking_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/security-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.
