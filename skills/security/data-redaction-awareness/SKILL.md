---
name: data-redaction-awareness
id: security/data-redaction-awareness
version: 1.0.0
domain: security
status: active
---

# Purpose

Awareness de presencia/configuración de políticas de Data Redaction (`DBMS_REDACT`) — nunca
crea/altera políticas (`# 41` del prompt de Fase 8).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-DATA-REDACTION-POLICIES-001`

# Optional evidence

Ninguna.

# Licensing requirements

Oracle Data Redaction — Advanced Security Option (mismo bucket que TDE, distinto de Data
Masking and Subsetting — ver `security/data-masking-awareness`).

# Query IDs

`Q-SEC-DATA-REDACTION-POLICIES-001`.

# Collector IDs

`get_data_redaction_policies`.

# Read-only operations

Lectura de `REDACTION_POLICIES`/`REDACTION_COLUMNS`.

# Forbidden operations

Nunca ejecuta `DBMS_REDACT.ADD_POLICY/ALTER_POLICY/DROP_POLICY`.

# Decision logic

1. En 10g/11g → `capability_status: UNSUPPORTED`, nunca se consulta.
2. Reporta conteo/ubicación de políticas — nunca su lógica de redacción detallada si contiene
   datos sensibles del negocio en los parámetros.

# Normal state

Políticas configuradas sobre columnas sensibles conocidas (PII, tarjetas, etc.) cuando aplica al
negocio del cliente.

# Abnormal patterns

Ausencia de políticas sobre columnas que el DBA identifica como sensibles.

# False positives

Ausencia de Data Redaction no es anómala si el cliente usa otro control compensatorio (ej. VPD,
masking a nivel de aplicación).

# Correlation rules

Alimenta `security/licensing-gates`, `security/compliance-mapping`.

# Confidence model

`FACT` para presencia/conteo de políticas.

# Severity

Informativo — depende del policy target del cliente.

# Output schema

```yaml
data_redaction:
  policies_detected: int|null
  license: {feature: "Oracle Data Redaction", required: true, edition: string|null, pack: "Advanced Security Option", status: string, source: string}
  evidence_refs: [EVD-...]
```

# Related skills

`security/data-masking-awareness`, `security/tde-awareness`, `security/licensing-gates`.

# Escalation

Ninguna directa.

# Manual remediation guidance

`manual_action` sugiere `DBMS_REDACT.ADD_POLICY` para columnas sensibles identificadas por el
DBA — siempre `NOT_EXECUTED`.

# Security

`object_owner`/`object_name`/`column_name` → MASK por defecto.

# Tests

`tests/test_no_redaction_change.sh`, `tests/test_data_redaction_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/security-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.
