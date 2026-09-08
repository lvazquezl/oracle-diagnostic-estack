---
query_id: Q-DG-MANAGED-PROCESS-001
version: 3.0.0

domain: dataguard
purpose: Estado de procesos Data Guard (MRP/RFS/LNS/ARCH) — visibilidad, nunca control

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$MANAGED_STANDBY, GV$MANAGED_STANDBY, V$DATAGUARD_PROCESS, GV$DATAGUARD_PROCESS]
privileges_required: [SELECT on V$MANAGED_STANDBY, SELECT on GV$MANAGED_STANDBY, SELECT on V$DATAGUARD_PROCESS, SELECT on GV$DATAGUARD_PROCESS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 100
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING (# 4-10 del prompt): metadata y
# frontera de versiones corregidas contra la documentación oficial de Oracle Database Reference.
# V$DATAGUARD_PROCESS fue introducida en Oracle Database 12c Release 2 (12.2.0.1) — NO 11.2 como
# se declaró incorrectamente en el hardening anterior. V$MANAGED_STANDBY está oficialmente
# deprecada desde esa misma versión (12.2.0.1), y Oracle recomienda V$DATAGUARD_PROCESS en su
# lugar. Por eso el rango de versiones deja de ser "legacy default + modern on-demand overlay"
# (hardening anterior) y pasa a una partición real, sin solapamiento: 10.2–12.1 usa
# exclusivamente la vista legacy (única opción certificada en ese rango); 12.2–23.0 usa
# exclusivamente la vista moderna (Oracle ya no recomienda la legacy ahí — # 8: no usar la vista
# deprecated como universal permanent default). Ver docs/PHASE_5_FINAL_PROCESS_VIEW_PORTABILITY_
# HARDENING.md para el detalle de verificación documental.
variants:
  - variant_id: Q-DG-MANAGED-PROCESS-001-V1
    label: legacy_managed_standby
    oracle_versions: {min: "10.2", max: "12.1"}
    container_scope: ANY_CONTAINER
    cost_class: LOW
    default: true
    sql_block: "Variant V1 (legacy_managed_standby, 10.2–12.1)"
  - variant_id: Q-DG-MANAGED-PROCESS-001-V2
    label: modern_dataguard_process
    oracle_versions: {min: "12.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    cost_class: LOW
    default: true
    sql_block: "Variant V2 (modern_dataguard_process, 12.2–23.0)"

tests: [tests/test_no_write_operations.sh, tests/test_dataguard_managed_process_query.sh, tests/test_apply_healthy.sh, tests/test_mrp_stopped.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_dataguard_process_legacy_variant.sh, tests/test_dataguard_process_modern_variant.sh, tests/test_dataguard_process_legacy_does_not_use_modern_view.sh, tests/test_dataguard_process_modern_does_not_use_legacy_default.sh, tests/test_dataguard_process_modern_uses_supported_columns.sh, tests/test_v_dataguard_process_columns_match_dictionary_model.sh, tests/test_dataguard_process_variant_resolution_11g.sh, tests/test_dataguard_process_variant_resolution_121.sh, tests/test_dataguard_process_variant_resolution_122.sh, tests/test_dataguard_process_variant_resolution_19c.sh, tests/test_dataguard_process_variant_resolution_23ai.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_managed_standby, 10.2–12.1)

```sql
SELECT process, pid, status, client_process, client_pid, thread#, sequence#, block#, blocks
FROM   v$managed_standby;
```

Única variante certificada para 10.2–12.1 — `V$MANAGED_STANDBY` no está deprecada en ese rango.
Sobre un sitio RAC, el collector selecciona `GV$MANAGED_STANDBY` (mismas columnas + `INST_ID`,
`compatibility/oracle-dictionary/views.yaml#gv$managed_standby`) según `target_profile.rac.enabled`
— no es una variante versionada del Query Variant Contract, es selección por arquitectura, igual
que en Q-DG-DEST-001.

# Statement / procedure (read-only) — Variant V2 (modern_dataguard_process, 12.2–23.0)

```sql
SELECT name, pid, type, role, action, client_pid, client_role, thread#, sequence#, block#, block_count
FROM   v$dataguard_process;
```

Única variante certificada para 12.2–23.0 — `V$MANAGED_STANDBY` está oficialmente deprecada desde
12.2.0.1 (Oracle Database Reference) y Oracle recomienda `V$DATAGUARD_PROCESS` en su lugar. A
diferencia de lo asumido en el hardening anterior, esta vista **sí** expone `THREAD#`/`SEQUENCE#`/
`BLOCK#` — verificado contra la documentación oficial — por lo que esos campos del modelo lógico
quedan totalmente soportados aquí, no `PARTIALLY_SUPPORTED`. Sobre RAC, el collector selecciona
`GV$DATAGUARD_PROCESS` (mismas columnas + `INST_ID`) según `target_profile.rac.enabled`.

# Semantic normalization

Los skills (`dataguard/apply`, `dataguard/processes`) consumen un modelo lógico común, nunca las
columnas de una vista específica directamente — así el cambio de variante (legacy/modern) es
transparente para la lógica de decisión (`# 6` del prompt de Final Process-View Hardening):

```yaml
dataguard_process:
  process_name: string          # PROCESS (V1) | NAME (V2)
  process_role: string|NOT_AVAILABLE   # NOT_AVAILABLE en V1 — V$MANAGED_STANDBY no tiene columna ROLE
  process_action: string        # STATUS (V1) | ACTION (V2) — vocabulario de estado solapado (CONNECTED/
                                 # ERROR/IDLE/WRITING/RECEIVING/APPLYING_LOG/UNUSED en ambas vistas)
  client_pid: string|null
  thread: int|null              # SUPPORTED en ambas variantes (V2 sí expone THREAD#)
  sequence: int|null            # SUPPORTED en ambas variantes
  source_view: string           # V$MANAGED_STANDBY|GV$MANAGED_STANDBY|V$DATAGUARD_PROCESS|GV$DATAGUARD_PROCESS
  source_variant: legacy|modern
```

`process_role` es el único campo sin equivalente real en la variante legacy — se reporta
explícitamente como `NOT_AVAILABLE`, nunca inferido desde `PROCESS`/`STATUS` (`# 6`: no inventar
valores). `thread`/`sequence` están soportados en ambas variantes (corrección respecto al
hardening anterior, que asumía incorrectamente que `V$DATAGUARD_PROCESS` no los exponía).

# Notes by version

`V$MANAGED_STANDBY` estable desde 10g; `GV$MANAGED_STANDBY` desde 11.2; ambas **deprecadas desde
12.2.0.1** (Oracle Database Reference) — certificadas en este catálogo únicamente para 10.2–12.1.
`V$DATAGUARD_PROCESS`/`GV$DATAGUARD_PROCESS` desde 12.2.0.1 — certificadas para 12.2–23.0. Ningún
rango se solapa: el resolver nunca elige entre dos variantes candidatas para la misma versión,
selecciona la única aplicable (`# 10` del prompt: no fallback silencioso entre legacy/modern).

# Notes by platform

Ninguna — SQL puro en ambas variantes.

# Container / role scope notes

`ANY_CONTAINER` en ambas variantes. `database_role_scope: ANY` — procesos de transporte corren en
el primary, de apply en el standby; ambas variantes cubren los dos roles.

# Cost classification rationale

`LOW` en ambas variantes — acotado al número de procesos/agentes Data Guard activos (típicamente <10).

# License notes

Ninguna en ninguna variante.

# Sanitization notes

Todos los campos → KEEP en ambas variantes.

# Evolution via `/change query`

Una nueva major Oracle requiere `/change compatibility` antes de extender `max_certified_major`
(hoy 23) — nunca heredar soporte automáticamente (`# 32` del prompt de Final Process-View
Hardening).
