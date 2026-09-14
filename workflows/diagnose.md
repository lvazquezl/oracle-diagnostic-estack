---
name: diagnose
version: 1.1.0
status: active
---

# Trigger/intent

Comando `/diagnose`. Punto de entrada genérico para un síntoma puntual reportado por el DBA en lenguaje natural, sin saber aún a qué dominio pertenece.

# Prerequisites

Target identificado y descripción del síntoma (`question` no vacío en el Task Package inicial).

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache válido.

# Minimum agents

`oracle-operations-orchestrator`, `oracle-discovery-analyst` (si aplica). Ningún especialista de dominio se activa automáticamente — este workflow existe precisamente para *decidir* cuál activar.

# Optional agents

Cualquiera del registro, según la clasificación del síntoma por el orquestador (ej. "lento" → `oracle-performance-analyst`; "no conecta" → `oracle-network-analyst`; "espacio" → `oracle-dba-analyst`/`capacity-analyst`). Escenarios Fase 4 (`# 43` del prompt de Fase 4): `rac` → `rac/troubleshooting`; `service`/`scan`/`listener`/`connection` → `network/troubleshooting`/`rac/troubleshooting` según si el síntoma es de conectividad o de recurso Clusterware; `interconnect` → `rac/interconnect`/`network/interconnect`; `asm` → `asm/troubleshooting`. Escenarios Fase 5 (`# 48` del prompt de Fase 5): `dataguard`/`transport`/`apply`/`lag`/`gap`/`broker`/`fsfo`/`switchover-readiness`/`failover-readiness` → `dataguard/troubleshooting`, que enruta al skill Data Guard específico. Escenarios Fase 6 (`# 43` del prompt de Fase 6): `cdb`/`pdb`/`pdb-open-state`/`pdb-service`/`pdb-temp`/`pdb-undo`/`plugin-violation`/`pdb-resource`/`pdb-rac-placement` → `multitenant/troubleshooting`, que enruta al skill Multitenant específico. Escenarios Fase 7 (`# 39` del prompt de Fase 7): `rman`/`backup-failure`/`backup-slow`/`channel-contention`/`fra-pressure`/`archivelog-backup-gap`/`controlfile-backup`/`snapshot-controlfile`/`sbt-media-manager`/`restore-readiness`/`recovery-readiness` → `rman/troubleshooting`, que enruta al skill RMAN específico (`rman/channel-contention`, `rman/fra-pressure`, `rman/archivelog-backup`, `rman/controlfile-backup`, `rman/snapshot-controlfile`, `rman/sbt-media-manager`, `rman/restore-readiness`, `rman/recovery-readiness` según el síntoma). Escenarios Fase 8 (`# 51` del prompt de Fase 8): `security`/`privilege-exposure`/`public-grants`/`account-posture`/`password-policy`/`password-profile`/`audit-gap`/`tde-posture`/`network-encryption`/`compliance-gap` → enrutan al skill Security específico (`security/powerful-privileges`, `security/public-grants`, `security/account-inventory`, `security/password-policy-strength`, `security/password-profiles`, `security/audit-configuration`, `security/tde-awareness`, `security/network-encryption`, `security/compliance-mapping` según el síntoma). No se crea un comando slash por cada código ORA/TNS/CRS/RMAN individual — la taxonomía vive en `knowledge/errors/{ora,tns,crs,rman}/`.

# Activation conditions

El orquestador mapea palabras clave/patrones del síntoma a dominios candidatos (ver `skills/core/environment-classification` y `skills/core/risk-classification`) y activa el mínimo conjunto de especialistas necesario para la primera pasada; si el resultado inicial no explica el síntoma, activa el siguiente dominio candidato en orden de probabilidad, no todos a la vez.

# Skills

`core/context-discovery`, `core/risk-classification`, `core/hypothesis-generation` (para armar la primera hipótesis de dominio antes de activar especialistas).

# Evidence required

Mínima al inicio (sólo discovery); el resto la determina el/los especialista(s) activado(s).

# Stop conditions

Si tras dos rondas de activación de especialistas ningún hallazgo se correlaciona con el síntoma reportado, el workflow escala a `incident-root-cause-analyst` en vez de seguir activando agentes al azar.

# Confidence threshold

Igual al general del stack — no se reporta `PROBABLE_CAUSE` sin correlación de al menos dos fuentes.

# Escalation

Automática a `incident-root-cause-analyst` si el síntoma persiste sin explicación tras la exploración inicial, o si el DBA indica que es un incidente en curso (en cuyo caso, ver `workflows/incident.md`).

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/` estándar.

# Token/context budget

Bajo al inicio, creciendo incrementalmente sólo con los dominios efectivamente activados — es, por diseño, el workflow más disciplinado en activación mínima.

# Security constraints

READ-ONLY ALWAYS. Identidad `ESTACK_DIAG_*`.

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml consultado ANTES de activar el especialista candidato del dominio clasificado
  architecture: si la clasificación del síntoma apunta a un dominio incompatible con la arquitectura detectada (ej. síntoma "RAC" sobre un target standalone), se declara UNSUPPORTED de inmediato en vez de activar el agente
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      si el dominio candidato es LICENSE_DEPENDENT y no se confirma, se activa igual con capability_status LICENSE_RESTRICTED y se busca alternativa (ver policies/licensing-awareness-policy.md)
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para la evidencia mínima del dominio candidato
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         queries cost_class HIGH no se activan en la primera pasada de /diagnose (exploración de bajo costo primero)
  evidence:     reutiliza evidencia ya recolectada en la sesión antes de pedir nueva
```
