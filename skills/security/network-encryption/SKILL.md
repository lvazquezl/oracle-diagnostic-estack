---
name: network-encryption
id: security/network-encryption
version: 2.0.0
domain: security
status: active
---

# Purpose

Interpreta compliance/riesgo de `SQLNET.ENCRYPTION_CLIENT/SERVER`, `SQLNET.CRYPTO_CHECKSUM_*` —
consume la evidencia read-only de `oracle-network-analyst` (`network/oracle-net-security`), nunca
la obtiene por sí misma ni edita configuración (`# 34` del prompt de Fase 8; `# 31` del prompt de
hardening ORACLE NET EVIDENCE: Security interpreta, Network obtiene).

**PHASE 8 HARDENING (SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR)**:
`Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` (que intentaba leer `SQLNET.*` desde `V$PARAMETER`) fue
retirada — `NOT_CERTIFIED: INCORRECT_EVIDENCE_SOURCE`, `SQLNET.*` es configuración de Oracle Net
(`sqlnet.ora`), nunca un parámetro de inicialización de instancia. Esta skill ya no declara
ninguna query SQL propia.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- evidencia de `oracle-network-analyst` (`network/oracle-net-security`,
  `get_oracle_net_security_configuration`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna — este dominio no ejecuta SQL para esta evidencia; consume el collector semántico de
`oracle-network-analyst`.

# Collector IDs

Delegado — `oracle-network-analyst` posee `get_oracle_net_security_configuration`.

# Read-only operations

Lectura pasiva de la evidencia ya recolectada por `oracle-network-analyst` (`network/oracle-net-security`).

# Forbidden operations

Nunca modifica `sqlnet.ora`/`listener.ora`. Nunca implementa su propio collector de red — toda
evidencia de Oracle Net se obtiene exclusivamente vía `oracle-network-analyst` (`# 31` del prompt
de hardening).

# Decision logic

1. Parámetro no presente en la evidencia de `oracle-network-analyst` → `null`, nunca inventado.
2. Sin evidencia disponible (`capability_status: PARTIALLY_SUPPORTED`/`INSUFFICIENT_EVIDENCE` de
   `network/oracle-net-security`, incluyendo el fallback `evidence_source:
   MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION` cuando el DBA provee `sqlnet.ora` ya sanitizado sin
   collector runtime certificado) → esta skill publica el mismo `capability_status`, nunca
   `SUPPORTED` fingido (`# 30`/`# 37` del prompt de hardening).
3. Reporta el algoritmo configurado (ej. `AES256`) sin evaluar fortaleza — eso queda a criterio
   del compliance mapping del cliente.

# Normal state

Encriptación configurada como `REQUIRED`/`REQUESTED` según política del cliente.

# Abnormal patterns

Sin ningún parámetro `SQLNET.ENCRYPTION_*` configurado en un ambiente con requisito de
compliance de encriptación en tránsito.

# False positives

`capability_status: PARTIALLY_SUPPORTED` (sin collector runtime certificado de
`network/oracle-net-security`) no significa "no configurado" — significa evidencia insuficiente;
esta skill nunca colapsa `PARTIALLY_SUPPORTED` en un hallazgo de "ausente".

# Correlation rules

Consume `oracle-network-analyst` (`network/oracle-net-security`). Alimenta
`security/tls-awareness`, `security/security-healthcheck`.

# Confidence model

`OBSERVATION` — depende de la evidencia de `oracle-network-analyst`; `FACT` sólo si
`network/oracle-net-security` reporta `capability_status: SUPPORTED` con `evidence_source:
SEMANTIC_COLLECTOR`.

# Severity

`MEDIUM` si no hay evidencia de encriptación configurada y el cliente requiere compliance de
red.

# Output schema

```yaml
network_encryption:
  capability_status: SUPPORTED|PARTIALLY_SUPPORTED|INSUFFICIENT_EVIDENCE
  client_encryption: string|null
  server_encryption: string|null
  crypto_checksum: string|null
  evidence_refs: [EVD-...]
```

# Related skills

`security/tls-awareness`.

# Escalation

Ninguna directa — delega detalle a `oracle-network-analyst`.

# Manual remediation guidance

`manual_action` sugiere configurar `SQLNET.ENCRYPTION_SERVER=REQUIRED` en `sqlnet.ora` — siempre
`NOT_EXECUTED`, edición de archivo delegada a `os-platform-analyst`/DBA.

# Security

`value` → KEEP (nombre de algoritmo).

# Tests

`tests/test_network_encryption_awareness.sh`, `tests/test_no_network_config_execution.sh`,
`tests/test_sqlnet_parameters_not_sourced_from_v_parameter.sh`,
`tests/test_network_encryption_uses_network_evidence.sh`,
`tests/test_network_encryption_partial_without_collector.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/network-security.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.
v2.0.0 — PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR
HARDENING: `Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` retirada (`INCORRECT_EVIDENCE_SOURCE` —
`SQLNET.*` no es evidencia de `V$PARAMETER`); esta skill ya no declara ninguna query SQL propia,
consume exclusivamente `network/oracle-net-security` (`oracle-network-analyst`).
