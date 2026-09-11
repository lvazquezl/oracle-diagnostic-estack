# RMAN — RAC / Data Guard / Multitenant Integration — Fase 7

## Principio

> RAC, Data Guard, Multitenant, ASM, Performance, OS and Network agents are activated only when backup/recovery evidence requires cross-domain correlation.

`oracle-backup-recovery-analyst` no activa todos los agentes de dominio por defecto — sólo delega cuando la evidencia específica lo requiere (mismo principio que Multitenant/Data Guard, `# 30` del prompt de Fase 7).

## RAC (`rman/rac-awareness`)

- RMAN configuration es a nivel database (no por instancia), salvo canales `CONNECT` específicos de instancia.
- Un backup ejecutado desde una sola instancia es válido — nunca se asume que todos los nodos deben participar en cada backup (`# 22`).
- `rman/snapshot-controlfile` da atención especial a `ORA-00245` (snapshot controlfile no accesible desde todas las instancias) cuando el path configurado no es ASM ni cluster filesystem compartido.
- `rman/channels`/`rman/channel-contention` correlacionan distribución de canales con `oracle-rac-analyst` cuando hay desbalance sostenido entre instancias.

## Data Guard (`rman/dataguard-awareness`)

- Distingue backup en primary, backup en standby (offload), `ARCHIVELOG DELETION POLICY` consciente de standby (`TO APPLIED ON [ALL] STANDBY`), disponibilidad de standby.
- Nunca ejecuta standby recovery.
- Nunca asume transportabilidad/uso de backup entre roles (primary↔standby) sin evidencia directa de topología/DBID compartido — delega a `oracle-dataguard-analyst` para esa confirmación.
- `rman/fra-pressure` correlaciona presión de FRA con apply lag en standby cuando la deletion policy retiene archivelogs hasta confirmación de aplicación.

## Multitenant (`rman/multitenant-awareness`, `rman/pdb-pitr-awareness`)

- Distingue CDB backup (`CON_ID=1`, cubre toda la CDB incl. todas las PDBs sin necesidad de filas `CON_ID=n` individuales), cobertura de datafile por PDB, PDB PITR, scope de controlfile/archivelog (siempre CDB-wide, nunca por PDB).
- Nunca trata una PDB como base de datos física independiente (`# 29`).
- PDB-level RMAN backup/restore existe desde 12.1 con mejoras en 12.2 — sin evidencia certificada del detalle completo por versión, `capability_status: PARTIALLY_SUPPORTED`.
- `rman/pdb-pitr-awareness` delega a `oracle-multitenant-analyst` para contexto de topología/local undo antes de afirmar viabilidad de un PDB PITR.

## ASM / Performance / OS / Network — sólo cuando hay evidencia

```text
ASM:          FRA/backup destination/restore destination — capacidad de diskgroup subyacente.
              Nunca se infiere causa ASM sólo por presión de FRA lógica.
Performance:  CPU/I/O/compresión/contención de workload durante duración/throughput degradados.
              Nunca se infiere root cause por una sola métrica.
OS:           filesystem/proceso/I/O/mount NFS/proceso de media manager.
Network:      SBT/media server/NFS/conectividad de Recovery Catalog.
              Nunca se diagnostica red sin evidencia.
```

## Reglas de no-inferencia

- Channel contention nunca asume causa Oracle única — correlaciona RMAN parallelism, concurrencia de media manager, límites de servidor, pools SBT, política del vendor (Commvault/Simpana u otro) y job scheduler (`# 23`).
- Ningún agente cross-domain se activa "por si acaso" — la delegación siempre está condicionada a evidencia específica (`routing.yaml#activation_conditions`/`collaboration.yaml#escalation_conditions`).
