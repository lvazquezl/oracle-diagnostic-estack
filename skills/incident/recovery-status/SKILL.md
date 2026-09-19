---
name: recovery-status
id: incident/recovery-status
version: 1.0.0
domain: incident
status: active
---

# Purpose

Normaliza el estado de recuperación (`RECOVERED|PARTIALLY_RECOVERED|STABLE_WITH_RISK|
NOT_RECOVERED|UNKNOWN`, `# 748`-`# 758` del prompt de Fase 11) y separa estrictamente `cause` de
`mitigation` de `recovery` (`# 1656`-`# 1667`) — una acción que restauró el servicio no prueba
necesariamente la causa raíz.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/timeline` ejecutado.

# Required evidence

- Eventos de `RECOVERY` en el timeline, estado actual del recurso afectado.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local.

# Forbidden operations

Nunca infiere root cause a partir de qué acción restauró el servicio (ver
`incident/root-cause#recovery-action-not-root-cause`).

## Recovery action ≠ root cause

Ejemplo del propio prompt (`# 1687`-`# 1699`): "restart listener restored service" no implica
"listener process hang was root cause" sin evidencia directa del mecanismo de falla. Este skill
reporta el `recovery_status` y qué acción se tomó, pero la atribución causal es exclusiva de
`incident/root-cause`.

## Mitigation vs. fix

Modelar (`# 1670`-`# 1683` del prompt): `MITIGATION` (alivia el síntoma temporalmente),
`TEMPORARY_FIX` (resuelve el síntoma sin atacar la causa), `PERMANENT_FIX` (resuelve la causa
confirmada), `WORKAROUND` (evita el síntoma sin resolverlo) — nunca mezclados en una sola
categoría.

# Decision logic

1. Determinar `recovery_status` desde evidencia directa del estado actual del recurso — nunca
   asumido `RECOVERED` sólo porque cesaron las alertas (podría ser `STABLE_WITH_RISK` si la
   causa raíz sigue presente sin confirmación de remediación).
2. Clasificar cada acción tomada (si fue reportada por el DBA) según el modelo
   `MITIGATION|TEMPORARY_FIX|PERMANENT_FIX|WORKAROUND` — nunca asumir `PERMANENT_FIX` sin
   confirmación de que la causa raíz fue atendida.

# Normal state

`recovery_status: RECOVERED` con evidencia directa de estabilidad sostenida post-incidente.

# Abnormal patterns

`STABLE_WITH_RISK`: el síntoma cesó pero la causa raíz no fue confirmada/atendida — reportado
explícitamente, nunca presentado como `RECOVERED` completo.

# False positives

Declarar `RECOVERED` sólo porque las alertas cesaron, sin verificar que la causa subyacente fue
atendida, es el falso positivo que este skill evita.

# Correlation rules

Consume `incident/timeline`. Alimenta `incident/root-cause` (nunca al revés — recovery no
determina causa), `incident/rca-report`.

# Confidence model

`FACT` para el estado observado directamente; `UNKNOWN` sin evidencia suficiente de seguimiento
post-incidente.

# Severity

N/A directa.

# Output schema

```yaml
recovery_status: RECOVERED|PARTIALLY_RECOVERED|STABLE_WITH_RISK|NOT_RECOVERED|UNKNOWN
mitigation_fix_model:
  - action_summary: string
    kind: MITIGATION|TEMPORARY_FIX|PERMANENT_FIX|WORKAROUND
    evidence_ids: [EVD-...]
```

# Related skills

`incident/root-cause`, `incident/impact-analysis`, `incident/post-incident-review`.

# Escalation

`STABLE_WITH_RISK`/`NOT_RECOVERED` sostenido escala como hallazgo `HIGH` para seguimiento
continuo.

# Manual remediation guidance

`manual_action` puede recomendar una `PERMANENT_FIX` pendiente cuando sólo se aplicó una
`MITIGATION`/`WORKAROUND` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_recovery_status.sh`, `tests/test_recovery_action_not_root_cause.sh`.

# Documentation requirements

Alimenta `incident-impact.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
