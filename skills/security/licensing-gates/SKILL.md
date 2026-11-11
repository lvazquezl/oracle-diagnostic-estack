---
name: licensing-gates
id: security/licensing-gates
version: 1.1.0
domain: security
status: active
---

# Purpose

Mantiene `feature, required, edition, pack, status, source` para toda capacidad licensing-sensitive
— disponibilidad técnica nunca implica derecho de uso (`# 43` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/database-vault-awareness`, `security/ols-awareness`, `security/data-redaction-awareness`,
`security/data-masking-awareness`, `security/tde-awareness` ejecutados según aplique.

# Required evidence

- evidencia de los skills de advanced features listados arriba

# Optional evidence

`Target Profile.security.licensing_profile` cuando el DBA lo confirma explícitamente.

- `Q-ORA-FEATURE-USAGE-001`

**Gateway (lote C, `CHG-ESTACK-C-NEW-QUERIES-001`):** `Q-ORA-FEATURE-USAGE-001` entrega las features con uso detectado (`DBA_FEATURE_USAGE_STATISTICS`) por contenedor. Cada feature en uso que corresponda a una opción o pack (por ejemplo Partitioning, Advanced Compression, Diagnostics/Tuning Pack, Active Data Guard) se reporta como `LICENSE_CHECK_REQUIRED`: el uso detectado no prueba que se requiera licencia (algunas se activan por componentes de Oracle) ni que esté o no licenciada. Nunca se reporta como incumplimiento. Las variantes `(system)` (por ejemplo `Partitioning (system)` o `SecureFiles (system)`) son uso de los esquemas de Oracle y no generan `LICENSE_CHECK_REQUIRED`: en el lab (19.32) aparecen en el root y en la PDB sin ninguna fila `Partitioning (user)`. Oracle muestrea el uso aproximadamente una vez por semana (`hours_since_last_sample`).

# Licensing requirements

N/A — este skill es el mecanismo de licensing gate en sí.

# Query IDs

Ninguna directa — consolida evidencia de otros skills.

# Collector IDs

Ninguno.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca habilita/deshabilita ninguna feature licenciada.

# Decision logic

1. `status` por defecto `SEPARATELY_LICENSED`/`REQUIRES_REVIEW` para toda feature avanzada
   detectada como instalada/visible — nunca `INCLUDED` sin confirmación explícita.
2. `Target Profile.security.licensing_profile` confirmado por el DBA → `status: INCLUDED` sólo
   para las features explícitamente listadas ahí.
3. `UNKNOWN` cuando no hay evidencia suficiente ni para instalado/visible ni para confirmación.

# Normal state

La mayoría de features avanzadas en `status: SEPARATELY_LICENSED` (no instaladas) o
`REQUIRES_REVIEW` (instaladas sin confirmación).

# Abnormal patterns

Feature en uso activo (políticas configuradas, ej. Data Redaction) sin `licensing_profile`
confirmado — riesgo de uso no licenciado, reportado como finding para revisión del cliente, no
una acusación.

# False positives

Ninguno — el gate es conservador por diseño (nunca asume `INCLUDED`).

# Correlation rules

Consolida `security/database-vault-awareness`, `security/ols-awareness`,
`security/data-redaction-awareness`, `security/data-masking-awareness`, `security/tde-awareness`.
Alimenta `security/compliance-mapping`.

# Confidence model

`FACT` para instalado/visible. `OBSERVATION` para el status de licenciamiento sin confirmación
explícita.

# Severity

Informativo — es un gate de proceso, no una vulnerabilidad técnica.

# Output schema

```yaml
licensing_gates:
  - feature: string
    required: bool
    edition: string|null
    pack: string|null
    status: INCLUDED|SEPARATELY_LICENSED|LICENSE_RESTRICTED|UNKNOWN|REQUIRES_REVIEW
    source: string
    evidence_refs: [EVD-...]
```

# Related skills

`security/database-vault-awareness`, `security/ols-awareness`, `security/data-redaction-awareness`,
`security/data-masking-awareness`, `security/tde-awareness`.

# Escalation

Feature en uso activo sin licencia confirmada → finding para revisión del cliente/legal, nunca
una acción técnica automática.

# Manual remediation guidance

N/A — decisión de licenciamiento, no remediación técnica.

# Security

Ninguna exposición adicional — consolida metadata ya sanitizada.

# Tests

`tests/test_security_licensing_gate.sh`, `tests/test_license_unknown_requires_review.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/security-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

v1.1.0 — `CHG-ESTACK-C-NEW-QUERIES-001`: evidencia opcional del gateway (ver Optional evidence).
