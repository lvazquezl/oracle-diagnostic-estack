# CLAUDE.md — oracle-diagnostic-estack

## Misión

Este e-stack asiste a DBAs Oracle y SysAdmins en **assessment, health checks, observabilidad, análisis, troubleshooting, root cause analysis y capacity management** sobre Oracle Database (10g→23ai, Standalone/RAC/CDB-PDB/ASM/Data Guard) y los OS que lo hospedan (Linux, RHEL, SUSE, Solaris, AIX, Windows Server, HP-UX).

## READ-ONLY ALWAYS. HUMAN EXECUTION ONLY.

- Este stack **nunca** ejecuta DML/DDL, `srvctl`/`crsctl` de cambio, `systemctl start/stop/restart`, operaciones ASM, switchover/failover, restore/recover, ni shell arbitrario.
- Toda remediación se entrega como **texto/procedimiento** para ejecución manual del DBA (ver [`change-advisor`](../agents/change-advisor.md)).
- No existen herramientas MCP de escritura. Ver [SECURITY.md](SECURITY.md) y [policies/forbidden-operations.md](policies/forbidden-operations.md).

## Routing

1. Toda solicitud entra por [`oracle-operations-orchestrator`](agents/oracle-operations-orchestrator.md).
2. El orquestador ejecuta primero [`oracle-discovery-analyst`](agents/oracle-discovery-analyst.md) si no hay contexto de ambiente cacheado (versión, topología, rol, OS).
3. **Capability Filter**: antes de activar nada, se cruza el discovery contra [config/capability-matrix.yaml](config/capability-matrix.yaml) y los `gates:` del workflow — un agente/skill ya incompatible con la versión/arquitectura no se activa (ver [docs/CONTRACTS.md#pipeline-de-activación-foundation-hardening](docs/CONTRACTS.md#pipeline-de-activación-foundation-hardening)).
4. El orquestador activa el **mínimo** número de agentes especialistas necesarios (ver [docs/CONTRACTS.md](docs/CONTRACTS.md#workflow-contract)) y les entrega un Task Package, no la conversación completa.
5. Los especialistas devuelven un Result Package con evidence refs, no evidencia cruda repetida. Toda capability que no se ejecutó tal como se pidió devuelve un `capability_status` explícito, nunca un fallo silencioso (ver [docs/CONTRACTS.md#capability-status-model](docs/CONTRACTS.md#capability-status-model)).
6. `technical-documentation-manager` registra automáticamente cada análisis en `analysis/ANA-*`.
7. `change-advisor` convierte recomendaciones aprobadas en propuestas de cambio para ejecución humana.

## Carga de agentes y skills

- Los manifests de agentes viven en `agents/*.md` y siguen el **Agent Contract** ([docs/CONTRACTS.md](docs/CONTRACTS.md#agent-contract)).
- Los skills viven en `skills/<dominio>/*.md` y siguen el **Skill Contract** ([docs/CONTRACTS.md](docs/CONTRACTS.md#skill-contract)). El índice completo está en [skills/REGISTRY.md](skills/REGISTRY.md). Todo skill se referencia **siempre** por su `skill_id` completo (`dominio/skill`) — nunca por un nombre corto suelto.
- Un agente sólo puede invocar skills listados en su `allowed_skills`. Un skill sólo puede usar queries certificadas en `queries/` (Query Contract v2 — ver [docs/CONTRACTS.md](docs/CONTRACTS.md#query-contract-v2-foundation-hardening)).

## Minimización de contexto

> MULTI-AGENT DOES NOT MEAN MULTI-CONTEXT.

- Task Package / Result Package obligatorios entre orquestador y especialistas (ver [docs/CONTRACTS.md](docs/CONTRACTS.md#context-token-model)).
- Evidencia por referencia (`EVD-*`), nunca duplicada en el prompt.
- Cache de discovery y de evidencia por sesión/target.
- Presupuesto de tokens por agente/skill declarado en cada contrato.

## Política de evidencia

`RAW DATA → PARSER LOCAL → FILTER → AGGREGATION → REDACTION/TOKENIZATION → SANITIZED EVIDENCE → MODELO`

- El modelo trabaja con `evidence/sanitized` y `evidence/derived`. `evidence/raw` no se modifica ni se envía completo al modelo.
- Clasificación de campos: KEEP / MASK / HASH / TOKENIZE / DROP (ver [sanitizers/data-classification-policy.md](sanitizers/data-classification-policy.md)).
- Trazabilidad obligatoria: `EVIDENCE → FINDING → RECOMMENDATION → CHANGE PROPOSAL` con IDs estables (`EVD-`, `FND-`, `REC-`, `CHG-`, `ANA-`, `INC-`).

## Operaciones prohibidas

Ver lista completa en [policies/forbidden-operations.md](policies/forbidden-operations.md). Resumen: cualquier verbo de escritura sobre Oracle/GI/ASM/OS/red/almacenamiento, SQL/shell arbitrario, credenciales privilegiadas, acceso a datos de aplicación o bind values, envío de secretos al modelo.

## Documentación

> ANALYZE ONCE, DOCUMENT MANY. NO ANALYSIS WITHOUT EVIDENCE RECORD.

Todo análisis genera automáticamente `analysis/ANA-YYYYMMDD-NNN/` en Markdown. Entregables binarios (DOCX/XLSX/PDF/PPTX) sólo bajo demanda vía `/document`, derivados del Markdown existente (ver [docs/CONTRACTS.md](docs/CONTRACTS.md), `technical-documentation-manager`).

## `/change`

Todo crecimiento del stack (agente, skill, query, workflow, policy, knowledge, compatibility, documentation, security) pasa por el flujo gobernado en [EVOLUTION.md](EVOLUTION.md): DETECT GAP → CHANGE REQUEST → GAP/IMPACT ANALYSIS → PROPOSAL → IMPLEMENT → TEST → SECURITY VALIDATION → REGRESSION VALIDATION → DOCUMENT → HUMAN REVIEW → PROMOTE. Ninguna capacidad crítica se promueve sin revisión humana.

## Referencias

- Arquitectura: [ARCHITECTURE.md](ARCHITECTURE.md)
- Seguridad: [SECURITY.md](SECURITY.md)
- Evolución/`/change`: [EVOLUTION.md](EVOLUTION.md)
- Distribución: [DISTRIBUTION.md](DISTRIBUTION.md)
- Contratos definitivos (Agent/Skill/Workflow/Query v2): [docs/CONTRACTS.md](docs/CONTRACTS.md)
- Registro de agentes: [agents/REGISTRY.md](agents/REGISTRY.md)
- Registro de skills: [skills/REGISTRY.md](skills/REGISTRY.md)
- Catálogo de queries certificadas: [queries/REGISTRY.md](queries/REGISTRY.md)
- Cobertura por dominio × versión: [docs/CAPABILITY_MATRIX.md](docs/CAPABILITY_MATRIX.md)
- Costo/riesgo, degradación de capacidades, licensing, version-awareness: [policies/query-cost-policy.md](policies/query-cost-policy.md), [policies/capability-degradation-policy.md](policies/capability-degradation-policy.md), [policies/licensing-awareness-policy.md](policies/licensing-awareness-policy.md), [policies/version-awareness-policy.md](policies/version-awareness-policy.md)
