---
name: cdb-discovery
id: multitenant/cdb-discovery
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Determinar CDB vs. NON-CDB reutilizando el bootstrap de Oracle Core (`Q-DISC-IDENTITY-001`) — nunca re-implementa detección de `V$DATABASE.CDB`, y nunca la lee en versiones anteriores a 12c (`# 7` del prompt de Fase 6).

# Supported Oracle versions

10g–23ai — este skill en particular SÍ se ejecuta en 10g/11g, mínimamente, para producir la respuesta `MULTITENANT_STATUS: NOT_APPLICABLE` sin activar el resto del agente (`# 6`).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno — es el primer punto de contacto, junto con `multitenant/architecture`.

# Required evidence

Ninguna propia — reutiliza `target_profile.architecture.multitenant_mode`, ya determinado por `oracle-discovery-analyst` vía `Q-DISC-IDENTITY-001` (Oracle Core, Fase 2).

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

Ninguno propio — `Q-DISC-IDENTITY-001` pertenece a Oracle Core, referenciado aquí sólo como fuente.

# Collector IDs

Ninguno.

# Read-only operations

Ninguna consulta propia.

# Forbidden operations

No ejecuta ninguna query `CDB_*`/`V$PDBS`/`V$CONTAINERS` cuando el target es NON-CDB o 10g/11g.

# Decision logic

1. Leer `target_profile.architecture.multitenant_mode`.
2. Si `non_cdb` (incluye siempre 10g/11g, y 12c+ configurado sin multitenant): responder `MULTITENANT_STATUS: NOT_APPLICABLE`, no activar ningún otro skill `multitenant/*`, puede delegar a Oracle Core para el resto del diagnóstico (`# 6`).
3. Si `cdb`: publicar la confirmación y ceder el flujo a `multitenant/architecture`.

# Normal state

`multitenant_mode` determinado con `confidence: FACT` en ambos casos.

# Abnormal patterns

`multitenant_mode` no determinable (`ENVIRONMENT_UNKNOWN` en el Target Profile) — el skill declara `INSUFFICIENT_EVIDENCE`, nunca asume CDB ni NON-CDB por defecto.

# False positives

Ninguno — es una lectura directa de un campo ya publicado, no una inferencia.

# Correlation rules

N/A — es la puerta de entrada, no correlaciona con otros hallazgos.

# Confidence model

`FACT` siempre que el Target Profile lo reporte como tal.

# Severity

N/A.

# Output schema

```yaml
multitenant_status: NOT_APPLICABLE|APPLICABLE
multitenant_mode: non_cdb|cdb
evidence_refs: [EVD-...]
```

# Related skills

`multitenant/architecture`.

# Escalation

N/A.

# Manual remediation guidance

Ninguna.

# Security

Ninguna dato sensible propio.

# Tests

`tests/test_multitenant_not_applicable_11g.sh`, `tests/test_cdb_detection_12c.sh`, `tests/test_11g_multitenant_not_applicable.sh`.

# Documentation requirements

N/A.

# Change history

v1.0.0 — Fase 6, creación inicial.
