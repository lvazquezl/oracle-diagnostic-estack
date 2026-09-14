# PHASE 8 — ORACLE SECURITY & COMPLIANCE

Baseline: `v0.7.0-backup-recovery-rman`. Branch: `phase/8-security-compliance`.

**Nota (superado)**: 3 defectos reales detectados en este build base — un gap sistémico del
Static Validator para objetos `DBA_*`/`CDB_*`/etc. (nunca validados, ninguna fase del catálogo),
un boundary de patch-level incorrecto en `DBA_USERS.LAST_LOGIN` (corregido a `12.1.0.2`), y
`Q-SEC-NETWORK-ENCRYPTION-PARAMS-001` certificando `SQLNET.*` desde una fuente de evidencia
estructuralmente incorrecta (`V$PARAMETER`) — fueron detectados y corregidos en el hardening
posterior, ver `docs/PHASE_8_SECURITY_QUERY_ORACLE_NET_STATIC_VALIDATOR_HARDENING.md`. El
catálogo Security activo pasa de 30 a 29 queries SQL certificadas (una retirada, reemplazada por
el collector semántico `network/oracle-net-security`). **PHASE 8 — FINAL DBA_USERS 12.1.0.2
SOURCE-OF-TRUTH CORRECTION**: `DBA_USERS.COMMON`/`DBA_USERS.ORACLE_MAINTAINED` también requieren
`12.1.0.2` (footnote oficial verbatim, verificado en HTML crudo — no `12.1.0.1` como se certificó
inicialmente en el hardening anterior) — ver
`docs/PHASE_8_FINAL_DBA_USERS_12102_SOURCE_OF_TRUTH_CORRECTION.md`.

## Objetivo

Construir la capa especializada para diagnóstico, assessment y evaluación de postura de seguridad y compliance de Oracle Database — cuentas/roles/privilegios, password policy, auditoría, TDE/keystore, cifrado de red, parámetros de seguridad, DB links/directories, Database Vault/OLS/Data Redaction/Data Masking — siempre read-only, nunca ejecuta ninguna operación mutante (GRANT/REVOKE/ALTER USER/AUDIT/ADMINISTER KEY MANAGEMENT/etc.).

## Agente principal

`agents/oracle-security-analyst/` — contrato completo (`AGENT.md`, `manifest.yaml`, `routing.yaml`, `context-policy.yaml`, `collaboration.yaml`, `output-schema.yaml`, `tests/README.md`, `CHANGELOG.md`), mismo patrón que RAC/ASM/Network/Data Guard/Multitenant/RMAN. v2.0.0 — `supersedes` documentado explícitamente en `manifest.yaml` porque, a diferencia del gap dangling de `oracle-backup-recovery-analyst` en Fase 7, `agents/oracle-security-analyst.md` (plano) sí existía con contenido real desde Foundation; ese archivo fue eliminado y reemplazado por el contrato estructurado completo, preservando y amplificando sus responsabilidades/boundaries originales sin contradecirlos.

Un solo agente cubre todo el dominio Security — explícitamente **no** se crean agentes separados para audit/TDE/wallet/roles/profiles/password-policy/Database Vault/compliance (`# 4` del prompt).

## Skills

39 skills `security/*` materializadas (`SKILL.md` + `manifest.yaml` cada una): `account-inventory`, `default-accounts`, `common-local-users`, `account-status`, `roles`, `role-grants`, `nested-role-grants`, `system-privileges`, `object-privileges`, `public-system-grants`, `public-object-grants`, `powerful-privileges`, `admin-privileges`, `proxy-authentication`, `password-profiles`, `password-policy-assessment`, `password-verify-function`, `password-special-character-requirement`, `password-versions`, `existing-password-compliance`, `unified-auditing`, `traditional-auditing`, `privileged-audit`, `audit-configuration`, `tde-awareness`, `keystore-awareness`, `tablespace-encryption`, `network-encryption`, `tls-awareness`, `security-parameters`, `db-links`, `directories`, `database-vault-awareness`, `ols-awareness`, `data-redaction-awareness`, `data-masking-awareness`, `licensing-gates`, `compliance-mapping`, `security-diagnostics`, `manual-remediation-plan`.

## Query catalog / variants

30 queries certificadas bajo `queries/security/**` (`Q-SEC-ACCOUNT-INVENTORY-001` … `Q-SEC-DATA-REDACTION-POLICIES-001`) — ver [`docs/ORACLE_SECURITY_READONLY_QUERY_MODEL.md`](ORACLE_SECURITY_READONLY_QUERY_MODEL.md) para el catálogo completo. Splits de variantes verificados: `Q-SEC-ACCOUNT-INVENTORY-001` (`INACTIVE_ACCOUNT_TIME` desde 12.2, no 12.1 genérico — confirmado vía múltiples fuentes independientes citando "12c Release 2" específicamente), `Q-SEC-ROLES-001`, `Q-SEC-ADMIN-PRIVILEGES-001` (SYSASM 11g+, SYSBACKUP/SYSDG/SYSKM/COMMON 12.1+), `Q-SEC-TRADITIONAL-AUDIT-001` (ROWNUM legacy / FETCH FIRST 12.1+, corregido antes de la primera ejecución de tests). Todas las variantes declaran `max` explícito — ninguna declara `max: latest`.

## Account / role / privilege model

`security/account-inventory`, `security/default-accounts`, `security/common-local-users`, `security/account-status` — inventario completo con `account_status` reportado tal cual `DBA_USERS.ACCOUNT_STATUS`, `authentication_type` (PASSWORD/EXTERNAL/GLOBAL/NONE), distinción `common`/`local` en multitenant. `security/roles`, `security/role-grants`, `security/nested-role-grants`, `security/system-privileges`, `security/object-privileges`, `security/public-system-grants`, `security/public-object-grants`, `security/powerful-privileges`, `security/admin-privileges`, `security/proxy-authentication` — resuelven la cadena completa `DIRECT|VIA_ROLE`, nunca sólo grants directos. Ver [`docs/ORACLE_SECURITY_PRIVILEGE_MODEL.md`](ORACLE_SECURITY_PRIVILEGE_MODEL.md).

## Password / profile posture

`security/password-profiles`, `security/password-policy-assessment`, `security/password-verify-function`, `security/password-special-character-requirement`, `security/password-versions`, `security/existing-password-compliance` — modelo de política por control (nunca agregado en un score único), extracción read-only de reglas desde `DBA_SOURCE`/`ALL_SOURCE`. `existing_password_compliance: NOT_DIRECTLY_VERIFIABLE` obligatorio incluso con policy `COMPLIANT`. `actual_password_content: NOT_INSPECTED` siempre. Ver [`docs/ORACLE_PASSWORD_POLICY_ASSESSMENT_MODEL.md`](ORACLE_PASSWORD_POLICY_ASSESSMENT_MODEL.md) y [`docs/ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md`](ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md).

## Auditing

`security/unified-auditing`, `security/traditional-auditing`, `security/privileged-audit`, `security/audit-configuration` — version-aware (Unified 12.1+, Traditional todas las versiones), budget obligatorio en toda consulta de audit trail (`:time_window_days`/`:max_rows`). Ver [`docs/ORACLE_AUDIT_DIAGNOSTIC_MODEL.md`](ORACLE_AUDIT_DIAGNOSTIC_MODEL.md).

## TDE / keystore / encryption

`security/tde-awareness`, `security/keystore-awareness`, `security/tablespace-encryption`, `security/network-encryption`, `security/tls-awareness` — cero exposición de secretos (`keystore.secrets_exposed` fijo `false` en el schema), nunca ejecuta `ADMINISTER KEY MANAGEMENT`. Network encryption/TLS integrado con `oracle-network-analyst` sin duplicar collectors. Ver [`docs/ORACLE_TDE_KEYSTORE_AWARENESS_MODEL.md`](ORACLE_TDE_KEYSTORE_AWARENESS_MODEL.md).

## Security parameters / DB links / directories

`security/security-parameters`, `security/db-links`, `security/directories` — awareness de parámetros de seguridad relevantes, database links (credenciales siempre DROP, nunca en evidencia), directories OS-path (paths sanitizados).

## Database Vault / OLS / Data Redaction / Data Masking

`security/database-vault-awareness`, `security/ols-awareness`, `security/data-redaction-awareness`, `security/data-masking-awareness`, `security/licensing-gates` — siempre licensing-gated, nunca asume `INCLUDED` sin `Target Profile.security.licensing_profile` explícito. Data Masking (Enterprise Manager Pack) tratado con licencia explícitamente distinta de Data Redaction (Advanced Security Option, mismo bucket que TDE). Ver [`docs/ORACLE_SECURITY_LICENSING_GATES.md`](ORACLE_SECURITY_LICENSING_GATES.md).

## Compliance mapping

`security/compliance-mapping` — modelo de control genérico no propietario, `framework_certification: NOT_ASSERTED` constante en cada entrada, nunca certifica un framework regulatorio nombrado. Ver [`docs/ORACLE_COMPLIANCE_MAPPING_MODEL.md`](ORACLE_COMPLIANCE_MAPPING_MODEL.md).

## Manual remediation

`security/manual-remediation-plan` — Manual Action Contract completo (`action_id, purpose, owner_role, command, prechecks, expected_result, risk, rollback, postchecks, licensing_gate, execution_status: NOT_EXECUTED`) para toda recomendación de GRANT/REVOKE/ALTER PROFILE/AUDIT/ADMINISTER KEY MANAGEMENT.

## Password hash/verifier protection

Regla verbatim obligatoria presente en `output-schema.yaml` y en la documentación del dominio: *"The e-stack assesses password policy strength; it never attempts to determine, recover, crack, validate, expose, compare, or test actual user passwords or password verifiers."*

## Fixtures / Tests

24 fixtures nuevas bajo `tests/fixtures/` (mínimo 23 requerido). 75 tests nuevos bajo `tests/test_*.sh` en 7 categorías (secciones 66–72 del prompt) — todos verificados pasando individualmente y en batch (`=== total fails: 0 / 75 ===`).

## Capability Matrix

`config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` — nuevo dominio `security` 10g-23ai (con degradaciones version-aware para Unified Auditing/admin privileges/INACTIVE_ACCOUNT_TIME), `future_status: COMPATIBILITY_VALIDATION_REQUIRED`, nunca `latest: SUPPORTED`.

## Documentación

Creados: [`docs/ORACLE_SECURITY_READONLY_PRIVILEGES.md`](ORACLE_SECURITY_READONLY_PRIVILEGES.md), [`docs/ORACLE_SECURITY_READONLY_QUERY_MODEL.md`](ORACLE_SECURITY_READONLY_QUERY_MODEL.md), [`docs/ORACLE_SECURITY_PRIVILEGE_MODEL.md`](ORACLE_SECURITY_PRIVILEGE_MODEL.md), [`docs/ORACLE_SECURITY_DIAGNOSTIC_MODEL.md`](ORACLE_SECURITY_DIAGNOSTIC_MODEL.md), [`docs/ORACLE_PASSWORD_POLICY_ASSESSMENT_MODEL.md`](ORACLE_PASSWORD_POLICY_ASSESSMENT_MODEL.md), [`docs/ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md`](ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md), [`docs/ORACLE_AUDIT_DIAGNOSTIC_MODEL.md`](ORACLE_AUDIT_DIAGNOSTIC_MODEL.md), [`docs/ORACLE_TDE_KEYSTORE_AWARENESS_MODEL.md`](ORACLE_TDE_KEYSTORE_AWARENESS_MODEL.md), [`docs/ORACLE_SECURITY_LICENSING_GATES.md`](ORACLE_SECURITY_LICENSING_GATES.md), [`docs/ORACLE_COMPLIANCE_MAPPING_MODEL.md`](ORACLE_COMPLIANCE_MAPPING_MODEL.md), este documento. `README.md`, `ARCHITECTURE.md` (principio 30), `SECURITY.md`, `CAPABILITY_MATRIX.md`, `CHANGELOG.md`, `docs/TARGET_PROFILE.md` (2.4.0→2.5.0), `workflows/healthcheck.md`, `workflows/diagnose.md`, `workflows/assessment.md`, `policies/forbidden-operations.md`, `agents/REGISTRY.md`, `skills/REGISTRY.md`, `queries/REGISTRY.md` — actualizados.

## Seguridad

READ-ONLY ALWAYS. Ninguna capacidad real de `GRANT|REVOKE|ALTER USER|ALTER PROFILE|CREATE/DROP USER|CREATE/DROP ROLE|AUDIT|NOAUDIT|ADMINISTER KEY MANAGEMENT|CREATE/DROP DATABASE LINK|CREATE/DROP DIRECTORY` — verificado por tests dedicados de seguridad (`test_security_no_*`/`test_security_agent_no_execution_capability.sh` y equivalentes de dominio). Password hash/verifier exposure absolutamente prohibido, verificado por `test_security_no_secrets.sh`.

## Known limitations

- `security/password-verify-function` degrada a `VERIFY_FUNCTION_NOT_ANALYZABLE` cuando la lógica de la función custom no es determinista o depende de configuración externa — nunca se asume compliance por la mera presencia de una función.
- `existing_password_compliance` permanece `NOT_DIRECTLY_VERIFIABLE` de forma permanente por diseño — no existe evidencia Oracle que permita verificar contraseñas ya establecidas contra la política actual sin comprometer el principio de nunca inspeccionar contenido real de contraseñas.
- `security/data-masking-awareness` no tiene vista dinámica de servidor para confirmar licensing — awareness limitada a lo que el cliente confirme explícitamente vía Target Profile.
- Integración profunda de vendor (HSM specifics, EM Data Masking job detail) fuera de alcance — awareness genérica únicamente.

## NOT_CERTIFIED

Ninguna query/vista Security queda sin certificar dentro del alcance declarado en el prompt (30 queries, todas certificadas).
