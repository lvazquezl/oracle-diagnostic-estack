---
name: objects
display_name: "Objects Inventory"
id: oracle/objects
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Producir un inventario agregado de objetos por tipo/schema (metadata: conteos, no contenido) para dar contexto de tamaño/complejidad del esquema y detectar anomalías estructurales evidentes (ej. crecimiento anómalo de un tipo de objeto).

# Scope

**En alcance:** conteos agregados por `OWNER`/`OBJECT_TYPE`/`STATUS` desde `DBA_OBJECTS`. **Fuera de alcance:** contenido de los objetos (filas, definiciones completas de vistas/procedimientos con lógica de negocio), objetos inválidos en detalle (eso es `oracle/invalid-objects`, skill propio).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (metadata idéntica desde cualquier instancia). NON-CDB y CDB (`CDB_OBJECTS` desde 12c para vista consolidada, o `DBA_OBJECTS` por contenedor). ASM y Filesystem (no relevante). Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-OBJECTS-INVENTORY-001`

# Optional evidence

Ninguna.

# Data collection

`DBA_OBJECTS` agregado: `COUNT(*) GROUP BY OWNER, OBJECT_TYPE, STATUS` — nunca el nombre completo de cada objeto individual salvo que sea necesario para un finding específico (ej. el objeto inválido concreto, cubierto por `oracle/invalid-objects`).

# Diagnostic logic / Decision tree

```text
Reporte principalmente informativo (inventario). Findings surgen de comparación temporal si hay evidencia
histórica disponible (capacity/growth, fases futuras) o de umbrales absolutos configurables:
IF un schema de aplicación tiene un conteo de objetos MUY por encima de lo típico para su tipo declarado
   → finding LOW (informativo, útil para capacity/assessment, no indica problema por sí solo)
```

# Normal behavior

Distribución de objetos consistente con la arquitectura declarada de la aplicación (si se conoce) o sin cambios abruptos respecto a un inventario previo (si existe).

# Abnormal patterns

Un schema con miles de objetos de tipo `TABLE PARTITION` inesperados (posible partición automática descontrolada); crecimiento repentino en un tipo de objeto específico entre dos análisis consecutivos.

# Root cause patterns

NOT_APPLICABLE en Fase 2 — este skill es principalmente de inventario; correlación de causa raíz sobre crecimiento de objetos requiere series de tiempo (`capacity/growth`, no profundizado aún para este dominio específico).

# Correlation rules

Cruzar con `oracle/invalid-objects` (¿el crecimiento incluye objetos inválidos?) y con `oracle/components` (¿coincide con una instalación/upgrade de componente?).

# False positives

Un aumento de objetos coincidente con un deployment de aplicación declarado por el DBA no es una anomalía.

# Confidence model

`FACT` — son conteos directos sin interpretación ambigua.

# Findings

```yaml
finding_id: FND-...
category: objects
severity: LOW
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT
impact: string
recommendations: []
```

# Recommendations

NOT_APPLICABLE en la mayoría de los casos — este skill es principalmente informativo/de inventario, no genera recomendaciones de cambio.

# DBA commands / prechecks / rollback / postchecks

NOT_APPLICABLE — no hay comando de remediación asociado a un inventario de objetos.

# Version differences

`CDB_OBJECTS` desde 12c. Sin otras diferencias estructurales relevantes.

# RAC considerations

Ninguna — el diccionario de objetos es compartido, idéntico desde cualquier instancia.

# Multitenant considerations

Con CDB, se puede reportar por PDB individual (`CON_ID`) o agregado vía `CDB_OBJECTS` — este skill opera a nivel de la conexión actual por defecto en Fase 2.

# Standby considerations

Idéntico al primary (el diccionario se replica vía redo apply) — no hay diferencia de interpretación relevante.

# Security

Read-only, `SELECT` sobre `DBA_OBJECTS`/`CDB_OBJECTS`. Nombres de schema/objeto pueden revelar estructura de aplicación — enmascarados según política.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/invalid-objects`, `oracle/components`.

# Escalation

Ninguna especial.

# Examples

Ver `tests/fixtures/12c-cdb-pdb.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (nombres de schema); presupuesto bajo.

# Tests

`tests/test_oracle_core_objects.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
