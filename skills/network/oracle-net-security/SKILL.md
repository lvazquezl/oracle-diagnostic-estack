---
name: oracle-net-security
id: network/oracle-net-security
version: 1.0.0
domain: network
status: active
---

# Purpose

Extrae, de forma semántica y allowlisted, la configuración de seguridad de Oracle Net
(`sqlnet.ora`): Native Network Encryption (`SQLNET.ENCRYPTION_*`, `SQLNET.CRYPTO_CHECKSUM_*`) y
metadata TCPS/TLS — nunca desde `V$PARAMETER`/`V$SPPARAMETER` (PHASE 8 — SECURITY QUERY
COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING, principio no-negociable
"SQLNET.\* IS NOT V\$PARAMETER EVIDENCE"). Reemplaza `Q-SEC-NETWORK-ENCRYPTION-PARAMS-001`
(retirada, `NOT_CERTIFIED: INCORRECT_EVIDENCE_SOURCE`).

# Supported Oracle versions

10g–23ai — los nombres de parámetro `SQLNET.*` son estándar de Oracle Net sin cambio estructural
conocido en ese rango.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- collector semántico `get_oracle_net_security_configuration` (ver `collectors/README.md`)

# Optional evidence

TCPS listener endpoint detail vía `network/listeners`, cuando disponible.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna — esta skill no consulta la base de datos; lee configuración de Oracle Net vía collector
semántico de archivo (mismo canal que `network/oracle-net`, nunca SQL).

# Collector IDs

`get_oracle_net_security_configuration`.

# Read-only operations

Lectura allowlisted de `sqlnet.ora` — sólo los parámetros del allowlist (# 28 del prompt de
hardening); nunca el archivo completo, nunca un path arbitrario.

# Forbidden operations

- Nunca edita `sqlnet.ora`.
- Nunca implementa un lector de archivo genérico (`read_file(path)`/`cat_file(path)`) — el
  collector resuelve el path por convención de plataforma, nunca recibe un path del modelo.
- Nunca ejecuta shell arbitrario (`execute_shell(command)` o equivalente) — el collector nunca
  acepta un comando del modelo, sólo devuelve los parámetros allowlisted ya resueltos.
- Nunca realiza handshake TLS activo contra un listener (eso es `security/tls-awareness`'s
  boundary, y tampoco lo hace).

# Allowlist de parámetros (# 28 del prompt de hardening)

```text
SQLNET.ENCRYPTION_SERVER
SQLNET.ENCRYPTION_CLIENT
SQLNET.ENCRYPTION_TYPES_SERVER
SQLNET.ENCRYPTION_TYPES_CLIENT
SQLNET.CRYPTO_CHECKSUM_SERVER
SQLNET.CRYPTO_CHECKSUM_CLIENT
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT
```

más metadata TCPS/TLS explícitamente permitida: presencia de endpoint TCPS en `listener.ora`
(delegado a `network/listeners`), y — sólo si el collector de certificado está certificado en una
fase futura — versión de protocolo/expiry/subject del certificado, nunca la clave privada.

# Decision logic

1. Resolver la presencia/ubicación de `sqlnet.ora` por convención de plataforma (mismo mecanismo
   que `network/oracle-net`) — nunca un path arbitrario suministrado por el modelo.
2. Extraer únicamente los parámetros del allowlist — cualquier otro parámetro presente en el
   archivo se ignora, nunca se envía.
3. Parámetro ausente en `sqlnet.ora` → `null`, nunca inventado, nunca `"not configured"` como
   sinónimo de `"REJECTED"` (ausencia ≠ rechazo explícito).
4. Si no existe aún un collector runtime certificado para esta fase (`# 30` del prompt de
   hardening): `capability_status: PARTIALLY_SUPPORTED`, `evidence_source:
   MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION` — el DBA provee el contenido ya sanitizado de
   `sqlnet.ora` (mismo patrón de ingest que los parsers RMAN, Fase 7: texto ya producido
   manualmente, nunca ejecutado por el e-stack) y la skill sólo interpreta el allowlist sobre ese
   texto. Nunca se finge `SUPPORTED`.
5. Si el archivo contiene credenciales embebidas (poco común en `sqlnet.ora`, pero posible en
   wallets referenciados), el sanitizer bloquea esa porción antes de llegar al modelo — mismo
   comportamiento que `network/oracle-net`.

# Normal state

Parámetros de encriptación/checksum configurados según la política del cliente; ausencia de
configuración no es intrínsecamente anómala sin un requisito de compliance declarado.

# Abnormal patterns

`SQLNET.ENCRYPTION_SERVER`/`SQLNET.CRYPTO_CHECKSUM_SERVER` ausentes en un ambiente con requisito
de compliance de cifrado en tránsito.

# False positives

Ausencia de un parámetro no implica que el ambiente esté desprotegido si existe TCPS/TLS a nivel
de listener en su lugar — Native Network Encryption y TLS/TCPS son mecanismos distintos, nunca
mezclados (`# 32` del prompt de hardening); `security/network-encryption` y `security/tls-awareness`
evalúan cada uno por separado.

# Correlation rules

Alimenta `security/network-encryption` (Native Network Encryption) y `security/tls-awareness`
(TCPS/TLS) — este skill sólo obtiene evidencia read-only; la interpretación de compliance/riesgo
queda en `oracle-security-analyst` (`# 31` del prompt de hardening: Security interpreta, Network
obtiene).

# Confidence model

`FACT` para un parámetro leído directamente de `sqlnet.ora` ya sanitizado. `INSUFFICIENT_EVIDENCE`
cuando no hay collector certificado ni contenido manual suministrado.

# Severity

N/A — esta skill no emite severidad; delega la interpretación a `security/network-encryption`/
`security/tls-awareness`.

# Output schema

```yaml
oracle_net_security:
  capability_status: SUPPORTED|PARTIALLY_SUPPORTED|INSUFFICIENT_EVIDENCE
  evidence_source: SEMANTIC_COLLECTOR|MANUAL_SANITIZED_ORACLE_NET_CONFIGURATION|null
  encryption_server: string|null
  encryption_client: string|null
  encryption_types_server: [string]|null
  encryption_types_client: [string]|null
  crypto_checksum_server: string|null
  crypto_checksum_client: string|null
  crypto_checksum_types_server: [string]|null
  crypto_checksum_types_client: [string]|null
  tcps_endpoint_detected: bool|null
  evidence_refs: [EVD-...]
```

# Related skills

`network/oracle-net`, `security/network-encryption`, `security/tls-awareness`.

# Escalation

Ninguna directa — evidencia read-only consumida por `security/network-encryption`/
`security/tls-awareness`.

# Manual remediation guidance

Ninguna directa — la remediación (ej. `SQLNET.ENCRYPTION_SERVER=REQUIRED`) se genera desde
`security/network-encryption` como `manual_action`, siempre `NOT_EXECUTED`; esta skill nunca
sugiere cambios de configuración por sí misma.

# Security

`sqlnet.ora` nunca se envía completo — sólo los valores del allowlist. Credenciales/paths de
wallet embebidos → bloqueados por el sanitizer, nunca al modelo.

# Tests

`tests/test_sqlnet_parameters_not_sourced_from_v_parameter.sh`,
`tests/test_network_encryption_uses_network_evidence.sh`,
`tests/test_oracle_net_collector_no_arbitrary_file_read.sh`,
`tests/test_oracle_net_collector_no_arbitrary_shell.sh`,
`tests/test_network_encryption_partial_without_collector.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/network-security.md`.

# Change history

v1.0.0 — PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR
HARDENING, creación inicial (reemplaza a `Q-SEC-NETWORK-ENCRYPTION-PARAMS-001`, retirada por
`INCORRECT_EVIDENCE_SOURCE`).
