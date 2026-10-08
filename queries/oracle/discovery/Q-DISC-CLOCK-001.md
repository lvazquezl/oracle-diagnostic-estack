---
query_id: Q-DISC-CLOCK-001
version: 1.0.0
domain: oracle
purpose: Hora UTC de la base (reloj del sistema operativo del servidor) y su zona horaria, para medir el desfase contra el reloj del gateway

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$INSTANCE]
privileges_required: [SELECT on V$INSTANCE]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 1
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - DATE '1970-01-01') * 86400) AS db_utc_epoch,
       EXTRACT(TIMEZONE_HOUR FROM SYSTIMESTAMP) * 60 + EXTRACT(TIMEZONE_MINUTE FROM SYSTIMESTAMP) AS db_tz_offset_minutes
FROM   v$instance;
```

`SYSTIMESTAMP` sale del reloj del sistema operativo del servidor: lo que se mide es el reloj del host. El gateway compara `db_utc_epoch` con su propia hora UTC al recolectar y publica `clock_check` (desfase en segundos; limitación `CLOCK_SKEW` si supera 300 s). Con desfase, cualquier "horas desde…" calculado en la base (uptime, edad de backups, apertura de PDBs) puede no corresponder al tiempo real.

# Notes by version

`SYS_EXTRACT_UTC`, `SYSTIMESTAMP` y `EXTRACT(TIMEZONE_*)` existen desde 9i.

# Notes by platform

Ninguna diferencia en SQL. La sincronización del reloj (NTP/chrony, pausas de la VM) es del dominio `os-platform-analyst`.

# Container / role scope notes

`ANY_CONTAINER`: todos los contenedores comparten el reloj del host.

# Cost classification rationale

`LOW`: una fila de `V$INSTANCE` (la instancia local).

# License notes

Ninguna.

# Sanitization notes

Sólo números (segundos desde 1970 en UTC y minutos de desfase de zona) → KEEP.

# Evolution via `/change query`

CHG-ESTACK-ASSESSMENT-ACCURACY-001 — creada: en ANA-20261008-001 el reloj de la base y el del gateway diferían ~2.2 h y alteraban los cálculos de "horas desde…" (FND-0003/FND-0027).
