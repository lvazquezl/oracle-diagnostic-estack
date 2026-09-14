---
name: time-sync
id: os/time-sync
version: 1.0.0
domain: os
status: active
---

# Purpose

Analiza estado de sincronización de tiempo (`chrony`/`ntpd`/`systemd-timesyncd`/Windows Time/
Solaris time service) — crítico para RAC (Clusterware requiere reloj sincronizado) y para
correlación de timestamps entre nodos/logs.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Linux (`chronyc tracking`/`sources`, `timedatectl`, ambos ya mencionados en `# 9` del prompt):
`SUPPORTED`. Solaris (servicio de tiempo nativo): `SUPPORTED`. Windows (`get_windows_time_sync_status`,
W32Time): `SUPPORTED`.

# Supported architectures

Standalone y RAC (RAC es el caso de mayor criticidad — Clusterware puede degradar el cluster con
desync severo).

# Prerequisites

`os/discovery` ya ejecutado.

# Required evidence

- collector `get_time_sync_status`

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `chronyc tracking`/`sources`, `timedatectl`, W32Time query vía collector semántico.

# Forbidden operations

Nunca ejecuta `chronyc makestep`, nunca reinicia `chronyd`/`ntpd`/W32Time, nunca ajusta el reloj.

# Decision logic

1. Estado normalizado: `SYNCED|UNSYNCED|DEGRADED|UNKNOWN` (`# 41` del prompt).
2. `DEGRADED` = sincronizado pero con offset/jitter fuera de umbral saludable (nunca un umbral
   universal sin contexto — se compara contra el offset típico reportado por el propio `chronyc
   tracking`). `UNSYNCED` = sin fuente de tiempo válida.
3. `UNSYNCED`/`DEGRADED` en un nodo RAC → `HIGH`/`CRITICAL` — correlacionado con
   `oracle-rac-analyst` (Clusterware puede evictar un nodo por desync severo).

# Normal state

`SYNCED` con offset/jitter bajo en todos los nodos.

# Abnormal patterns

`UNSYNCED` o `DEGRADED`, especialmente en RAC o entre primary/standby de Data Guard.

# False positives

Offset pequeño y transitorio inmediatamente después de un reinicio del servicio de tiempo no es
un hallazgo — se correlaciona con el historial de `chronyc sources`, no sólo el estado
instantáneo.

# Correlation rules

Alimenta `os/rac-interconnect-awareness`, `os/dataguard-network-awareness`.

# Confidence model

`FACT` para estado leído directamente.

# Severity

`CRITICAL` si `UNSYNCED` en un nodo RAC; `HIGH` si `DEGRADED` en RAC; `MEDIUM`/`LOW` en
standalone.

# Output schema

```yaml
time_sync:
  service: chrony|ntpd|systemd-timesyncd|windows_time|solaris_time|unknown
  status: SYNCED|UNSYNCED|DEGRADED|UNKNOWN
  offset_ms: number|null
  findings: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
```

# Related skills

`os/rac-interconnect-awareness`, `os/dataguard-network-awareness`.

# Escalation

`UNSYNCED`/`DEGRADED` en RAC escala a `oracle-rac-analyst` inmediatamente.

# Manual remediation guidance

`manual_action` sugiere revisar configuración de `chrony.conf`/fuentes NTP — siempre
`NOT_EXECUTED`, nunca ejecuta `chronyc makestep`.

# Security

Sin datos sensibles.

# Tests

`tests/test_time_sync_status.sh`.

# Documentation requirements

Alimenta `time-sync.md`.

# Change history

v1.0.0 — Fase 9, creación inicial.
