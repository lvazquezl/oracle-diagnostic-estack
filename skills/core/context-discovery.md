---
name: context-discovery
id: core/context-discovery
version: 1.0.0
domain: core
status: active
---

# Purpose

Determinar y cachear la identidad mínima de un target (versión, topología, rol, tenancy, storage, OS) antes de permitir que cualquier skill de dominio ejecute análisis, evitando que un agente asuma comportamiento no válido para ese ambiente.

# Supported Oracle versions

10g, 11g, 12c, 18c, 19c, 21c, 23ai. Version-awareness: consulta primero `V$INSTANCE.VERSION`/`PRODUCT_COMPONENT_VERSION` y ajusta qué vistas adicionales son válidas.

# Supported OS/platforms

Todas las soportadas por el stack (Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server, HP-UX). El OS se detecta vía `get_os_cpu`/`get_os_memory` (metadata de plataforma en la respuesta), no vía comandos shell libres.

# Supported architectures

Standalone, RAC, RAC One Node, NON-CDB, CDB, PDB, ASM, Filesystem, Primary, Physical Standby, Active Data Guard. Este skill es el único responsable de clasificarlas — todo lo demás las consume por referencia.

# Prerequisites

Ninguno — es el primer skill que corre sobre un target nuevo o sin cache válido.

# Required evidence

- query_id: `Q-DISC-IDENTITY-001` (`get_database_identity`)
- query_id: `Q-DISC-INSTANCE-001` (`get_instance_status`)
- query_id: `Q-DISC-RAC-001` (`get_rac_topology`) — sólo si `Q-DISC-INSTANCE-001` indica RAC

# Optional evidence

- query_id: `Q-DISC-ASM-001` (`get_asm_usage`, sólo para confirmar presencia de ASM, no capacidad)

# Read-only operations

Lectura de `V$INSTANCE`, `V$DATABASE`, `V$PDBS`/`DBA_PDBS` (si aplica), `GV$INSTANCE` (si RAC), metadata de OS provista por el Gateway.

# Forbidden operations

No ejecuta ninguna operación de escritura. No infiere versión/rol a partir de heurísticas no confirmadas por diccionario — si la vista no responde, el dato queda `UNDETERMINED`, nunca se asume.

# Decision logic

1. Leer `V$INSTANCE.VERSION` y `DATABASE_ROLE` de `V$DATABASE` → determina versión y rol.
2. Si `V$INSTANCE.INSTANCE_NUMBER` + `GV$INSTANCE` tiene más de una fila para el mismo `DB_NAME` → `instance_mode = rac`; si no, `single`.
3. Leer `CDB` de `V$DATABASE` → `container_mode = cdb|non_cdb`; si `cdb`, listar `V$PDBS`.
4. Leer `V$ASM_DISKGROUP` (acceso concedido) → si responde, `storage_mode = asm`; si el acceso es denegado o vacío pero los datafiles están en filesystem, `storage_mode = filesystem`.
5. Combinar con metadata de OS del Gateway → `os_platform`.
6. Cualquier paso que no pueda confirmarse queda `UNDETERMINED` explícitamente, nunca se rellena con un valor por defecto.

# Confidence model

`FACT` cuando el dato viene directo de una vista de diccionario sin ambigüedad. `OBSERVATION` cuando proviene de un único indicador indirecto. `UNDETERMINED` cuando no hay evidencia suficiente — este skill nunca emite `HYPOTHESIS`/`PROBABLE_CAUSE`/`CONFIRMED_ROOT_CAUSE` (no es su función).

# Output schema

```yaml
findings:
  - product_version: string
    edition: string
    instance_mode: single|rac|rac_one_node
    container_mode: non_cdb|cdb
    pdbs: [string]
    database_role: primary|physical_standby
    storage_mode: asm|filesystem
    os_platform: string
    confidence: FACT|OBSERVATION|UNDETERMINED
    evidence_refs: [EVD-...]
```

# Related skills

`core/environment-classification`, `core/version-awareness`, `core/platform-awareness`.

# Escalation

Si tras las queries requeridas no se puede confirmar versión + rol + topología con al menos `OBSERVATION`, el skill devuelve `UNDETERMINED` global y el workflow que lo invocó debe detenerse (ver `workflows/*.md#stop-conditions`) en vez de continuar con especialistas de dominio.

# Data sensitivity

Baja — es metadata de identidad, no contenido de negocio. Hostnames/IPs se enmascaran igual que en cualquier otro skill según `sanitizers/data-classification-policy.md`.

# Context budget

Bajo: una ronda de queries de identidad, sin AWR/ASH ni evidencia de configuración profunda.

# Tests

`tests/test_version_awareness.sh`, `tests/test_rac_standalone_detection.sh`, `tests/test_cdb_pdb_detection.sh`, `tests/test_primary_standby_detection.sh`.

# Documentation requirements

Alimenta `context.md` del análisis con el bloque `findings` completo.

# Evolution via `/change`

Cambios (nuevas versiones/plataformas soportadas) vía `/change compatibility`; cambios de lógica de decisión vía `/change skill`.
