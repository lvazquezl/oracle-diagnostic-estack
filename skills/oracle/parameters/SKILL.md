---
name: parameters
display_name: "Initialization Parameters"
id: oracle/parameters
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar parámetros de inicialización efectivos (`V$PARAMETER`) contra valores por defecto, mejores prácticas conocidas por versión/rol, y consistencia entre instancias en RAC.

# Scope

**En alcance:** parámetros no-default, parámetros deprecados/obsoletos, parámetros inconsistentes entre instancias RAC, comparación contra rangos razonables conocidos. **Fuera de alcance:** tuning de memoria (SGA/PGA sizing detallado — Fase 3), parámetros ocultos (`_underscore`) salvo que estén documentados como diagnósticamente relevantes y sin efectos secundarios de lectura.

# Supported Oracle versions

10g–23ai. El conjunto de parámetros válidos cambia por versión — nunca se asume que un parámetro existente en 19c existe en 10g o viceversa; `V$PARAMETER` sólo devuelve lo que la versión conectada soporta, por lo que la query es inherentemente segura, pero la *interpretación* de "falta" debe considerar la versión.

# Supported OS/platforms

Todas — algunos parámetros son platform-specific (ej. `use_large_pages` sólo Linux) y se documentan como tal, sin tratarlos como anomalía en plataformas donde no aplican.

# Supported architectures

Standalone y RAC (parámetros pueden diferir intencionalmente entre instancias — ej. `instance_number`, `thread`; y no intencionalmente — ej. `sga_target` distinto sin razón documentada). NON-CDB y CDB (algunos parámetros son sólo modificables a nivel CDB$ROOT desde 12c). ASM y Filesystem. Primary y Physical Standby.

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-ORA-PARAMETERS-001`

# Optional evidence

- `Q-ORA-PARAMETERS-RAC-DIFF-001` (comparación cross-instance, sólo si RAC)

# Data collection

`V$PARAMETER`/`GV$PARAMETER` (`NAME`, `VALUE`, `ISDEFAULT`, `ISMODIFIED`, `ISPDB_MODIFIABLE` desde 12c).

# Diagnostic logic / Decision tree

```text
Para cada parámetro NO default:
  IF parámetro está en la lista de deprecados/obsoletos para la versión detectada → finding MEDIUM
  IF RAC AND el mismo parámetro difiere entre instancias sin estar en la lista de "puede diferir legítimamente"
     (instance_number, thread, undo_tablespace, ...) → finding MEDIUM
  IF parámetro fuera de un rango conocido como razonable (ej. processes muy bajo para el uso real) → finding LOW/MEDIUM
     con nota de correlación pendiente (requiere oracle/resource-limits para confirmar)
```

# Normal behavior

Parámetros no-default documentados y consistentes con la versión/rol; diferencias entre instancias RAC limitadas a las legítimas (`instance_number`, `thread`, `undo_tablespace`, `local_listener` si usa direcciones distintas por nodo).

# Abnormal patterns

Uso de parámetros deprecados que Oracle recomienda no usar en la versión detectada; `sga_target`/`pga_aggregate_target` en cero con `sga_max_size` grande (posible mala migración de configuración manual a automática); `remote_login_passwordfile` en un valor inesperado para el modelo de seguridad esperado (ver `oracle-security-analyst`, no profundizado en Fase 2 pero señalado aquí como observación).

# Root cause patterns

Un parámetro deprecado correlacionado con comportamiento inesperado reportado por el DBA — causa probable: configuración heredada de una versión anterior nunca actualizada tras un upgrade. Requiere confirmación cruzada antes de subir de `HYPOTHESIS` a `PROBABLE_CAUSE`.

# Correlation rules

Cruzar con `oracle/resource-limits` para parámetros de límites (`processes`, `sessions`, `open_cursors`). Cruzar con `oracle/instance` (RAC) para diferencias entre instancias.

# False positives

Parámetros que difieren entre instancias RAC por diseño (`instance_number`, `thread`) no son findings. Un parámetro `ISMODIFIED = 'MODIFIED'` en la sesión actual (no persistente) no se reporta como configuración de instancia — sólo `ISMODIFIED IN ('SYSTEM_MOD', 'FALSE')` es relevante.

# Confidence model

`FACT` para el valor leído directamente. `OBSERVATION` para "fuera de rango razonable" (juicio basado en umbrales documentados, no en la instancia específica). `HYPOTHESIS` para causa raíz de un síntoma correlacionado con un parámetro.

# Findings

```yaml
finding_id: FND-...
category: parameters
severity: LOW|MEDIUM
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|OBSERVATION|HYPOTHESIS
impact: string
recommendations: [REC-...]
```

# Recommendations

Actualizar un parámetro deprecado al reemplazo recomendado por Oracle para la versión detectada — `manual_execution_required: true`.

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar impacto de un cambio de parámetro en el resto del ambiente (RAC: todas las instancias)
command:    ALTER SYSTEM SET <parameter>=<value> SCOPE=BOTH; -- o SCOPE=SPFILE si requiere restart
expected_result: V$PARAMETER refleja el nuevo valor (o el spfile, si SCOPE=SPFILE, tras el próximo restart)
rollback:   ALTER SYSTEM SET <parameter>=<valor_anterior> SCOPE=BOTH;
postcheck:  Q-ORA-PARAMETERS-001 re-ejecutada confirma el nuevo valor
```

# Version differences

Lista de parámetros deprecados/obsoletos varía por versión — mantenida en `compatibility.yaml`-equivalente dentro de `manifest.yaml` de este skill, actualizada vía `/change compatibility` cuando se detecta una nueva versión.

# RAC considerations

Comparación cross-instance es el valor añadido principal de este skill en RAC — un parámetro divergente sin razón documentada es la señal más común de configuración manual inconsistente entre nodos.

# Multitenant considerations

Desde 12c, algunos parámetros son modificables a nivel PDB (`ISPDB_MODIFIABLE`); este skill opera a nivel de la conexión actual (CDB$ROOT por defecto) y no itera PDBs individualmente en Fase 2.

# Standby considerations

Los parámetros de un Physical Standby suelen (y deben) coincidir con los del Primary para varios parámetros críticos (ej. `compatible`, `db_block_size`) — una discrepancia aquí es una señal de riesgo para un futuro switchover, aunque la comparación cross-site no es posible sin acceso a ambos sitios en el mismo análisis.

# Security

Read-only, `SELECT` sobre `V$PARAMETER`. No lee `V$PARAMETER2`/parámetros con valores potencialmente sensibles (ej. rutas de wallet) sin pasar por sanitización.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/resource-limits`, `oracle/spfile`, `oracle/instance`.

# Escalation

Un parámetro relacionado con seguridad (ej. `remote_login_passwordfile`, `o7_dictionary_accessibility`) se señala pero la interpretación profunda de postura de seguridad se deja a `oracle-security-analyst` (no profundizado en Fase 2).

# Examples

Ver `tests/fixtures/19c-rac-cdb.yaml` (parámetro `optimizer_index_cost_adj` divergente entre 2 de 3 instancias).

# Data sensitivity / Context budget

Sensibilidad BAJA-MEDIA (algunos nombres/valores de parámetro pueden insinuar topología); presupuesto medio (una consulta por instancia si RAC).

# Tests

`tests/test_oracle_core_parameters.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
