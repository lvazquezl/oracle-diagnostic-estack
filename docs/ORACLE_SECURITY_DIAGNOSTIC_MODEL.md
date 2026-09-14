# Oracle Security Diagnostic Model — Fase 8

## Health Model

Por dimensión, nunca un score único opaco (mismo patrón que `docs/RMAN_DIAGNOSTIC_MODEL.md`):

```text
ACCOUNT_INVENTORY
ROLES_AND_PRIVILEGES
PUBLIC_GRANTS
ADMIN_PRIVILEGES
PASSWORD_PROFILE_POSTURE
PASSWORD_STRENGTH_POLICY
AUDIT_CONFIGURATION
TDE_ENCRYPTION
NETWORK_ENCRYPTION
SECURITY_PARAMETERS
DB_LINKS_DIRECTORIES
DATABASE_VAULT
OLS
DATA_REDACTION
DATA_MASKING
```

Estados: `HEALTHY|WARNING|DEGRADED|CRITICAL|UNKNOWN|NOT_APPLICABLE|LICENSE_RESTRICTED`. `LICENSE_RESTRICTED` es específico de este dominio — ver [`docs/ORACLE_SECURITY_LICENSING_GATES.md`](ORACLE_SECURITY_LICENSING_GATES.md).

## Evidence model

```text
account_name (sanitizado por defecto salvo confirmación explícita)
role_name
privilege_name
grant_path            # DIRECT | VIA_ROLE
grantee_type          # USER | ROLE | PUBLIC
profile_name
audit_mechanism        # UNIFIED | TRADITIONAL
encryption_algorithm
source
query_id
collector_id
variant_id
validation_status
sanitization
```

Trazabilidad: `EVD → FND → REC → CHG` (mismo modelo que el resto del e-stack).

## Account/role/privilege model

```yaml
account:
  username:
  account_status:          # OPEN | LOCKED | EXPIRED | EXPIRED(GRACE) | LOCKED(TIMED) | ...
  authentication_type:      # PASSWORD | EXTERNAL | GLOBAL | NONE
  profile:
  common_or_local:          # multitenant only
  default_tablespace_flagged:  # SYSTEM/SYSAUX default tablespace on non-Oracle-maintained account
  last_login:
```

`account_status` reportado tal cual `DBA_USERS.ACCOUNT_STATUS` lo declara — nunca se inventa un mapping adicional.

## PUBLIC exposure / powerful privileges

Ver [`docs/ORACLE_SECURITY_PRIVILEGE_MODEL.md`](ORACLE_SECURITY_PRIVILEGE_MODEL.md).

## Password / audit / TDE / network models

Ver [`docs/ORACLE_PASSWORD_POLICY_ASSESSMENT_MODEL.md`](ORACLE_PASSWORD_POLICY_ASSESSMENT_MODEL.md), [`docs/ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md`](ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md), [`docs/ORACLE_AUDIT_DIAGNOSTIC_MODEL.md`](ORACLE_AUDIT_DIAGNOSTIC_MODEL.md), [`docs/ORACLE_TDE_KEYSTORE_AWARENESS_MODEL.md`](ORACLE_TDE_KEYSTORE_AWARENESS_MODEL.md).

## Sanitización / tokenización

```text
usernames (MASK por defecto salvo confirmación explícita del cliente)
role names custom
password verify function names/source (nunca literal completo sin sanitizar comentarios/strings)
wallet paths (wrl_parameter)
DB link connection strings / hosts / credentials (siempre DROP para credenciales)
directory OS paths
audit trail free-text comments
```

Ver [`docs/ORACLE_SECURITY_READONLY_PRIVILEGES.md`](ORACLE_SECURITY_READONLY_PRIVILEGES.md) para el detalle de sanitización por vista.

## Context/token policy

Nunca se envían miles de rows de audit trail o grants completos. Preferir: cuentas privilegiadas, cuentas con password expirado/gracia, roles PUBLIC con privilegios sensibles, top hallazgos por severidad, evidence refs — mismo principio de minimización que el resto del e-stack (`docs/CONTRACTS.md#context-token-model`).

## Multitenant / Data Guard / Backup-Recovery integration

- **Multitenant**: todo hallazgo distingue explícitamente `common` vs. `local` — nunca mezclado entre containers (mismo patrón que Fase 6).
- **Data Guard**: `security/network-encryption` coordina con `oracle-network-analyst` para awareness de cifrado en el canal de redo transport, sin duplicar collectors.
- **Backup/Recovery**: TDE keystore awareness es prerequisito informativo para `rman/restore-readiness` (un backup de tablespace TDE-encrypted requiere el wallet correspondiente en restore) — referencia cruzada documental únicamente, sin nuevo collector.

## Manual remediation

Ver `security/manual-remediation-plan` — Manual Action Contract completo (`action_id, purpose, owner_role, command, prechecks, expected_result, risk, rollback, postchecks, licensing_gate, execution_status: NOT_EXECUTED`).
