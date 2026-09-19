# Incident Causality Model — Fase 11

## Principio central

> CORRELATION IS NOT CAUSATION.

La proximidad temporal sola nunca es prueba suficiente de causalidad — requiere mecanismo,
evidencia de soporte, y ausencia de una contradicción más fuerte (`# 71`, `# 80` del prompt de
Fase 11).

## Change correlation vs. change caused

`CHANGE_CORRELATED` (coincidencia dentro de una ventana temporal configurable) se distingue
explícitamente de `CHANGE_CAUSED` (evidencia causal directa confirmada) — nunca colapsados en un
único estado (`incident/change-correlation`).

## Symptom / Condition / Contributing Factor / Root Cause / Impact

Separación estricta y nunca colapsada:

- **Symptom**: la manifestación observable (ej. `ORA-12537`).
- **Condition**: el estado del sistema en el momento del síntoma.
- **Contributing Factor**: algo que amplificó/permitió el problema sin ser la causa directa
  (`incident/contributing-factors`, roles `AMPLIFIER|PRECONDITION|LATENT_RISK|RECOVERY_DELAY|
  OBSERVABILITY_GAP`).
- **Root Cause**: el mecanismo confirmado que, de eliminarse, habría evitado el incidente.
- **Impact**: la consecuencia observada (`incident/impact-analysis`).

Ejemplo verbatim del prompt: `ORA-12537` nunca es automáticamente root cause — es symptom
(`# 40`-`# 47` del prompt de Fase 11).

## Recovery action ≠ root cause

Una acción que restauró el servicio (ej. "restart listener restored service") no prueba por sí
misma la causa raíz — requiere evidencia directa del mecanismo de falla, nunca inferida
únicamente de qué acción funcionó (`incident/recovery-status#recovery-action-not-root-cause`,
`# 1687`-`# 1699` del prompt).

## Capacity forecast ≠ past cause

Un forecast de capacidad futuro nunca se usa como prueba de causa de un incidente ya ocurrido,
salvo evidencia histórica/actual directa que confirme saturación en el momento del incidente
(`incident/capacity-correlation`, `# 1609`-`# 1620` del prompt).

## Causal chain

Toda declaración de root cause requiere una cadena causal explícita, nunca un salto directo de
alerta a causa raíz — ejemplo del propio prompt: "network path instability → RAC interconnect
packet loss → cluster communication degradation → node eviction → service disruption"
(`# 1560`-`# 1575` del prompt). Cada eslabón requiere su propia evidencia.

## Referencias

`skills/incident/root-cause/SKILL.md`, `skills/incident/change-correlation/SKILL.md`,
`skills/incident/recovery-status/SKILL.md`, `skills/incident/capacity-correlation/SKILL.md`,
`skills/incident/rac-correlation/SKILL.md`, `docs/INCIDENT_ROOT_CAUSE_MODEL.md`.
