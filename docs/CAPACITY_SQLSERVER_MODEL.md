# Capacity SQL Server Model — Fase 10

## Alcance

CPU, memoria, tamaño de base de datos, data files, log files, volumen/storage (`# 593`-`# 606`
del prompt de Fase 10). **No implementa administración de SQL Server fuera del alcance de
capacidad** — nunca T-SQL, nunca cambios de configuración de la instancia.

## Estado en Fase 10 (MVP)

Contract diseñado (`skills/capacity/sqlserver/SKILL.md`), sin collector runtime certificado en
esta fase — fuente `NOT_CERTIFIED` por defecto, disponible sólo vía `MANUAL_IMPORT`.

## Output

```yaml
sqlserver_capacity:
  status: NOT_CERTIFIED|MANUAL_IMPORT|CONNECTED
  cpu:
  memory:
  database_size_bytes:
  data_files: [...]
  log_files: [...]
  volume_storage:
```

## Referencias

`skills/capacity/sqlserver/SKILL.md`, `docs/CAPACITY_DATA_SOURCE_MODEL.md`.
