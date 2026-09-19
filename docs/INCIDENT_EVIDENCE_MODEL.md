# Incident Evidence Model — Fase 11

## Evidencia por referencia

`incident-root-cause-analyst` nunca duplica collectors — consume `evidence_refs` (`EVD-*`) ya
producidos por los 10 especialistas previos (`oracle-dba-analyst`, `oracle-performance-analyst`,
`oracle-rac-analyst`, `oracle-asm-storage-analyst`, `oracle-dataguard-analyst`,
`oracle-multitenant-analyst`, `oracle-backup-recovery-analyst`, `oracle-network-analyst`,
`oracle-security-analyst`, `os-platform-analyst`, `capacity-analyst`) a través de los 9 skills de
correlación cross-domain (`incident/performance-correlation` … `incident/multitenant-correlation`).

## Plan de evidencia

`incident/evidence-plan` determina qué evidencia se necesita antes de solicitarla — nunca una
recolección exploratoria sin justificación de hipótesis (mismo criterio de costo que
`policies/query-cost-policy.md`).

## Pipeline de minimización de contexto

```text
raw evidence → local parser → event extraction → dedup → timeline summary → top hypotheses → LLM reasoning
```

Archivos de log completos nunca se envían al modelo — mismo principio que
`CLAUDE.md#política-de-evidencia`.

## Cadena de identificadores

`INC-YYYYMMDD-NNN → EVD-... → FND-... → HYP-... → RCA-... → REC-... → CHG-...` — trazabilidad
obligatoria, mismo patrón que el resto del e-stack (`CLAUDE.md#documentación`).

## Correlación de evidencia

`incident/evidence-correlation` (v2.0.0, fusiona `skills/incident/root-cause-analysis.md`
Foundation) vincula evidencia de múltiples fuentes al mismo síntoma/hipótesis — nunca declara
correlación sin al menos dos referencias de evidencia independientes o una relación temporal
explícitamente verificada.

## No-secrets / no-business-data

Hereda estrictamente `sanitizers/data-classification-policy.md` — nunca passwords, hashes, wallet
secrets, private keys, SQL text sensible completo, bind values, datos de negocio, identificadores
crudos de clientes (`# 63` del prompt de Fase 11).

## Referencias

`skills/incident/evidence-plan/SKILL.md`, `skills/incident/evidence-correlation/SKILL.md`,
`skills/incident/known-error-correlation/SKILL.md`, `docs/INCIDENT_READONLY_SECURITY_MODEL.md`.
