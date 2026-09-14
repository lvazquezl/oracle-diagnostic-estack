---
name: security-filesystem-awareness
id: os/security-filesystem-awareness
version: 1.0.0
domain: os
status: active
---

# Purpose

Correlaciona permisos de filesystem de wallet TDE, binarios Oracle y grupos OS con
`oracle-security-analyst` — nunca modifica permisos.

# Supported Oracle versions

N/A directo — wallet TDE existe desde 10.2 (column encryption)/11.2 (tablespace encryption, ver
`docs/ORACLE_TDE_KEYSTORE_AWARENESS_MODEL.md`).

# Supported OS/platforms

Linux/Solaris: `SUPPORTED` (modelo de permisos POSIX). Windows: `PARTIALLY_SUPPORTED` (ACLs,
modelo distinto).

# Supported architectures

Standalone y RAC.

# Prerequisites

`os/mount-options`, `os/oracle-groups` recomendados; ubicación del wallet TDE conocida (vía
`oracle-security-analyst`, nunca determinada por este skill).

# Required evidence

- collector `get_mount_summary` (ownership/permisos del path del wallet, nunca su contenido)

# Optional evidence

- ownership/permisos de `ORACLE_HOME`/binarios críticos

# Read-only operations

Lectura de ownership/permisos de archivo/directorio — **nunca** contenido del wallet ni de
ningún archivo de credencial.

# Forbidden operations

Nunca modifica permisos, nunca lee contenido del wallet (`# 50` del prompt: "No modificar
permisos").

# Decision logic

1. Reportar ownership/permisos del directorio del wallet TDE — debe ser exclusivo del owner
   Oracle/Grid (`700`/owner único), nunca world-readable.
2. Wallet con permisos amplios (`group`/`world` readable) → `CRITICAL` — exposición potencial de
   material de clave.
3. Correlacionar con `os/oracle-groups` — el owner/grupo del wallet debe coincidir con el
   usuario/grupo Oracle esperado, nunca un usuario genérico o inesperado.
4. Nunca lee ni transmite el contenido del wallet bajo ninguna circunstancia — sólo metadata de
   filesystem.

# Normal state

Wallet con permisos exclusivos del owner Oracle, sin acceso `group`/`world`.

# Abnormal patterns

Wallet con permisos amplios, owner/grupo inesperado.

# False positives

Ninguno conocido — permisos amplios en un directorio de wallet son siempre un hallazgo relevante.

# Correlation rules

Alimenta `oracle-security-analyst` (`security/tde-awareness`/`security/keystore-awareness`, por
referencia — nunca duplica ese análisis).

# Confidence model

`FACT` para permisos leídos directamente.

# Severity

`CRITICAL` si el wallet tiene permisos `group`/`world` readable.

# Output schema

```yaml
security_filesystem:
  wallet_path_token: string|null   # TOKENIZE, nunca el path completo sin enmascarar
  wallet_permissions: string|null
  wallet_owner_expected: bool|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/mount-options`, `os/oracle-groups`, `os/ssh-sshd-awareness`.

# Escalation

Permisos amplios en wallet escala inmediatamente a `oracle-security-analyst`.

# Manual remediation guidance

`manual_action` sugiere `chmod 700`/corrección de ownership — siempre `NOT_EXECUTED`, ejecución
delegada al administrador OS/DBA de seguridad.

# Security

Path del wallet → `TOKENIZE` por defecto. Contenido del wallet nunca leído ni transmitido.

# Tests

`tests/test_os_security_wallet_permission_awareness.sh`, `tests/test_os_path_sanitization.sh`.

# Documentation requirements

Alimenta `manual-hardening.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
