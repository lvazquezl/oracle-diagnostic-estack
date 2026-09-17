---
name: sqlserver
id: capacity/sqlserver
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Contract de capacidad para SQL Server Database — CPU, memoria, tamaño de base de datos, data
files, log files, volumen/storage. Sin collector runtime certificado en esta fase — fuente
`NOT_CERTIFIED` por defecto, disponible sólo vía `MANUAL_IMPORT` cuando el DBA aporte datos
exportados. **No implementa administración de SQL Server fuera del alcance de capacidad.**

# Supported Oracle versions

N/A — dominio SQL Server, no Oracle.

# Supported OS/platforms

Windows Server (host típico de SQL Server): contract diseñado, `PARTIALLY_SUPPORTED`.

# Supported architectures

N/A directo — Always On Availability Groups fuera de alcance de esta fase (awareness únicamente
si el DBA declara la topología).

# Prerequisites

Fuente `MANUAL_IMPORT` o adapter certificado (fuera de alcance de Fase 10 MVP) declarado en el
Target Profile.

# Required evidence

- Datos aportados vía `MANUAL_IMPORT` con `source_id` explícito, o `NOT_CERTIFIED` si no hay
  fuente disponible — nunca un valor inventado.

# Optional evidence

Ninguna.

# Read-only operations

Lectura de datos ya exportados/importados manualmente — ningún acceso directo a la instancia SQL
Server en esta fase.

# Forbidden operations

Nunca ejecuta T-SQL, nunca modifica configuración de SQL Server, nunca administra la instancia
fuera del alcance de capacidad.

# Decision logic

1. Normalizar (cuando disponible) `CPU`, `memory`, `database size`, `data files`, `log files`,
   `volume/storage` al Common Metric Model (`# 593`-`# 606` del prompt de Fase 10).
2. Sin fuente `CONNECTED`/`MANUAL_IMPORT`, el recurso queda `NOT_CERTIFIED` — el resto del
   assessment continúa con `PARTIAL_CAPACITY_ASSESSMENT`, nunca bloqueado.
3. Nunca extiende el contract a administración de SQL Server (índices, mantenimiento, backups) —
   estrictamente fuera de alcance de capacidad.

# Normal state

Datos disponibles vía `MANUAL_IMPORT` con calidad `ACCEPTABLE`/`GOOD`.

# Abnormal patterns

N/A hasta que exista evidencia real — el estado por defecto es `NOT_CERTIFIED`, no un hallazgo.

# False positives

Ninguno — sin evidencia no se reporta ningún hallazgo, sólo `NOT_CERTIFIED`.

# Correlation rules

Alimenta `capacity/cpu`, `capacity/memory`, `capacity/storage` cuando haya evidencia; alimenta
`capacity/capacity-assessment`.

# Confidence model

`UNDETERMINED` sin evidencia; `FACT` sobre datos efectivamente importados.

# Severity

N/A sin evidencia.

# Output schema

```yaml
sqlserver_capacity:
  status: NOT_CERTIFIED|MANUAL_IMPORT|CONNECTED
  cpu: number|null
  memory: number|null
  database_size_bytes: number|null
  data_files: [{file: string, size: number|null}]|null
  log_files: [{file: string, size: number|null}]|null
  volume_storage: number|null
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/cpu`, `capacity/memory`, `capacity/storage`, `capacity/data-source-inventory`.

# Escalation

Ninguna sin evidencia real.

# Manual remediation guidance

N/A directa — fuera de alcance de capacidad.

# Security

Sin datos sensibles — sólo metadata de capacidad cuando exista.

# Tests

`tests/test_capacity_read_only.sh`.

# Documentation requirements

Alimenta `capacity-summary.md` (sección SQL Server, `NOT_CERTIFIED` cuando aplique).

# Change history

v1.0.0 — Fase 10, creación inicial.
