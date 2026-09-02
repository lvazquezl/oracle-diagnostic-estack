# Agent Registry

18/18 agentes obligatorios (sección 7 del prompt maestro), todos `status: active`, versión `1.0.0`, conformes al [Agent Contract](../docs/CONTRACTS.md#agent-contract).

| id | Dominio | Manifest |
|---|---|---|
| `oracle-operations-orchestrator` | Orquestación | [agents/oracle-operations-orchestrator.md](oracle-operations-orchestrator.md) |
| `oracle-discovery-analyst` | Discovery/identidad | [agents/oracle-discovery-analyst.md](oracle-discovery-analyst.md) |
| `oracle-dba-analyst` | Estado general Oracle | [agents/oracle-dba-analyst.md](oracle-dba-analyst.md) |
| `oracle-performance-analyst` | AWR/ASH/ADDM/performance | [agents/oracle-performance-analyst.md](oracle-performance-analyst.md) |
| `oracle-rac-analyst` | RAC/GI/Cache Fusion | [agents/oracle-rac-analyst.md](oracle-rac-analyst.md) |
| `oracle-asm-storage-analyst` | ASM/almacenamiento | [agents/oracle-asm-storage-analyst.md](oracle-asm-storage-analyst.md) |
| `oracle-dataguard-analyst` | Data Guard | [agents/oracle-dataguard-analyst.md](oracle-dataguard-analyst.md) |
| `oracle-multitenant-analyst` | CDB/PDB | [agents/oracle-multitenant-analyst.md](oracle-multitenant-analyst.md) |
| `oracle-backup-recovery-analyst` | RMAN/backup | [agents/oracle-backup-recovery-analyst.md](oracle-backup-recovery-analyst.md) |
| `oracle-network-analyst` | TNS/listener/red | [agents/oracle-network-analyst.md](oracle-network-analyst.md) |
| `oracle-security-analyst` | Postura de seguridad | [agents/oracle-security-analyst.md](oracle-security-analyst.md) |
| `os-platform-analyst` | OS multiplataforma | [agents/os-platform-analyst.md](os-platform-analyst.md) |
| `capacity-analyst` | Capacity management | [agents/capacity-analyst.md](capacity-analyst.md) |
| `incident-root-cause-analyst` | RCA/correlación | [agents/incident-root-cause-analyst.md](incident-root-cause-analyst.md) |
| `change-advisor` | Propuestas de cambio | [agents/change-advisor.md](change-advisor.md) |
| `technical-documentation-manager` | Documentación/entregables | [agents/technical-documentation-manager.md](technical-documentation-manager.md) |
| `knowledge-curator` | Curaduría de conocimiento | [agents/knowledge-curator.md](knowledge-curator.md) |
| `estack-evolution-architect` | `/change` governance | [agents/estack-evolution-architect.md](estack-evolution-architect.md) |

Template para nuevos agentes: [`_AGENT_CONTRACT_TEMPLATE.md`](_AGENT_CONTRACT_TEMPLATE.md). Todo agente nuevo entra como `status: candidate` vía `/change agent` y sólo pasa a `active` tras HUMAN REVIEW (ver [EVOLUTION.md](../EVOLUTION.md)).

## Principio de activación

> AGENTS FOR DOMAINS. SKILLS FOR TASKS.

No existe (ni debe crearse) un agente por error o actividad puntual — el detalle de tareas vive en `skills/`. Ver activación mínima por workflow en `workflows/*.md#minimum-agents`.
