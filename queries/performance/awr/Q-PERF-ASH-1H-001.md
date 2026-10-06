---
query_id: Q-PERF-ASH-1H-001
version: 1.0.0

domain: performance
purpose: Actividad de sesiones de los últimos 60 minutos según ASH, por clase de espera, evento y sql_id (muestras, no filas crudas)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$ACTIVE_SESSION_HISTORY]
privileges_required: [SELECT on V$ACTIVE_SESSION_HISTORY]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 25
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-ASH-1H-001-V1
    label: legacy_rownum
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_rownum, 10.2–11.2)"
  - variant_id: Q-PERF-ASH-1H-001-V2
    label: modern_fetch_first
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_fetch_first, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_every_logical_query_has_variant.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_rownum, 10.2–11.2)

```sql
SELECT *
FROM  (SELECT NVL(h.wait_class, 'CPU') AS wait_class, NVL(h.event, 'ON CPU') AS event, h.sql_id,
              COUNT(*) AS ash_samples, COUNT(DISTINCT h.session_id) AS session_count
       FROM   v$active_session_history h
       WHERE  h.sample_time >= SYSTIMESTAMP - INTERVAL '60' MINUTE
       GROUP  BY NVL(h.wait_class, 'CPU'), NVL(h.event, 'ON CPU'), h.sql_id
       ORDER  BY COUNT(*) DESC)
WHERE  ROWNUM <= 25;
```

# Statement / procedure (read-only) — Variant V2 (modern_fetch_first, 12.1+)

```sql
SELECT NVL(h.wait_class, 'CPU') AS wait_class, NVL(h.event, 'ON CPU') AS event, h.sql_id,
       COUNT(*) AS ash_samples, COUNT(DISTINCT h.session_id) AS session_count
FROM   v$active_session_history h
WHERE  h.sample_time >= SYSTIMESTAMP - INTERVAL '60' MINUTE
GROUP  BY NVL(h.wait_class, 'CPU'), NVL(h.event, 'ON CPU'), h.sql_id
ORDER  BY COUNT(*) DESC
FETCH  FIRST 25 ROWS ONLY;
```

Cada muestra de ASH ≈ 1 segundo de una sesión activa: `ash_samples / 3600` = sesiones activas promedio de esa combinación en la hora. CPU aparece como clase `CPU` y evento `ON CPU`. Para incidentes puntuales, `Q-PERF-WAIT-ASH-001` (ruta humana, ventana con `--param`) da el detalle.

# Notes by version

`V$ACTIVE_SESSION_HISTORY` desde 10g; `FETCH FIRST` desde 12.1 (V2).

# Notes by platform

Ninguna diferencia.

# Container / role scope notes

`ANY_CONTAINER`: desde `CDB$ROOT` AWR describe la instancia completa. `PRIMARY`: en un standby no se generan snapshots AWR locales (salvo configuración remota de AWR).

# Cost classification rationale

`MEDIUM`: lee snapshots AWR de una ventana fija (24 h) o ASH en memoria (60 min), agrega en la base y acota filas.

# License notes

**Requiere Oracle Diagnostics Pack.** El gateway sólo la ejecuta si el target declara `license_status.diagnostics_pack = CONFIRMED` (confirmación humana del contrato; `CONTROL_MANAGEMENT_PACK_ACCESS` no prueba la licencia). En la ruta humana exige `--license-confirmed diagnostics_pack --confirmed-by <revisor>`.

# Sanitization notes

`event` → nombre de evento Oracle; `wait_class` → enum (incluye `CPU`); `sql_id` → tipo `sql_id`; conteos → KEEP. Sin sesiones ni usuarios.

# Evolution via `/change query`

CHG-ESTACK-AWR-LICENSED-001 — creada para el lote B4 (AWR/ASH con ventana fija, sin binds).
