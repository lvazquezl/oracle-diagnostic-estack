# Identity Model

## Principio

Separación estricta entre la identidad del e-stack y la identidad DBA humana. El e-stack nunca ve, usa ni puede solicitar la identidad humana con capacidad de cambio.

## `ESTACK_DIAG_*`

- Identidad(es) exclusiva(s) del e-stack, read-only por diseño de privilegios (no por convención).
- Preferentemente **una identidad diagnóstica por DBA** (`ESTACK_DIAG_<usuario>`) para trazabilidad individual en auditoría — no una cuenta genérica compartida.
- Nunca tiene `SYSDBA`, `SYSOPER`, `SYSASM`, `DBA` role, ni privilegios `ANY` de escritura.
- Concedida vía `ESTACK_DIAGNOSTIC_ROLE` (ver abajo), nunca privilegios directos ad-hoc.

## `ESTACK_DIAGNOSTIC_ROLE`

Rol de mínimo privilegio, compuesto por:

- `SELECT` sobre vistas `V$*`/`GV$*`/`DBA_HIST_*` necesarias para el catálogo certificado (`queries/REGISTRY.md`), nunca `GRANT ANY`.
- `SELECT_CATALOG_ROLE` como base cuando sea el mínimo suficiente; si se requiere granularidad mayor, vistas diagnósticas propias (ver abajo) en vez de ampliar `SELECT_CATALOG_ROLE`.
- Sin acceso a esquemas de aplicación por defecto.
- Sin `CREATE SESSION` con perfil sin límites — se recomienda un `PROFILE` dedicado con `IDLE_TIME`/`CONNECT_TIME` acotados.

## Vistas diagnósticas controladas

Cuando conviene exponer un subconjunto agregado en lugar de la vista completa (ej. para evitar exponer `sql_text` en `V$SQL`), el rol usa una vista propia (`ESTACK_V_*`) creada y mantenida por el DBA humano — nunca creada ni modificada por el e-stack mismo, que sólo la consume por `SELECT`.

## Identidad DBA humana

- Completamente separada, nunca accesible ni utilizable por el e-stack.
- El e-stack nunca solicita, recibe, ni almacena la password/wallet de la identidad DBA.
- Toda ejecución de un `CHG-*` la realiza el DBA con su propia identidad, fuera del e-stack.

## Least privilege — regla general

No se otorgan privilegios genéricos innecesarios. Cada ampliación de `ESTACK_DIAGNOSTIC_ROLE` requiere justificación explícita ligada a una query certificada concreta (`/change query` → impacto en `/change security`).

## OS / plataforma

Identidad de sistema operativo de sólo lectura, sin `root`/`sudo`/Administrator. En Windows, cuenta de servicio sin privilegios administrativos, con acceso de lectura únicamente a los contadores de rendimiento y rutas de configuración necesarias.
