---
name: diagnostics
display_name: "Basic Diagnostic State"
id: oracle/diagnostics
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Consolidar existencia y errores recientes del ADR/alert log a nivel metadata (¿hay incidentes ADR abiertos? ¿el alert log tiene errores `ORA-*` en la ventana reciente?) — sin análisis profundo de trace files ni de la causa de cada error individual.

# Scope

**En alcance:** existencia/tamaño del ADR home, conteo de incidentes ADR abiertos, presencia de errores `ORA-*` en el alert log dentro de una ventana reciente acotada. **Fuera de alcance:** contenido completo de trace files, análisis profundo de cada incidente (eso pertenece a `incident-root-cause-analyst` cuando se le asigna un síntoma específico).

# Supported Oracle versions

11g–23ai para ADR completo (`V$DIAG_INFO`, `ADR_HOME`); en 10g no existe ADR — se degrada a metadata de alert log únicamente si el collector certificado lo soporta como archivo (fuera del diccionario SQL, ver Data collection).

# Supported OS/platforms

Todas — la ruta del ADR/alert log difiere por convención de plataforma; el collector certificado la resuelve, este skill no asume una ruta fija.

# Supported architectures

Standalone y RAC (ADR por instancia). NON-CDB y CDB. ASM y Filesystem (no relevante). Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-DIAGNOSTICS-ADR-001` (11g+, vía `V$DIAG_INFO`/`DBA_OUTSTANDING_ALERTS`)

# Optional evidence

- `Q-ORA-DIAGNOSTICS-ALERTLOG-001` (extracto acotado de alert log reciente, sólo si el collector de archivo está certificado para esa plataforma; ver `collectors/README.md`)

# Data collection

`V$DIAG_INFO` (ubicación de ADR home), `DBA_OUTSTANDING_ALERTS`/`V$DIAG_ALERT_EXT` (11g+, incidentes/alertas activos), y — condicionalmente — un extracto de las últimas N líneas del alert log vía collector de archivo certificado (ventana de tiempo acotada, nunca el archivo completo).

# Diagnostic logic / Decision tree

```text
IF hay incidentes ADR abiertos (DBA_OUTSTANDING_ALERTS con MESSAGE_TYPE indicando error crítico)
   → finding HIGH por cada incidente crítico
IF el extracto de alert log reciente contiene ORA-600/ORA-7445/ORA-4031 → finding HIGH
   (errores internos serios, siempre ameritan atención)
IF contiene otros ORA-* recurrentes en la ventana → finding MEDIUM
IF 10g sin ADR y sin collector de archivo certificado para esa plataforma → capability_status: UNSUPPORTED
   para este skill específicamente en ese ambiente
```

# Normal behavior

Sin incidentes ADR abiertos; alert log reciente sin errores `ORA-*` inesperados (mensajes informativos de checkpoint/log switch son normales, no se reportan como finding).

# Abnormal patterns

Incidente ADR abierto sin resolver; `ORA-600`/`ORA-7445` (errores internos) en el alert log reciente — siempre significativos, incluso uno solo.

# Root cause patterns

Un `ORA-4031` (unable to allocate shared memory) en el alert log correlacionado con presión de shared pool — señal para escalar a `oracle-performance-analyst` (Fase 3) para el análisis de memoria detallado; este skill sólo detecta y reporta el error, no diagnostica la causa de memoria en profundidad.

# Correlation rules

Cruzar con `oracle/instance` (¿coincide el error con un restart?) y con `oracle/jobs` (¿coincide con la ejecución de un job específico?).

# False positives

Mensajes informativos rutinarios del alert log (checkpoints, log switches, `ALTER SYSTEM` ejecutados intencionalmente y declarados por el DBA) no son findings.

# Confidence model

`FACT` para la presencia de un incidente/error específico. `HYPOTHESIS` para cualquier atribución de causa que este skill no está diseñado para confirmar en profundidad (eso es `incident-root-cause-analyst`).

# Findings

```yaml
finding_id: FND-...
category: diagnostics
severity: MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT
impact: string
recommendations: [REC-...]
```

# Recommendations

Para `ORA-600`/`ORA-7445`: recomendar apertura de SR con Oracle Support (nunca se inventa una causa ni un MOS Note — ver `policies/licensing-awareness-policy.md#prohibiciones-explícitas`) — `manual_execution_required: true` en el sentido de que la acción es del DBA/soporte, no del e-stack.

# DBA commands / prechecks / rollback / postchecks

NOT_APPLICABLE — este skill nunca genera un comando de remediación; errores internos (`ORA-600` etc.) requieren investigación por Oracle Support, no un comando SQL.

# Version differences

ADR completo desde 11g. En 10g, sólo alert log tradicional (sin `V$DIAG_INFO`), degradación explícita — ver Diagnostic logic.

# RAC considerations

Cada instancia tiene su propio ADR home — este skill reporta por instancia, nunca mezcla incidentes de distintas instancias como si fueran uno solo.

# Multitenant considerations

El alert log es a nivel de instancia física (CDB); desde 12c hay además un PDB alert log separado por contenedor en algunas configuraciones — este skill reporta lo que el collector certificado exponga, declarando explícitamente el alcance.

# Standby considerations

Aplica igual — errores en el proceso de apply (MRP) aparecerían en el alert log del standby, aunque este skill no los interpreta en profundidad (eso es `oracle-dataguard-analyst`, fases futuras).

# Security

Read-only. El extracto de alert log pasa por sanitización antes de llegar al modelo (hostnames, nombres de schema/objeto en mensajes de error se enmascaran según política) — nunca se envía el archivo completo.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/instance`, `oracle/jobs`.

# Escalation

`ORA-600`/`ORA-7445` o cualquier incidente ADR crítico escala inmediatamente a `incident-root-cause-analyst`.

# Examples

Ver `tests/fixtures/19c-standalone-cdb.yaml` (un `ORA-4031` en la ventana de las últimas 24h).

# Data sensitivity / Context budget

Sensibilidad MEDIA-ALTA (el alert log puede contener nombres de schema/objeto e incluso fragmentos de contexto de aplicación en mensajes de error) — sanitización estricta obligatoria; presupuesto medio (extracto acotado, nunca el archivo completo).

# Tests

`tests/test_oracle_core_diagnostics.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
