---
name: resource-limits
display_name: "Resource Limits"
id: oracle/resource-limits
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Consolidar el uso vs. límite configurado de recursos de instancia (`processes`, `sessions`, `open_cursors`, y licencia de sesión/usuario si `V$LICENSE` la reporta), como vista agregada única sobre lo que `oracle/sessions`/`oracle/processes` ya evaluaron individualmente, más `open_cursors` que no tiene skill propio.

# Scope

**En alcance:** `processes`, `sessions`, `open_cursors` (uso máximo reciente vs. límite), `V$LICENSE` si expone límites de sesión/usuario configurados por el DBA (no licenciamiento Oracle Corp). **Fuera de alcance:** límites de OS (ulimits, ver `os-platform-analyst`, no profundizado en Fase 2), cuotas de tablespace por usuario (`DBA_TS_QUOTAS`, considerado de menor prioridad diagnóstica, `registered` no materializado en Fase 2).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB. ASM y Filesystem (no relevante). Primary y Physical Standby.

# Prerequisites

Target Profile publicado. Reutiliza evidencia de `oracle/sessions`/`oracle/processes` si ya fue recolectada en la misma sesión de análisis (no duplica).

# Required evidence

- `Q-ORA-RESOURCE-LIMITS-001`

# Optional evidence

Ninguna.

# Data collection

`V$RESOURCE_LIMIT` (`RESOURCE_NAME`, `CURRENT_UTILIZATION`, `MAX_UTILIZATION`, `LIMIT_VALUE`) — vista consolidada que Oracle ya expone para exactamente este propósito.

# Diagnostic logic / Decision tree

```text
Para cada resource_name relevante (processes, sessions, open_cursors, ...):
  IF limit_value != 'UNLIMITED' AND max_utilization / limit_value >= 90% → finding HIGH
  ELIF max_utilization / limit_value >= 75% → finding MEDIUM
```

`max_utilization` es el pico histórico desde el último restart — un valor alto no significa que el uso *actual* sea alto, sino que en algún momento estuvo cerca del límite; el finding lo declara explícitamente como pico histórico, no como estado actual.

# Normal behavior

`max_utilization` con margen razonable respecto a `limit_value` para todos los recursos monitoreados.

# Abnormal patterns

`max_utilization` muy cercano a `limit_value` (indica que en algún momento el sistema estuvo a punto de rechazar conexiones/cursores).

# Root cause patterns

Un `ORA-01000` (maximum open cursors exceeded) reportado por el DBA correlacionado con `open_cursors.max_utilization` cercano al límite — causa directa.

# Correlation rules

Cruzar con `oracle/sessions`/`oracle/processes` (evitar duplicar evidencia — este skill reutiliza `EVD-*` ya recolectado por ellos cuando están en el mismo análisis).

# False positives

Un pico histórico desde hace mucho tiempo (instancia con muchos días de uptime) que ya no representa el patrón actual no es necesariamente urgente — el finding lo declara como histórico, dejando al DBA juzgar relevancia.

# Confidence model

`FACT` — lectura directa de una vista diseñada exactamente para este propósito.

# Findings

```yaml
finding_id: FND-...
category: resource-limits
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT
impact: string
recommendations: [REC-...]
```

# Recommendations

Ampliar el parámetro correspondiente (`processes`, `sessions`, `open_cursors`) si el margen es insuficiente — `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar si el límite requiere restart (processes/sessions, SCOPE=SPFILE) o es dinámico
            (open_cursors, SCOPE=BOTH)
command:    ALTER SYSTEM SET open_cursors=<n> SCOPE=BOTH;
            -- processes/sessions: ver oracle/processes, oracle/sessions
expected_result: mayor margen entre max_utilization y limit_value en la próxima ventana de observación
rollback:   ALTER SYSTEM SET <parameter>=<valor_anterior> SCOPE=BOTH|SPFILE;
postcheck:  Q-ORA-RESOURCE-LIMITS-001 re-ejecutada en una ventana posterior confirma margen esperado
```

# Version differences

Sin diferencias estructurales relevantes 10g–23ai.

# RAC considerations

`V$RESOURCE_LIMIT` es por instancia — este skill reporta cada instancia individualmente si RAC.

# Multitenant considerations

Los límites de `V$RESOURCE_LIMIT` son a nivel de instancia física, no por PDB.

# Standby considerations

Aplica igual, aunque el patrón de uso en un standby (menos sesiones de usuario salvo Active Data Guard) típicamente muestra picos históricos menores.

# Security

Read-only, `SELECT` sobre `V$RESOURCE_LIMIT`.

# Licensing

`V$LICENSE` (si se incluye) refleja límites de sesión/usuario configurados por el DBA para control interno, no licenciamiento Oracle Corp — este skill nunca lo confunde con `capabilities.*` de licencia de producto.

# Related skills

`oracle/sessions`, `oracle/processes`, `oracle/parameters`.

# Escalation

Un límite alcanzado (`max_utilization = limit_value`) correlacionado con un incidente de rechazo de conexiones escala a `incident-root-cause-analyst`.

# Examples

Ver `tests/fixtures/19c-rac-cdb.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto muy bajo — una sola vista compacta, evidencia frecuentemente reutilizada de `oracle/sessions`/`oracle/processes`.

# Tests

`tests/test_oracle_core_resource_limits.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
