---
query_id: Q-ORA-DIAGNOSTICS-ALERTLOG-001
version: 1.0.0
domain: oracle
purpose: Extracto acotado de errores ORA-* recientes en el alert log

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [alert.log]
privileges_required: [lectura de archivo via collector certificado]

risk_class: R0
cost_class: MEDIUM
timeout_seconds: 30
max_rows: 2000
max_output_bytes: 262144

sensitivity: HIGH
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_secret_detection.sh]
status: active
---

# Statement / procedure (read-only)

```text
Collector de archivo certificado: lee las últimas N líneas del alert log (o la ventana de tiempo
solicitada, si el formato del alert log lo permite parsear por timestamp — XML alert log desde 11g
lo facilita; texto plano en 10g requiere parseo por patrón de fecha) filtradas a líneas que contienen
"ORA-". Nunca lee el archivo completo; nunca ejecuta un comando de shell arbitrario — el collector es
un lector de archivo certificado y acotado, no un canal de ejecución.
```

# Notes by version

Alert log en XML desde 11g (`log.xml` bajo ADR) facilita filtrado estructurado; en 10g es texto plano, el collector usa parseo por patrón.

# Notes by platform

La ruta del alert log difiere por convención de plataforma — resuelta por el collector certificado (ver `collectors/README.md`), nunca hardcodeada aquí.

# Container / role scope notes

`NOT_APPLICABLE` — el alert log es de instancia física (algunas configuraciones tienen un PDB alert log adicional, fuera de esta query en Fase 2).

# Cost classification rationale

`MEDIUM`: lectura de archivo acotada por líneas/ventana, pero el I/O de archivo es más costoso que una query SQL simple.

# License notes

Ninguna.

# Sanitization notes

El extracto completo pasa por el Sanitizer antes de llegar al modelo: hostnames, nombres de schema/objeto, y cualquier patrón que coincida con credenciales/secretos se enmascaran o se eliminan (`DROP`) — nunca se envía el archivo sin procesar.

# Evolution via `/change query`
