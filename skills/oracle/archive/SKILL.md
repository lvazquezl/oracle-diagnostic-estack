---
name: archive
display_name: "Archive Configuration"
id: oracle/archive
version: 1.0.0
domain: oracle
status: active
---

# Purpose

Evaluar configuración de archivelog: modo (`ARCHIVELOG`/`NOARCHIVELOG`), destinos configurados y su estado, y gaps básicos de archivado local — sin profundizar en Data Guard (destinos remotos se detectan, no se analizan en profundidad).

# Scope

**En alcance:** modo de archivado, destinos locales/remotos configurados (`LOG_ARCHIVE_DEST_n`) y su estado (`VALID`/`ERROR`), espacio del área de archivado local. **Fuera de alcance:** apply de Data Guard, gap resolution, FRA sizing detallado (eso es `rman/fra`, no profundizado en Fase 2 — aquí sólo se reporta el estado que `V$ARCHIVE_DEST_STATUS` expone).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (cada thread archiva su propio redo). NON-CDB y CDB. ASM y Filesystem. Primary (foco principal).

# Prerequisites

Target Profile publicado (`log_mode` ya disponible ahí).

# Required evidence

- `Q-ORA-ARCHIVE-001`

# Optional evidence

Ninguna (gap detection profundo pertenece a `dataguard/archive-gap`, no profundizado en Fase 2).

# Data collection

`V$ARCHIVE_DEST` (configuración), `V$ARCHIVE_DEST_STATUS` (estado: `VALID`, `ERROR`, `DISABLED`), `V$ARCHIVED_LOG` (últimos archivados, para confirmar actividad reciente).

# Diagnostic logic / Decision tree

```text
IF log_mode = NOARCHIVELOG AND environment_class = producción (config/allowed-targets.local.yaml)
   → finding HIGH (sin archivado, sin recuperabilidad point-in-time)
Para cada destino habilitado:
  IF status = 'ERROR' → finding HIGH (archivado a ese destino está fallando activamente)
  IF status = 'DISABLED' AND parecía ser el destino primario esperado → finding MEDIUM
IF no hay actividad de archivado reciente en V$ARCHIVED_LOG a pesar de log_mode = ARCHIVELOG
   → finding MEDIUM (posible estancamiento)
```

# Normal behavior

`ARCHIVELOG` en producción, al menos un destino local `VALID`, actividad de archivado consistente con la frecuencia de log switches (`oracle/redo`).

# Abnormal patterns

Destino en `ERROR` (típicamente por espacio agotado en el destino o problema de permisos/red si es remoto); `NOARCHIVELOG` en un ambiente que debería tener recuperabilidad.

# Root cause patterns

`ORA-16038`/archiver stuck correlacionado con un destino en `ERROR` por espacio agotado — causa confirmable directamente cruzando `V$ARCHIVE_DEST_STATUS.ERROR` con el mensaje específico.

# Correlation rules

Cruzar con `oracle/redo` (frecuencia de switch) y con espacio de FRA/filesystem (`os-platform-analyst`, fases futuras) para el destino local.

# False positives

`NOARCHIVELOG` en un ambiente explícitamente de desarrollo/laboratorio (`environment_class` declarado) es normal, no un finding `HIGH` — se reporta como informativo `LOW`.

# Confidence model

`FACT` para modo y estado de destinos. `PROBABLE_CAUSE` para "archiver stuck por espacio agotado" sólo si el mensaje de error específico lo confirma, no por inferencia.

# Findings

```yaml
finding_id: FND-...
category: archive
severity: LOW|MEDIUM|HIGH
title: string
observation: string
evidence_refs: [EVD-...]
confidence: FACT|PROBABLE_CAUSE
impact: string
recommendations: [REC-...]
```

# Recommendations

Liberar espacio en el destino de archivado o ampliar el área; habilitar `ARCHIVELOG` si el ambiente lo requiere y no lo tiene — ambas `manual_execution_required: true`, la segunda de alto impacto (requiere shutdown/mount, se marca como tal).

# DBA commands / prechecks / rollback / postchecks

```text
NOT_EXECUTED / HUMAN_REVIEW_REQUIRED
precheck:   confirmar espacio disponible en el nuevo destino / backup reciente antes de cambiar log_mode
command:    -- liberar destino con error: gestión externa de espacio (fuera del alcance del e-stack)
            -- habilitar archivelog: SHUTDOWN IMMEDIATE; STARTUP MOUNT; ALTER DATABASE ARCHIVELOG; ALTER DATABASE OPEN;
expected_result: V$ARCHIVE_DEST_STATUS vuelve a VALID / log_mode = ARCHIVELOG confirmado
rollback:   ALTER DATABASE NOARCHIVELOG (mismo procedimiento de mount) si el cambio de modo no era deseado
postcheck:  Q-ORA-ARCHIVE-001 re-ejecutada confirma estado esperado
```

# Version differences

Sin diferencias estructurales relevantes 10g–23ai.

# RAC considerations

Cada thread (instancia) archiva independientemente — un destino en `ERROR` puede afectar sólo a una instancia si la configuración no es idéntica entre nodos (verificar consistencia es responsabilidad cruzada con `oracle/parameters`).

# Multitenant considerations

El archivado es a nivel CDB, no por PDB — no varía por contenedor.

# Standby considerations

`V$ARCHIVE_DEST_STATUS` en un Physical Standby refleja los destinos configurados para ese sitio (que pueden incluir un destino de re-transmisión) — este skill lo reporta igual, sin asumir que el standby no archiva.

# Security

Read-only, `SELECT` sobre `V$ARCHIVE_DEST*`/`V$ARCHIVED_LOG`. Rutas de destino remoto pueden revelar topología — enmascaradas según política.

# Licensing

No depende de ninguna feature licenciada.

# Related skills

`oracle/redo`, `oracle/controlfile`.

# Escalation

Un destino en `ERROR` sostenido escala a `incident-root-cause-analyst` si coincide con síntomas reportados (ej. la base se detiene por archiver stuck). Gaps y destinos remotos Data Guard-specific escalan (como `capability_status: UNSUPPORTED` por ahora) hacia `oracle-dataguard-analyst` en fases futuras.

# Examples

Ver `tests/fixtures/19c-physical-standby.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (rutas/hosts de destino remoto); presupuesto bajo.

# Tests

`tests/test_oracle_core_archive.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 2 (Oracle Core) | Creado. |
