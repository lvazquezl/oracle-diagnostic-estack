# Incident Postmortem Model — Fase 11

## Principio

Blameless por diseño — el post-incident review nunca atribuye culpa individual; el foco es
sistémico (proceso, tooling, observabilidad, documentación) (`incident/post-incident-review`,
`# 1076`-`# 1096` del prompt de Fase 11).

## Estructura

```yaml
post_incident_review:
  timeline_summary: string
  what_worked: [string]
  what_did_not_work: [string]
  detection_gaps: [string]
  follow_up_actions:
    - summary: string
      owner_hint: string|null
      status: PROPOSED
```

`follow_up_actions` se proponen como texto para revisión humana — nunca auto-creadas como
tickets/cambios reales.

## Lecciones aprendidas

`incident/lessons-learned` (v2.0.0, fusiona el rol implícito de
`skills/incident/root-cause-analysis.md` Foundation) extrae patrones reutilizables:

```yaml
lessons_learned:
  - summary: string
    category: KNOWLEDGE_GAP|PLAYBOOK_GAP|OBSERVABILITY_GAP|PROCESS_GAP
    proposed_action: string
    status: PROPOSED
```

Nunca se escribe automáticamente en `knowledge/errors/` — la promoción de una lección aprendida
al knowledge base pasa siempre por el flujo `/change` gobernado (`EVOLUTION.md`).

## Recurrencia

`incident/recurrence-awareness` clasifica el incidente como `first_occurrence`/`recurrent`/
`patterned`/`unknown` — `unknown` explícito sin historial disponible, nunca `first_occurrence`
asumido por defecto.

## Reportes generados

`incident/incident-report` (reporte completo del incidente) e `incident/rca-report` (RCA
enfocado, reproducible) — ambos vía `technical-documentation-manager`, registrados
automáticamente en `analysis/ANA-*` (mismo principio "ANALYZE ONCE, DOCUMENT MANY" de
`CLAUDE.md`).

## Referencias

`skills/incident/post-incident-review/SKILL.md`, `skills/incident/lessons-learned/SKILL.md`,
`skills/incident/recurrence-awareness/SKILL.md`, `skills/incident/incident-report/SKILL.md`,
`skills/incident/rca-report/SKILL.md`.
