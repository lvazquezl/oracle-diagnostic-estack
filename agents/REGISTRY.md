# Agent Registry

18/18 agentes obligatorios (sección 7 del prompt maestro), todos `status: active`, conformes al [Agent Contract](../docs/CONTRACTS.md#agent-contract). `oracle-discovery-analyst` y `oracle-dba-analyst` están en `v2.0.0` (Fase 2 — Oracle Core, desarrollo profundo con estructura de carpeta `agents/<id>/AGENT.md`); `oracle-performance-analyst` está en `v4.0.0` (Fase 3 Completion & Portability Hardening — contrato estructurado completo); `oracle-rac-analyst`/`oracle-asm-storage-analyst`/`oracle-network-analyst` están en `v2.0.0` (Fase 4 — RAC/GI/ASM/Network, mismo contrato estructurado completo); `oracle-dataguard-analyst` está en `v2.0.0` (Fase 5 — Data Guard, mismo contrato estructurado completo: `AGENT.md` + `manifest.yaml` + `routing.yaml` + `context-policy.yaml` + `collaboration.yaml` + `output-schema.yaml` + `tests/` + `CHANGELOG.md`); `oracle-multitenant-analyst` está en `v2.0.0` (Fase 6 — Multitenant/CDB/PDB, mismo contrato estructurado completo); `oracle-backup-recovery-analyst` está en `v1.0.0` con estructura de carpeta completa (Fase 7 — Backup & Recovery/RMAN; nunca tuvo un `agents/oracle-backup-recovery-analyst.md` plano real en Foundation — el registro apuntaba a un archivo nunca materializado, corregido en esta fase); `oracle-security-analyst` está en `v2.0.0` con estructura de carpeta completa (Fase 8 — Security & Compliance; a diferencia de RMAN, sí existía un `agents/oracle-security-analyst.md` plano real y materializado desde Foundation — su contenido (responsabilidades, boundaries, evidence policy) se preservó y amplió al deepening, nunca contradicho; el flat file fue eliminado en favor del contrato estructurado); `os-platform-analyst` recibió una extensión ligera en Fase 4 (`v1.1.0`, sin restructurar a carpeta); el resto permanece en `v1.0.0` (Foundation, manifest plano `agents/<id>.md`) hasta que su fase correspondiente los profundice.

| id | Dominio | Manifest |
|---|---|---|
| `oracle-operations-orchestrator` | Orquestación | [agents/oracle-operations-orchestrator.md](oracle-operations-orchestrator.md) |
| `oracle-discovery-analyst` | Discovery/identidad/Target Profile | [agents/oracle-discovery-analyst/AGENT.md](oracle-discovery-analyst/AGENT.md) |
| `oracle-dba-analyst` | Oracle Core (18 áreas) | [agents/oracle-dba-analyst/AGENT.md](oracle-dba-analyst/AGENT.md) |
| `oracle-performance-analyst` | AWR/ASH/ADDM/Statspack/performance | [agents/oracle-performance-analyst/AGENT.md](oracle-performance-analyst/AGENT.md) |
| `oracle-rac-analyst` | RAC/Grid Infrastructure/Cache Fusion | [agents/oracle-rac-analyst/AGENT.md](oracle-rac-analyst/AGENT.md) |
| `oracle-asm-storage-analyst` | ASM/almacenamiento | [agents/oracle-asm-storage-analyst/AGENT.md](oracle-asm-storage-analyst/AGENT.md) |
| `oracle-dataguard-analyst` | Data Guard | [agents/oracle-dataguard-analyst/AGENT.md](oracle-dataguard-analyst/AGENT.md) |
| `oracle-multitenant-analyst` | CDB/PDB | [agents/oracle-multitenant-analyst/AGENT.md](oracle-multitenant-analyst/AGENT.md) |
| `oracle-backup-recovery-analyst` | RMAN/backup | [agents/oracle-backup-recovery-analyst/AGENT.md](oracle-backup-recovery-analyst/AGENT.md) |
| `oracle-network-analyst` | TNS/listener/SCAN/red | [agents/oracle-network-analyst/AGENT.md](oracle-network-analyst/AGENT.md) |
| `oracle-security-analyst` | Postura de seguridad y compliance | [agents/oracle-security-analyst/AGENT.md](oracle-security-analyst/AGENT.md) |
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
