# Incident Manual Remediation Model — Fase 11

## Principio no-negociable

> HUMAN-EXECUTED REMEDIATION ONLY. Incluso para acciones de emergencia.

Reinicio de listener/instancia, relocación de servicio, `ALTER SYSTEM KILL SESSION`, kill de
proceso OS, failover/switchover, extensión de filesystem, cambio de parámetro, cambio de
storage/red/seguridad, ejecución de RMAN — **ninguna** se ejecuta jamás por el e-stack, ni
siquiera en un escenario de incidente activo etiquetado urgente (`# 1054`-`# 1072` del prompt de
Fase 11).

## Formato de cada acción

```yaml
manual_remediation_plan:
  - action_summary: string
    justification: string
    linked_to: RCA-...|HYP-...
    kind: MITIGATION|TEMPORARY_FIX|PERMANENT_FIX|WORKAROUND
    risk: string
    rollback: string|null
    execution_status: NOT_EXECUTED
```

## Trazabilidad obligatoria

Toda acción se vincula explícitamente a la causa/hipótesis que atiende — nunca una acción
huérfana sin justificación causal (mismo patrón que `change-advisor`).

## Relación con `/change`

Si el DBA decide formalizar una acción de remediación como cambio permanente, pasa por el flujo
`/change` gobernado (`EVOLUTION.md`) o por `change-advisor` — el plan de remediación de incidente
nunca sustituye ese flujo, sólo lo alimenta como propuesta.

## Consistencia con el resto del e-stack

Mismo patrón ya establecido por `change-advisor`, `capacity/manual-capacity-plan`,
`os/manual-hardening-plan`, `rman/manual-recovery-plan`, `security/manual-remediation-plan` —
ninguna excepción por tratarse de un incidente.

## Referencias

`skills/incident/manual-remediation-plan/SKILL.md`, `policies/forbidden-operations.md`,
`docs/INCIDENT_READONLY_SECURITY_MODEL.md`.
