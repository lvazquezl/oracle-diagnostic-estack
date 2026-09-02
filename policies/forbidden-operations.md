# Forbidden Operations

Lista exhaustiva de lo que ningún agente, skill, query, collector o tool MCP de este e-stack puede declarar ni ejecutar. Validado estáticamente por `tests/test_no_write_operations.*` sobre todos los manifests, el catálogo de queries y el tool manifest.

## Oracle Database

- Cualquier `INSERT`, `UPDATE`, `DELETE`, `MERGE` (DML).
- Cualquier `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `RENAME` (DDL) — incluyendo `ALTER SYSTEM`, `ALTER SESSION SET` con efecto persistente.
- `ALTER PLUGGABLE DATABASE OPEN/CLOSE/UNPLUG`.
- Gestión de usuarios/roles/profiles/auditoría (`CREATE/ALTER/DROP USER|ROLE|PROFILE`, `AUDIT`/`NOAUDIT` de configuración).
- `SQL Plan Baselines`/`SQL Profiles` de escritura, recompilación forzada de objetos.
- Kill de sesión (`ALTER SYSTEM KILL SESSION`).

## RMAN / Backup-Recovery

- `BACKUP`, `RESTORE`, `RECOVER`.
- `CROSSCHECK`, `DELETE OBSOLETE`, `DELETE EXPIRED` (mutan el catálogo RMAN).
- `CONFIGURE` de escritura (retention policy, canales, device type).

## Data Guard

- `ALTER DATABASE SWITCHOVER/FAILOVER TO`.
- Cambio de protection mode o modo de transporte.
- Inicio/detención de MRP/RFS.
- Cambios de configuración de Broker (`DGMGRL EDIT/ENABLE/DISABLE CONFIGURATION`).

## RAC / Grid Infrastructure / ASM

- `srvctl start|stop|modify|add|remove` (cualquier verbo de cambio).
- `crsctl start|stop|modify|add|delete|relocate`.
- `ALTER DISKGROUP ADD/DROP/RESIZE DISK`, inicio/detención de rebalance.
- Relocate/failover manual de servicios o instancias.

## Sistema Operativo (todas las plataformas)

- `systemctl start/stop/restart/enable/disable` (o equivalentes: `svcadm` en Solaris, `chkconfig`/`smit` en AIX de escritura, `sc.exe`/`Set-Service` en Windows, `/sbin/init.d/*` en HP-UX).
- Cualquier `sudo`, elevación, o uso de shell administrativo irrestricto.
- Escritura en `/etc/sysctl.conf`, `/etc/security/limits.conf`, Registro de Windows, `/etc/fstab`, o cualquier archivo de configuración de kernel/sistema.
- `kill`/`Stop-Process` de procesos, gestión de particiones/volúmenes/multipath.

## Red

- Modificación de `listener.ora`/`tnsnames.ora`/`sqlnet.ora`.
- Reinicio de listener/SCAN listener.
- Cambios de DNS, bonding, VLAN, firewall.

## Genéricas (cualquier dominio)

- No existe ni puede existir una tool equivalente a `execute_any_shell_command()` o `execute_sql(sql)` de texto libre.
- Ninguna tool recibe un parámetro `sql`/`command`/`script`/`raw_query` sin certificar.
- Ninguna identidad usada por el e-stack tiene capacidad de escritura, por diseño de privilegios, no sólo por convención de uso.

## Excepción única

`change-advisor` puede **generar texto** de cualquiera de los comandos anteriores como parte de una propuesta de cambio (`CHG-*`) para ejecución manual del DBA — nunca los ejecuta, invoca, ni los pasa a ninguna tool.
