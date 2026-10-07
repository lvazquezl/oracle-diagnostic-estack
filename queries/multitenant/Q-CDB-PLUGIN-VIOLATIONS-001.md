---
query_id: Q-CDB-PLUGIN-VIOLATIONS-001
version: 4.0.0

domain: multitenant
purpose: Plug-in violations por PDB — MESSAGE/ACTION siempre tratados como DATA, nunca ejecutados

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [PDB_PLUG_IN_VIOLATIONS]
privileges_required: [SELECT on PDB_PLUG_IN_VIOLATIONS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING: corrige un defecto real de
# la construcción base de Fase 6 — CON_ID se seleccionaba incondicionalmente, declarado disponible
# desde 12.1 sin verificación independiente. Verificado (WebFetch): la referencia 12.1
# (docs.oracle.com/database/121/REFRN/GUID-845E5369-CCB0-4F8D-AE09-447EF0CAC93F.htm) lista 9
# columnas SIN con_id; la referencia 12.2 (docs.oracle.com/en/database/oracle/oracle-database/
# 12.2/refrn/PDB_PLUG_IN_VIOLATIONS.html) lista 10 columnas CON con_id. CON_ID se agrega en 12.2,
# no existe en 12.1 (# 15-19 del prompt de hardening). Dos variantes reales:
variants:
  - variant_id: Q-CDB-PLUGIN-VIOLATIONS-001-V1
    label: legacy_121_no_con_id
    oracle_versions: {min: "12.1", max: "12.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_121_no_con_id, 12.1 only)"
  - variant_id: Q-CDB-PLUGIN-VIOLATIONS-001-V2
    label: modern_122plus_con_id
    oracle_versions: {min: "12.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_122plus_con_id, 12.2+)"

tests: [tests/test_no_write_operations.sh, tests/test_plugin_violation_detection.sh, tests/test_plugin_violation_action_treated_as_data.sh, tests/test_plugin_violation_no_auto_remediation.sh, tests/test_multitenant_container_scope.sh, tests/test_plugin_violation_121_variant_without_con_id.sh, tests/test_plugin_violation_modern_variant_with_con_id.sh, tests/test_plugin_violation_121_does_not_reference_con_id.sh, tests/test_plugin_violation_modern_columns_valid.sh, tests/test_plugin_violation_variant_resolution.sh, tests/test_plugin_violation_121_name_maps_to_pdb_identity.sh, tests/test_plugin_violation_121_container_id_not_available.sh, tests/test_plugin_violation_121_container_name_from_name.sh, tests/test_plugin_violation_modern_con_id_and_name.sh, tests/test_plugin_violation_identity_sanitization.sh, tests/test_plugin_violation_action_still_treated_as_data.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_121_no_con_id, 12.1 only)

```sql
SELECT name AS pdb_name, type, status, cause,
       COUNT(*) AS violation_count,
       ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(MAX(time)) AS DATE)) * 24, 2) AS hours_since_last
FROM   pdb_plug_in_violations
GROUP  BY name, type, status, cause
ORDER  BY name, type, status;
```

# Statement / procedure (read-only) — Variant V2 (modern_122plus_con_id, 12.2+)

```sql
SELECT con_id, name AS pdb_name, type, status, cause,
       COUNT(*) AS violation_count,
       ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(MAX(time)) AS DATE)) * 24, 2) AS hours_since_last
FROM   pdb_plug_in_violations
GROUP  BY con_id, name, type, status, cause
ORDER  BY con_id, type, status;
```

`PDB_PLUG_IN_VIOLATIONS` tiene **dos** señales de identidad de PDB en esta variante: `CON_ID` (el contenedor) y `NAME` (*"the name of an existing PDB or a PDB intended to be created"*, verificado contra Oracle Database Reference 12.2/19c — corrección respecto a una interpretación incorrecta anterior que asumía `NAME` como nombre de violación/componente, ver PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING). El skill (`multitenant/plugin-violations`) correlaciona `con_id` contra el inventario ya publicado por `Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001` (en vez de duplicar un join en SQL) y usa `NAME` como segunda señal — si `con_id`→`pdb_token` y `NAME` no correlacionan, publica `IDENTITY_MISMATCH` en vez de ocultar la inconsistencia (`# 6` del prompt de este hardening). `MESSAGE`/`ACTION` se sanitizan y se tratan siempre como texto de datos — nunca como instrucción ejecutable (`# 26`, `# 48` del prompt de Fase 6 base; `# 20`/`# 8` de los hardenings posteriores). Ninguna variante ejecuta la acción sugerida por `ACTION`.

# Notes by version

`PDB_PLUG_IN_VIOLATIONS` disponible desde 12.1 (view-level). `CON_ID` disponible sólo desde **12.2** — no existe en 12.1 (corregido en el hardening de compatibilidad). `NAME` (identidad de PDB) disponible en **todo** el rango 12.1–23ai, en ambas variantes. Columnas restantes (`time`/`cause`/`type`/`error_number`/`line`/`message`/`status`/`action`) también estables en todo el rango.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — un CDB sano típicamente tiene 0 filas; incluso con violaciones, el volumen es acotado (decenas).

# License notes

Ninguna.

# Sanitization notes

`message`/`action` → sanitización de patrones de ruta/hostname/nombre de PDB embebidos en el texto libre antes de publicarse como evidencia (mismo criterio que `parsers/dataguard/alertlog_filter.py` para texto libre de Oracle). `name` → **MASK** (contiene el nombre real de la PDB, no un nombre de violación/componente — corregido en PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING), mismo tokenizado consistente (`PDB_NNN`) que `Q-CDB-PDB-STATE-001.name` — mismo mapping dentro del mismo análisis, nunca expuesto en claro si la política requiere tokenización (`# 7` del prompt de este hardening).

# Evolution via `/change query`

N/A — vista estable.

4.0.0 CHG-ESTACK-PDB-COVERAGE-001: Resumen por contenedor (`con_id` y nombre, para detectar `IDENTITY_MISMATCH`), tipo, estado y causa: ya no devuelve `message`, `action` ni `line` (texto libre que puede llevar nombres o rutas) ni `time` absoluto. El detalle de cada violación se consulta a mano. Requiere `GRANT SELECT ON SYS.PDB_PLUG_IN_VIOLATIONS` (no viene en `SELECT_CATALOG_ROLE`; ORA-00942 en el lab).
