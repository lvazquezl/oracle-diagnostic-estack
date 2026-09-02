# Tests — Fase 1 + Foundation Hardening quality gates

Suite de validación **estática** (no requiere ambiente Oracle/OS real) sobre los contratos, catálogo y políticas del repositorio. Corresponde a la sección 22 del prompt maestro de Fundación y a la sección 14 del prompt de Foundation Hardening. Validación de runtime real (collectors vivos, Gateway MCP ejecutando) es Fase 7+.

## Ejecutar

```bash
bash tests/run-all.sh
```

En Windows, ejecutar cada script vía Git Bash/WSL (los scripts son POSIX sh), o usar `bash.exe` si está disponible.

## Cobertura (sección 22 del prompt maestro)

| Test | Qué valida |
|---|---|
| `test_no_write_operations.sh` | Ninguna query certificada contiene verbos DML/DDL |
| `test_no_shell_arbitrary.sh` | Ninguna tool/agente declara shell o SQL arbitrario |
| `test_no_srvctl_crsctl_systemctl_write.sh` | Ninguna query/tool invoca verbos de cambio de srvctl/crsctl/systemctl |
| `test_application_data_blocked.sh` | Toda query certificada apunta sólo a diccionario/V$/GV$/histórico, nunca a esquema de aplicación |
| `test_secret_detection.sh` | No hay secretos (passwords, keys, tokens) en el repositorio distribuible |
| `test_version_awareness.sh` | Todo skill/query activo declara versiones Oracle soportadas |
| `test_rac_standalone_detection.sh` | El modelo de discovery distingue explícitamente RAC/standalone |
| `test_cdb_pdb_detection.sh` | El modelo de discovery distingue explícitamente CDB/PDB/NON-CDB |
| `test_primary_standby_detection.sh` | El modelo de discovery distingue explícitamente Primary/Standby |
| `test_os_detection.sh` | El modelo de discovery/os-platform-analyst cubre todas las plataformas requeridas |
| `test_query_limits.sh` | Toda query activa declara timeout y max_rows |
| `test_sanitization_policy.sh` | La política de sanitización cubre KEEP/MASK/HASH/TOKENIZE/DROP |
| `test_evidence_traceability.sh` | El modelo EVD→FND→REC→CHG está definido y referenciado |
| `test_minimum_agent_activation.sh` | Todo workflow declara Minimum/Optional agents y Activation conditions |
| `test_change_governance_flow.sh` | `/change` implementa el flujo completo de 12 pasos sin saltos |
| `test_document_traceability.sh` | Documentación exige análisis Markdown de origen antes de cualquier binario |
| `test_no_promotion_without_human_review.sh` | HUMAN REVIEW es obligatorio antes de PROMOTE en `/change` |
| `test_registries_consistency.sh` | Todo skill/agente `active` referenciado en su registro tiene archivo materializado |
| `test_no_credential_exposure.sh` | Ningún manifest solicita SYSDBA/SYSOPER/SYSASM/root/sudo |
| `adversarial/prompt-injection-cases.md` | Casos de prueba de contenido malicioso embebido en evidencia (manual/futuro harness) |

## Cobertura — Foundation Hardening (sección 14)

| Test | Qué valida |
|---|---|
| `test_skill_ids_are_globally_unique.sh` | Ningún `skill_id` se repite en `skills/REGISTRY.md` |
| `test_skill_ids_are_domain_qualified.sh` | Todo `skill_id` es `dominio/skill`, nunca un nombre corto suelto |
| `test_no_ambiguous_skill_references.sh` | Ningún agente/workflow referencia un skill por nombre corto ambiguo |
| `test_query_contract_requires_container_scope.sh` | Toda query certificada declara `container_scope` válido |
| `test_query_contract_requires_role_scope.sh` | Toda query certificada declara `database_role_scope` válido |
| `test_query_contract_requires_cost_class.sh` | Toda query certificada declara `cost_class`/`risk_class` válidos, ninguna `BLOCKED` |
| `test_query_contract_requires_license_metadata.sh` | (cubierto dentro de `test_query_contract_requires_cost_class.sh` + `test_license_gate_*`) — `license_requirements` presente |
| `test_query_cost_low.sh` / `_medium.sh` / `_high.sh` / `_blocked.sh` | `policies/query-cost-policy.md` documenta las 4 clases; existen ejemplos certificados de LOW/MEDIUM/HIGH; ninguna certificada es BLOCKED |
| `test_capability_supported.sh` … `test_capability_environment_unknown.sh` (8) | Los 8 estados de `policies/capability-degradation-policy.md` están documentados con sus 5 campos obligatorios |
| `test_10g_multitenant_unsupported.sh` | Multitenant en 10g/11g es `UNSUPPORTED` (no `PLANNED`/`FOUNDATION_ONLY`) |
| `test_standalone_rac_unsupported.sh` | Un target standalone no activa `oracle-rac-analyst` (gate `architecture` de `workflows/rac.md`) |
| `test_non_cdb_pdb_unsupported.sh` | `multitenant/pdb` no aplica fuera de CDB |
| `test_license_gate_blocks_unknown_license_when_required.sh` | La secuencia de gate de licensing bloquea (`LICENSE_RESTRICTED`) cuando no se puede confirmar |
| `test_license_gate_allows_nonlicensed_alternative.sh` | Existe ruta alternativa no licenciada documentada (AWR→Statspack) |
| `test_workflow_skips_incompatible_agent.sh` | Todo workflow declara bloque `# Gates` |
| `test_workflow_skips_incompatible_skill.sh` | El pipeline de activación incluye SKILL FILTER y las métricas de tokens evitados |
| `test_capability_matrix_schema.sh` | `config/capability-matrix.yaml` tiene 17 dominios × 8 versiones con status dentro del enum |
| `test_capability_matrix_registry_consistency.sh` | `docs/CAPABILITY_MATRIX.md` refleja los mismos dominios que `config/capability-matrix.yaml` |

## Salida

Cada script imprime `[PASS]`/`[FAIL]` por check y termina con exit code 0 (todo pasó) o 1 (al menos un fallo). `run-all.sh` agrega los resultados y falla si cualquier script falla.
