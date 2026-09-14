---
name: tls-awareness
id: security/tls-awareness
version: 1.0.0
domain: security
status: active
---

# Purpose

Awareness de versiones TLS, TCPS, validez/expiry de certificado, protocolos débiles — nunca
realiza handshake activo a PROD sin collector aprobado (`# 35` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai (TCPS disponible desde versiones tempranas; detalle depende del collector de red
disponible).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Integra con `oracle-network-analyst`.

# Required evidence

- evidencia de `oracle-network-analyst` (`network/oracle-net-security`,
  `get_oracle_net_security_configuration` — listener/TCPS endpoints) cuando disponible

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna directa en este dominio — delega collectors de red a `oracle-network-analyst`.

# Collector IDs

Delegado — `oracle-network-analyst` posee los collectors de listener/TCPS.

# Read-only operations

Lectura pasiva de configuración ya recolectada por `oracle-network-analyst`.

# Forbidden operations

Nunca realiza handshake TLS activo contra un listener de producción sin un collector
explícitamente aprobado y certificado.

# Decision logic

1. Sin evidencia de `oracle-network-analyst`, todos los campos quedan `null`,
   `capability_status: INSUFFICIENT_EVIDENCE` — nunca se asume TLS presente/ausente.
2. `weak_protocol_detected` sólo se reporta cuando hay evidencia positiva de un protocolo
   deprecado (SSLv3, TLS 1.0/1.1) — nunca inferido.

# Normal state

TCPS configurado con certificado válido y protocolo TLS 1.2+ cuando la política del cliente lo
requiere.

# Abnormal patterns

Certificado próximo a expirar (`certificate_expiry_days` bajo) o protocolo débil detectado.

# False positives

Ausencia de TCPS no es anómala si la política del cliente no lo requiere (ej. red interna
confiable con otros controles compensatorios) — el finding se reporta, la severidad depende del
Target Profile.

# Correlation rules

Consume `oracle-network-analyst`. Alimenta `security/network-encryption`,
`security/security-healthcheck`.

# Confidence model

`OBSERVATION` — depende de evidencia externa de `oracle-network-analyst`.

# Severity

`HIGH` si `weak_protocol_detected: true` en producción; `MEDIUM` si certificado expira en <30
días.

# Output schema

```yaml
tls:
  tls_listener_endpoints_detected: bool|null
  tcps_configured: bool|null
  certificate_expiry_days: int|null
  weak_protocol_detected: bool|null
  evidence_refs: [EVD-...]
```

# Related skills

`security/network-encryption`.

# Escalation

Certificado expirado o protocolo débil en producción → `incident-root-cause-analyst`.

# Manual remediation guidance

`manual_action` sugiere renovación de certificado o actualización de protocolo — siempre
`NOT_EXECUTED`.

# Security

Ninguna exposición de contenido de certificado privado (sólo metadata pública: expiry, subject
si aplica, siempre MASK por defecto).

# Tests

`tests/test_tls_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/network-security.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.
