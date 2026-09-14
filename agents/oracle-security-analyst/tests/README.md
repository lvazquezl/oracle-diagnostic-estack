# Tests — oracle-security-analyst

Los tests de contrato de este agente viven en `tests/` (raíz del repositorio), no aquí — mismo
patrón que `oracle-multitenant-analyst`/`oracle-dataguard-analyst`/`oracle-rac-analyst`/
`oracle-asm-storage-analyst`/`oracle-network-analyst`/`oracle-backup-recovery-analyst`.

Ver:

- `tests/test_security_agent_manifest.sh`
- `tests/test_security_agent_routing.sh`
- `tests/test_security_agent_no_execution_capability.sh`
- `tests/test_security_agent_no_delegation_loop.sh`

Además, el dominio completo de Seguridad tiene su propia suite extensa de tests de
seguridad/compliance/password-policy — ver `tests/README.md` (raíz) y
`docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md#test-results`.
