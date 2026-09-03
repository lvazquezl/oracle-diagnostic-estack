---
name: processes
display_name: "Processes Summary"
id: oracle/processes
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar el resumen de procesos del lado Oracle (`V$PROCESS`) vs. el límite configurado (`processes`), detectando saturación inminente o procesos huérfanos evidentes desde el diccionario.

# Scope

**En alcance:** conteo de procesos vs. límite, tipos de proceso (background vs. foreground/servidor). **Fuera de alcance:** procesos a nivel OS (eso es `os-platform-analyst`, no profundizado en Fase 2), correlación PID↔proceso OS.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas — `V$PROCESS` es igual en todas las plataformas aunque el modelo de proceso subyacente difiera (procesos separados en Unix/Linux vs. threads en Windows); este skill no asume una cosa u otra, sólo reporta lo que `V$PROCESS` expone.

# Supported architectures

Standalone y RAC (por instancia). NON-CDB y CDB. ASM y Filesystem. Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-PROCESSES-SUMMARY-001`

# Optional evidence

Ninguna.

# Data collection

`V$PROCESS` agregado (conteo total, agrupado por si tiene `V$SESSION` asociada — background vs. foreground); parámetro `processes` (vía `oracle/parameters`, reutilizado por referencia, no re-consultado).

# Diagnostic logic / Decision tree

```text
used_pct = count(V$PROCESS) / processes_parameter
IF used_pct >= 90% → finding HIGH
ELIF used_pct >= 75% → finding MEDIUM
```

# Normal behavior

`used_pct` con margen razonable; conteo de procesos background estable (proporcional a la configuración de la instancia: PMON, SMON, LGWR, DBWn, etc., más los específicos de features habilitadas).

# Abnormal patterns

`used_pct` sostenidamente alto; crecimiento del conteo de procesos foreground sin correlato de sesiones proporcional (posible desalineación, señal para revisión más profunda en fases futuras).

# Root cause patterns

`ORA-00020` (maximum number of processes exceeded) correlacionado con `used_pct` cercano a 100% en la captura previa — causa directa.

# Correlation rules

Cruzar con `oracle/sessions` (el conteo de procesos foreground debe ser proporcional al de sesiones activas) y con `oracle/resource-limits`.

# False positives

Un pico de procesos background durante el arranque de una feature (ej. parallel query recién habilitado) no es un finding aislado si el `used_pct` resultante sigue con margen.

# Confidence model

`FACT` para conteos leídos directamente.

# Findings

```yaml
finding_id: FND-...
category: processes
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT
impact: string
recommendations: [REC-...]
```

# Recommendations

Ampliar el parámetro `processes` (y typically `sessions` proporcionalmente) — `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar impacto de memoria (cada proceso reserva PGA/overhead); requiere restart (SCOPE=SPFILE)
command:    ALTER SYSTEM SET processes=<n> SCOPE=SPFILE;
expected_result: mayor margen antes de ORA-00020
rollback:   ALTER SYSTEM SET processes=<valor_anterior> SCOPE=SPFILE;
postcheck:  Q-ORA-PROCESSES-SUMMARY-001 re-ejecutada confirma margen esperado
```

# Version differences

Sin diferencias estructurales relevantes 10g–23ai (el conjunto de procesos background varía por feature habilitada, no por versión per se).

# RAC considerations

Cada instancia tiene su propio límite `processes` y su propio conteo — nunca se suman entre instancias como si fuera un solo límite.

# Multitenant considerations

Los procesos son a nivel de instancia física (CDB) — no varían por PDB.

# Standby considerations

Un Physical Standby tiene procesos adicionales relacionados con apply (MRP, etc.) — este skill los cuenta igual dentro del total, sin necesidad de distinguirlos en Fase 2 (la distinción detallada de procesos de Data Guard pertenece a `oracle-dataguard-analyst`, fases futuras).

# Security

Read-only, `SELECT` sobre `V$PROCESS`.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/sessions`, `oracle/resource-limits`, `oracle/parameters`.

# Escalation

Saturación de procesos correlacionada con un incidente reportado escala a `incident-root-cause-analyst`.

# Examples

Ver `tests/fixtures/19c-rac-cdb.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto bajo.

# Tests

`tests/test_oracle_core_processes.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
