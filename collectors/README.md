# Collectors — especificación

Estado en Fase 1: **especificación certificada**, no runtime ejecutable (Fase 2+ implementa los collectors reales por plataforma).

Un collector ejecuta exactamente una query/comando certificado de `queries/REGISTRY.md` contra el ambiente real y devuelve el resultado crudo al Sanitizer — nunca directamente al modelo.

## Contrato de un collector

- Recibe: `query_id`, parámetros validados por el Gateway (ya acotados a `timeout`/`max_rows`).
- Ejecuta: exactamente esa query certificada, con la identidad `ESTACK_DIAG_*`, contra el target indicado.
- Nunca interpola parámetros no validados en SQL/shell (previene injection).
- Devuelve: resultado crudo + metadata (`collector`, `timestamp`, `target`, `duration`) para construir el `EVD-*` correspondiente.
- Nunca cachea credenciales; las obtiene del credential provider local de la estación de trabajo en cada invocación.

## Tipos de collector

| collector | transporte | plataformas |
|---|---|---|
| `oracle-sql-collector` | JDBC/Oracle Client, sesión read-only `ESTACK_DIAG_*` | todas las que soportan Oracle Client |
| `oracle-rman-collector` | `V$RMAN_*`/catálogo vía el mismo canal SQL (no invoca `rman` como shell) | todas |
| `os-linux-collector` | lectura de `/proc`, `/sys` vía canal certificado (no shell interactivo libre) | Oracle Linux, RHEL, SUSE |
| `os-solaris-collector` | `kstat`/`/proc` equivalentes, sólo lectura | Solaris |
| `os-aix-collector` | comandos de estado AIX (`vmstat`, `lparstat` en modo lectura, sin flags de cambio) | AIX |
| `os-windows-collector` | PerfCounters/WMI de sólo lectura | Windows Server |
| `os-hpux-collector` | comandos de estado HP-UX de sólo lectura | HP-UX (legacy) |
| `net-config-collector` | lectura de archivos `tnsnames.ora`/`sqlnet.ora`/`listener.ora` y `listener.log` (ventana acotada) | todas |

## Certificación

Un collector nuevo o modificado sigue el mismo flujo `/change query` (para las queries que ejecuta) + `/change compatibility` (si introduce una plataforma nueva), con SECURITY VALIDATION obligatoria antes de HUMAN REVIEW.

## Límites obligatorios (todo collector)

Timeout, max rows/output, cancelación, clasificación de costo — heredados de la entrada de `queries/REGISTRY.md` que ejecuta. Ver `policies/rate-limiting-policy.md`.
