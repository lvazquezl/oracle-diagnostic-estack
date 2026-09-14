---
name: tablespace-encryption
id: security/tablespace-encryption
version: 1.0.0
domain: security
status: active
---

# Purpose

Clasifica tablespaces `ENCRYPTED|UNENCRYPTED|UNKNOWN|NOT_APPLICABLE` — nunca declara
incumplimiento sin policy target (`# 33` del prompt de Fase 8).

# Supported Oracle versions

11g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-ENCRYPTED-TABLESPACES-001`

# Optional evidence

Ninguna.

# Licensing requirements

Advanced Security Option donde aplique.

# Query IDs

`Q-SEC-ENCRYPTED-TABLESPACES-001`.

# Collector IDs

`get_tablespace_encryption`.

# Read-only operations

Lectura de `V$ENCRYPTED_TABLESPACES`/`DBA_TABLESPACES`.

# Forbidden operations

Nunca ejecuta `ALTER TABLESPACE ... ENCRYPTION`.

# Decision logic

1. Tablespace sin fila en `V$ENCRYPTED_TABLESPACES` → `UNENCRYPTED` (ausencia es la evidencia,
   no `UNKNOWN`).
2. Sin `Target Profile.security.encryption_required` definido → `policy_target_encrypted: null`,
   nunca se declara incumplimiento.
3. En 10g/11.1 (sin `V$ENCRYPTED_TABLESPACES`) → `NOT_APPLICABLE`, `capability_status:
   UNSUPPORTED`.

# Normal state

Tablespaces de datos sensibles `ENCRYPTED` cuando la política del cliente lo requiere.

# Abnormal patterns

Tablespace conocido como sensible por el DBA `UNENCRYPTED` con `encryption_required: true` en
Target Profile.

# False positives

Tablespaces de sistema (`SYSTEM`, `SYSAUX`) `UNENCRYPTED` no son anómalos por defecto salvo
política explícita que los incluya.

# Correlation rules

Consume `security/tde-awareness`. Alimenta `security/compliance-mapping`.

# Confidence model

`FACT`.

# Severity

`HIGH` sólo cuando hay policy target explícito y no se cumple.

# Output schema

```yaml
tablespace_encryption:
  - tablespace_token: string
    classification: ENCRYPTED|UNENCRYPTED|UNKNOWN|NOT_APPLICABLE
    policy_target_encrypted: bool|null
    evidence_refs: [EVD-...]
```

# Related skills

`security/tde-awareness`.

# Escalation

Incumplimiento de policy target explícito → finding, nunca acción automática.

# Manual remediation guidance

`manual_action` sugiere migración a tablespace encriptado (`ALTER TABLESPACE ... ENCRYPTION
OFFLINE`/online move) — siempre `NOT_EXECUTED`, operación de alto impacto que requiere ventana
de mantenimiento.

# Security

`tablespace_name` → KEEP.

# Tests

`tests/test_tablespace_encryption.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/encryption-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.
