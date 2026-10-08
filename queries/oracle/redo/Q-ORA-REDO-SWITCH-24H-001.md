---
query_id: Q-ORA-REDO-SWITCH-24H-001
version: 2.0.0
domain: oracle
purpose: Log switches por hilo en las últimas 24 horas, en tramos de una hora hacia atrás (ventana fija, sin binds)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$LOG_HISTORY, V$LOG]
privileges_required: [SELECT on V$LOG_HISTORY, SELECT on V$LOG]

risk_class: R0
cost_class: LOW
timeout_seconds: 15
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT thread_no,
       FLOOR((SYSDATE - switch_time) * 24)       AS hours_ago,
       COUNT(*)                                  AS switch_count
FROM  (SELECT thread# AS thread_no, first_time AS switch_time FROM v$log_history
       UNION ALL
       SELECT thread#, first_time FROM v$log WHERE status = 'CURRENT')
WHERE  switch_time >= SYSDATE - 1
  AND  switch_time <= SYSDATE
GROUP  BY thread_no, FLOOR((SYSDATE - switch_time) * 24)
ORDER  BY thread_no, hours_ago;
```

`hours_ago` = 0 es la hora más reciente. Tramos sin switches no aparecen. Más de ~4 switches por hora de forma sostenida sugiere redo logs pequeños para la carga (ver `oracle/redo`). Para una ventana arbitraria sigue existiendo `Q-ORA-REDO-SWITCH-FREQ-001`, con binds, para ejecución humana.

# Notes by version

`V$LOG_HISTORY` estable desde 10g en las columnas usadas.

# Notes by platform

Ninguna diferencia.

# Container / role scope notes

`ANY_CONTAINER`: la historia de redo es de la base (CDB). `ANY` rol: en standby refleja el redo recibido/aplicado.

# Cost classification rationale

`LOW`: ventana fija de 24 horas y agregación por hora; como máximo 24 filas por hilo.

# License notes

Ninguna.

# Sanitization notes

Sólo números (hilo, horas hacia atrás, conteo) → KEEP. Sin fechas absolutas.

# Evolution via `/change query`

CHG-ESTACK-COLLECTOR-FACTORY-B2 — creada: versión sin binds de `Q-ORA-REDO-SWITCH-FREQ-001` para que el gateway pueda recolectarla.

2.0.0 CHG-ESTACK-ASSESSMENT-ACCURACY-001: cada fila de `V$LOG_HISTORY` es un log y su `FIRST_TIME` es el switch que lo hizo actual; el log actual todavía no está en la historia, así que la 1.0.0 no contaba el switch más reciente (por ejemplo el del arranque) y reportaba 0 (FND-0017 de ANA-20261007-001, FND-0028 de ANA-20261008-001). Ahora suma el `FIRST_TIME` del log `CURRENT` de `V$LOG`. Se descarta `switch_time > SYSDATE` (registros de un reloj desfasado darían horas negativas). La revisión sugería `NEXT_TIME`, que **no existe** en `V$LOG_HISTORY` (sí en `V$ARCHIVED_LOG`): un primer intento con esa columna falló en el lab con `E_ADAPTER_FAILED`.
