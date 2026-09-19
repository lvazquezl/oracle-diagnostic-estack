# Incident Playbook Model — Fase 11

## Principio

Los playbooks de incidente son **read-only, diagnose-and-recommend only** — nunca ejecutan una
acción de contención/corrección directamente, incluso para escenarios etiquetados "emergencia"
(mismo principio que `incident/manual-remediation-plan`).

## Cobertura mínima (sección 100 del prompt de Fase 11)

- RAC node eviction (`incident/rac-correlation`, `incident/root-cause`)
- Listener/TNS failure (`incident/network-correlation`)
- Data Guard lag/gap (`incident/dataguard-correlation`)
- FRA pressure (`incident/asm-storage-correlation`, `incident/rman-correlation`)
- RMAN backup failure (`incident/rman-correlation`)
- OS memory pressure (`incident/os-correlation`)

## Estructura de un playbook

1. Síntoma reconocido (patrón de error/alerta).
2. Dominios candidatos a activar (skills de correlación cross-domain relevantes).
3. Hipótesis típicas asociadas al patrón, con su evidencia requerida para confirmación.
4. Advertencias de causalidad específicas del patrón (ej. "eviction no implica automáticamente
   causa de red" en el playbook RAC — ver `incident/rac-correlation`).
5. Acciones de remediación manual candidatas, siempre como referencia a
   `incident/manual-remediation-plan` con `execution_status: NOT_EXECUTED`.

## Nunca automatiza

Ningún playbook ejecuta ni siquiera un paso de diagnóstico adicional sin evidencia — cada paso
sigue el mismo Query Contract v2/Evidence Policy que el resto del e-stack, nunca un atajo
"porque es un playbook conocido".

## Referencias

`skills/incident/rac-correlation/SKILL.md`, `skills/incident/network-correlation/SKILL.md`,
`skills/incident/dataguard-correlation/SKILL.md`, `skills/incident/asm-storage-correlation/SKILL.md`,
`skills/incident/rman-correlation/SKILL.md`, `skills/incident/os-correlation/SKILL.md`,
`skills/incident/manual-remediation-plan/SKILL.md`, `docs/INCIDENT_ROOT_CAUSE_MODEL.md`.
