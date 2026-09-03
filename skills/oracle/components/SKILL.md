---
name: components
display_name: "Database Components"
id: oracle/components
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar el estado de los componentes de base de datos registrados (`DBA_REGISTRY`): `VALID`/`INVALID`/`OPTION OFF`, y su versión, para detectar componentes en mal estado tras un upgrade o instalación parcial.

# Scope

**En alcance:** estado y versión de cada componente registrado. **Fuera de alcance:** el contenido/funcionalidad interna de cada componente (ej. no evalúa Spatial internals, Text internals, etc.).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (registro compartido). NON-CDB y CDB (`CDB_REGISTRY` desde 12c; cada PDB puede tener su propio estado de componente). ASM y Filesystem (no relevante). Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-COMPONENTS-001`

# Optional evidence

Ninguna.

# Data collection

`DBA_REGISTRY` (`COMP_ID`, `COMP_NAME`, `VERSION`, `STATUS`).

# Diagnostic logic / Decision tree

```text
Para cada componente:
  IF status = 'INVALID' → finding HIGH
  IF status = 'UPGRADED'|'DEGRADED' → finding MEDIUM (estado transitorio esperado sólo durante un upgrade activo;
     fuera de esa ventana, es anómalo)
  IF version del componente no coincide con la versión de la base (oracle_version del Target Profile)
     → finding MEDIUM (componente desalineado, típico de un upgrade incompleto)
```

# Normal behavior

Todos los componentes instalados en `VALID`, con versión coincidente con la versión de la base de datos.

# Abnormal patterns

Componente `INVALID` (indica que su instalación/upgrade falló o quedó incompleta); componente con versión desalineada respecto a la base.

# Root cause patterns

Componente `INVALID` correlacionado con un upgrade reciente reportado por el DBA (vía `constraints`) — causa probable: el script de upgrade de ese componente específico falló o no se ejecutó completo (`catupgrd.sql`/`dbupgrade` equivalente según versión).

# Correlation rules

Cruzar con `oracle/invalid-objects` (un componente `INVALID` casi siempre implica objetos inválidos de sus schemas asociados).

# False positives

`STATUS = 'OPTION OFF'` no es un finding — indica que la feature simplemente no está en uso, no que esté rota.

# Confidence model

`FACT` — lectura directa sin ambigüedad.

# Findings

```yaml
finding_id: FND-...
category: components
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT
impact: string
recommendations: [REC-...]
```

# Recommendations

Re-ejecutar el script de upgrade/instalación del componente afectado, o consultar el log de upgrade correspondiente — `manual_execution_required: true`, sin comando específico generado automáticamente (los scripts de upgrade de componentes son largos y provistos por Oracle, no se reconstruyen aquí).

# DBA commands / prechecks / rollback / postchecks

NOT_APPLICABLE — la remediación de un componente inválido normalmente requiere el script de upgrade oficial de Oracle para esa versión/componente, no un comando SQL simple generable por este skill; se recomienda consultar la documentación/MOS correspondiente (ver `policies/licensing-awareness-policy.md#prioridad-de-fuentes`).

# Version differences

El conjunto de componentes registrados varía significativamente por versión y por opciones instaladas — este skill no asume una lista fija, reporta lo que `DBA_REGISTRY` efectivamente expone.

# RAC considerations

Ninguna — el registro de componentes es compartido, idéntico desde cualquier instancia.

# Multitenant considerations

Desde 12c, `CDB_REGISTRY` permite ver el estado por PDB — un componente puede estar `VALID` en CDB$ROOT pero `INVALID` en un PDB específico tras un plug-in incompleto; este skill lo reporta si el análisis está acotado a ese PDB.

# Standby considerations

Idéntico al primary (el registro se replica vía redo apply).

# Security

Read-only, `SELECT` sobre `DBA_REGISTRY`/`CDB_REGISTRY`.

# Licensing

No depende de ninguna feature licenciada — de hecho, un componente `OPTION OFF` es información útil para licensing-awareness (confirma que una feature no está en uso).

# Related skills

`oracle/invalid-objects`, `oracle/objects`.

# Escalation

Componente `INVALID` en un componente crítico (ej. `CATALOG`, `CATPROC`) escala a `incident-root-cause-analyst` inmediatamente — es una señal de alta severidad.

# Examples

Ver `tests/fixtures/12c-cdb-pdb.yaml` (componente `XDB` en `INVALID` tras un plug-in de PDB incompleto).

# Data sensitivity / Context budget

Sensibilidad BAJA; presupuesto muy bajo.

# Tests

`tests/test_oracle_core_components.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
