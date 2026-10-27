---
name: tde-awareness
id: security/tde-awareness
version: 1.1.0
domain: security
status: active
---

# Purpose

Determina en **toda revisión** (`/healthcheck`, `/assessment`, `/assessment security`) la **postura TDE** del ambiente: si TDE no está configurado, está configurado sin uso o está en uso, y si eso representa un **riesgo**, una **mala configuración**, una **propuesta de mejora** o una **revisión de licencia**. Leer el estado no requiere licencia: el paso corre aunque la opción no esté licenciada (`CHG-ESTACK-TDE-POSTURE-001`). Nunca ejecuta `OPEN/CLOSE KEYSTORE`, `SET KEY`, `ROTATE KEY`, `CREATE KEYSTORE` (`# 31` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai (wallet awareness 11.2+; column encryption 10.2+).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-TDE-WALLET-001` (estado, tipo, orden, modo unido/aislado y respaldo del keystore por contenedor)
- `Q-SEC-ENCRYPTED-TABLESPACES-001` (tablespaces cifrados o no, y algoritmo)
- `Q-SEC-ENCRYPTED-COLUMNS-001` (columnas cifradas por dueño y algoritmo)
- `Q-SEC-TDE-MASTER-KEYS-001` (12.1+: llaves maestras, sin respaldo y horas desde la activación más reciente)
- `Q-SEC-SECURITY-PARAMETERS-001` (`encrypt_new_tablespaces`, `wallet_root`, `tde_configuration`)

# Optional evidence

`security/tablespace-encryption`, `security/keystore-awareness`; `Target Profile.security.encryption_required` y `security.tde_key_rotation_hours` (por defecto 8760 h, un año) cuando el DBA los declara.

# Licensing requirements

**Ninguna para este skill**: las 5 lecturas tienen `license_requirements: none`, y una capability de postura TDE nunca se marca `LICENSE_RESTRICTED`. **Usar** TDE (cifrar datos) requiere Advanced Security Option fuera de los servicios cloud de Oracle que la incluyen: cuando la postura es `IN_USE` se emite `TDE-12` (`LICENSE_REVIEW`), sin afirmar nunca que esté o no licenciado (`policies/licensing-awareness-policy.md`).

# Query IDs

`Q-SEC-TDE-WALLET-001`, `Q-SEC-ENCRYPTED-TABLESPACES-001`, `Q-SEC-ENCRYPTED-COLUMNS-001`, `Q-SEC-TDE-MASTER-KEYS-001`, `Q-SEC-SECURITY-PARAMETERS-001`.

# Collector IDs

Los mismos IDs en el gateway (`diagnostics.collect`).

# Read-only operations

Lectura de `V$ENCRYPTION_WALLET`, `V$ENCRYPTED_TABLESPACES`, `CDB_TABLESPACES`/`DBA_TABLESPACES`, `CDB_ENCRYPTED_COLUMNS`/`DBA_ENCRYPTED_COLUMNS`, `V$ENCRYPTION_KEYS` (agregada) y `V$PARAMETER`.

# Forbidden operations

Nunca `ADMINISTER KEY MANAGEMENT` en ninguna variante.

# Decision logic

**1. Clasificación por contenedor** (`con_id`; en non-CDB o 11.2, una sola):

| Postura | Condición |
|---|---|
| `NOT_APPLICABLE` | 10.2–11.1: no existe `V$ENCRYPTION_WALLET`; solo se evalúan columnas cifradas |
| `NOT_CONFIGURED` | keystore `status` `NOT_AVAILABLE`, sin llaves maestras, sin tablespaces ni columnas cifradas, `wallet_root` y `tde_configuration` en default |
| `CONFIGURED_NOT_IN_USE` | hay keystore (`status` distinto de `NOT_AVAILABLE`, llaves maestras o `wallet_root`/`tde_configuration` configurados) pero ningún tablespace ni columna cifrada |
| `IN_USE` | al menos un tablespace `ENCRYPTED` o una columna cifrada |

La postura global es la más alta de los contenedores (`IN_USE` > `CONFIGURED_NOT_IN_USE` > `NOT_CONFIGURED`), y se reporta también por contenedor.

**2. Hallazgos.** Cada uno lleva `category` (`RISK`, `MISCONFIGURATION`, `IMPROVEMENT`, `LICENSE_REVIEW`), `severity` y las referencias `EVD-*` de las filas que lo sostienen:

| Código | Condición | Categoría | Severidad |
|---|---|---|---|
| `TDE-01` | Contenedor con datos cifrados y keystore `CLOSED`, `NOT_AVAILABLE`, `OPEN_NO_MASTER_KEY` u `OPEN_UNKNOWN_MASTER_KEY_STATUS`: esos datos no se pueden leer | RISK | CRITICAL |
| `TDE-02` | `IN_USE` o `CONFIGURED_NOT_IN_USE` con `fully_backed_up` `NO` o `keys_not_backed_up` > 0: perder el keystore es perder los datos | RISK | HIGH |
| `TDE-03` | `IN_USE` con `wallet_type` `PASSWORD`: tras cada reinicio los datos cifrados no están disponibles hasta abrir el keystore a mano | RISK | MEDIUM |
| `TDE-04` | `wallet_type` `AUTOLOGIN` (no `LOCAL_AUTOLOGIN`): el keystore abre en cualquier host donde se copie | IMPROVEMENT | LOW |
| `TDE-05` | `hours_since_last_activation` mayor que `tde_key_rotation_hours` (8760 por defecto): llave maestra sin rotar | IMPROVEMENT | MEDIUM |
| `TDE-06` | Algoritmo `3DES168` en tablespaces o columnas: algoritmo obsoleto; `AES128` se reporta como mejora opcional hacia `AES256` | IMPROVEMENT | MEDIUM (`3DES168`) / LOW (`AES128`) |
| `TDE-07` | `encryption_required: true` en el Target Profile y tablespaces `UNENCRYPTED` en un contenedor con datos de aplicación (lo resuelve `security/tablespace-encryption`) | MISCONFIGURATION | HIGH |
| `TDE-08` | CDB con `keystore_mode` mixto (`UNITED` e `ISOLATED`) o un PDB con datos cifrados y keystore en otro estado que el root. `NONE` en el root (`con_id` 1) o en un non-CDB es lo normal y no cuenta como mezcla | MISCONFIGURATION | MEDIUM |
| `TDE-09` | `IN_USE` con `encrypt_new_tablespaces` distinto de `ALWAYS` y `encryption_required: true`: los tablespaces nuevos pueden nacer sin cifrar | IMPROVEMENT | LOW |
| `TDE-10` | 18c+ con keystore y `wallet_root` en default: el keystore se ubica por `sqlnet.ora` (`ENCRYPTION_WALLET_LOCATION`, método heredado); conviene migrar a `WALLET_ROOT` + `TDE_CONFIGURATION` | IMPROVEMENT | LOW |
| `TDE-11` | `NOT_CONFIGURED`: los datos en reposo, los respaldos y los archivos de datos copiados quedan legibles fuera de la base. Se propone evaluar TDE según la clasificación de datos | IMPROVEMENT | INFO; MEDIUM si el Target Profile declara datos sensibles; si `encryption_required: true`, aplica `TDE-07` |
| `TDE-12` | `IN_USE`: usar TDE requiere Advanced Security Option fuera de los servicios cloud de Oracle que la incluyen. `LICENSE_CHECK_REQUIRED`, sin afirmar cobertura | LICENSE_REVIEW | MEDIUM |
| `TDE-13` | `CONFIGURED_NOT_IN_USE`: keystore mantenido sin datos cifrados (despliegue incompleto o residuo); confirmar la intención con el DBA | MISCONFIGURATION | LOW |

**3. Lo que no se observa y se declara como limitación:** la ubicación y los permisos del keystore en el SO, la copia del keystore en un standby de Data Guard (si hay Data Guard y `IN_USE`, se recomienda verificarla), el cifrado de los respaldos RMAN y `sqlnet.ora`. Nunca se infiere su estado.

**4. Sin evidencia:** si un collector de la postura no corre (privilegios, versión), la postura queda `UNDETERMINED` con su `capability_status`; nunca se reporta `NOT_CONFIGURED` por falta de datos.

**5. Versiones:** en 10.2–11.1, `NOT_APPLICABLE` para tablespaces y keystore (`capability_status: UNSUPPORTED`); en 11.2 no hay `con_id`, `wallet_type` ni llaves maestras (`TDE-02` usa solo lo observable; `TDE-03`, `TDE-04` y `TDE-05` quedan `NOT_ASSESSED`); `keystore_mode` desde 12.2.

# Normal state

`NOT_CONFIGURED` con la mejora `TDE-11` documentada, o `IN_USE` con keystore `OPEN` en todos los contenedores con datos cifrados, respaldado (`fully_backed_up` `YES`), llave maestra rotada dentro de la política y algoritmo AES.

# Abnormal patterns

Cualquier hallazgo `RISK` (`TDE-01`, `TDE-02`, `TDE-03`) o `MISCONFIGURATION` (`TDE-07`, `TDE-08`, `TDE-13`).

# False positives

- `SYSTEM`, `SYSAUX`, `TEMP` y `UNDO` sin cifrar no son anómalos por sí solos: desde 12.2 los datos de tablespaces cifrados también van cifrados en `TEMP`, `UNDO` y redo. Los nombres salen enmascarados; el DBA mapea los tokens.
- `wallet_type` `UNKNOWN` con `status` `NOT_AVAILABLE` es el estado normal de `NOT_CONFIGURED`.

# Correlation rules

Integra `security/keystore-awareness` (tipo y modo del keystore) y `security/tablespace-encryption` (`TDE-07`). Alimenta `security/security-healthcheck`, `security/compliance-mapping` y `security/licensing-gates` (`TDE-12`). Con Data Guard, deriva a `oracle-dataguard-analyst` la verificación del keystore en el standby.

# Confidence model

`FACT` para la postura y los estados observados; las mejoras (`IMPROVEMENT`) son recomendaciones, no fallas. Sin validación en campo para el contexto, la confianza no supera `PROBABLE_CAUSE`.

# Severity

La de la tabla de hallazgos. La severidad global de la postura es la mayor de sus hallazgos.

# Output schema

```yaml
tde:
  posture: NOT_APPLICABLE|NOT_CONFIGURED|CONFIGURED_NOT_IN_USE|IN_USE|UNDETERMINED
  per_container: [{con_id: int, posture: string, keystore_status: string, wallet_type: string|null,
                   keystore_mode: string|null, encrypted_tablespaces: int, encrypted_columns: int,
                   master_keys: int|null, hours_since_last_activation: number|null}]
  findings: [{code: TDE-01..TDE-13, category: RISK|MISCONFIGURATION|IMPROVEMENT|LICENSE_REVIEW,
              severity: CRITICAL|HIGH|MEDIUM|LOW|INFO, con_id: int|null, evidence_refs: [EVD-...]}]
  not_observable: [keystore_os_location, standby_keystore_copy, rman_backup_encryption, sqlnet_ora]
  license: {reading: none, use: LICENSE_CHECK_REQUIRED|NOT_APPLICABLE}
  evidence_refs: [EVD-...]
```

# Related skills

`security/keystore-awareness`, `security/tablespace-encryption`, `security/licensing-gates`.

# Escalation

`TDE-01` en producción → `incident-root-cause-analyst`. Las mejoras y las mala configuraciones van a `change-advisor` como propuestas de ejecución humana.

# Manual remediation guidance

Solo texto, siempre `NOT_EXECUTED` y para ejecución del DBA, con su reverso y ventana. Ejemplos: abrir el keystore (`ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN ...`), respaldarlo (`... BACKUP KEYSTORE ...`), rotar la llave maestra (`... SET KEY ... WITH BACKUP`), crear un keystore `LOCAL_AUTOLOGIN`, migrar a `WALLET_ROOT`/`TDE_CONFIGURATION`, cifrar un tablespace en línea (`ALTER TABLESPACE ... ENCRYPTION ONLINE ...`). La contraseña del keystore nunca se pide ni se guarda; en el texto va como marcador.

# Security

`wrl_parameter` (ruta del keystore) no se selecciona; `wallet_root` solo sale como configurado o no. `key_id`, `tag`, creador y fechas de las llaves nunca salen de la base. Nunca contraseña ni material de llave.

# Tests

`tests/test_tde_awareness.sh`, `tests/test_tde_posture.sh`, `tests/test_no_keystore_change.sh`, `tests/test_no_tde_key_rotation.sh`, `tests/p18/check_collector_factory.py` (`tde_posture_…`).

# Documentation requirements

Alimenta la sección **Postura de cifrado (TDE)** de todo análisis (`analysis/ANA-*/encryption-posture.md` o la sección equivalente de `analysis.md`), siempre presente, aunque la postura sea `NOT_CONFIGURED`.

# Change history

v1.0.0 — Fase 8, creación inicial.

v1.1.0 — `CHG-ESTACK-TDE-POSTURE-001`: postura TDE obligatoria en toda revisión, sin licencia para leer; clasificación por contenedor; hallazgos `TDE-01`..`TDE-13` (riesgo, mala configuración, mejora, revisión de licencia); evidencia de llaves maestras y parámetros del keystore.
