---
query_id: Q-ORA-PARAMETERS-001
version: 1.0.0
domain: oracle
purpose: Parámetros de inicialización no-default

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$PARAMETER]
privileges_required: [SELECT on V$PARAMETER]

risk_class: R0
cost_class: LOW
timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT name, value, isdefault, ismodified
FROM   v$parameter
WHERE  isdefault = 'FALSE'
ORDER  BY name;
```

Nunca selecciona `V$PARAMETER2`/parámetros que puedan contener rutas de wallet u otro material sensible sin pasar por sanitización explícita.

# Notes by version

El conjunto de parámetros válidos varía por versión — la query no asume ninguno específico, sólo filtra `isdefault='FALSE'` sobre lo que la versión conectada expone.

# Notes by platform

Ninguna — algunos parámetros son platform-specific pero la query no lo distingue, el skill interpreta el resultado según plataforma.

# Container / role scope notes

`ANY_CONTAINER` — desde 12c algunos parámetros son PDB-modifiable, otros no; la query no filtra por eso, el skill lo interpreta.

# Cost classification rationale

`LOW`: acotado a parámetros no-default, típicamente decenas, no miles.

# License notes

Ninguna.

# Sanitization notes

`value` → condicional (`DROP` si el nombre del parámetro sugiere contenido sensible, ej. rutas de wallet); resto → KEEP.

# Evolution via `/change query`
