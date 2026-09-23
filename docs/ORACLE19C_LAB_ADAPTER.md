# Adaptador `oracle_sql` de laboratorio — Oracle Database 19c sobre Oracle Linux 8.10

**Cambio:** `CHG-ESTACK-ORA19C-LAB-001` (`/change security|compatibility`) · **Rama:** `feature/oracle19c-readonly-lab` · **Estado:** aprobado (conversacional) e integrado a `main` vía PR #3 (`7eb585f`), versión `0.15.0`. La gobernanza de la §10 sigue pendiente.

> **Esto no es preparación para producción.** Un `check` exitoso contra el laboratorio demuestra que el camino de lectura funciona contra *un* target no productivo. El release gate de Fase 14 sigue calculando `READY_FOR_REAL_ENVIRONMENT_PILOT = NO`, y así debe quedar hasta que se complete la revisión humana y exista un registro de piloto (ver [PILOT_ACCEPTANCE_CHECKLIST.md](PILOT_ACCEPTANCE_CHECKLIST.md)).

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY — sin cambios en ninguna de las dos políticas.

## 1. Alcance

| Elemento | Alcance de este cambio |
|---|---|
| Target | **Uno solo**, Oracle 19c no productivo (`environment_class: NON_PRODUCTION`) |
| Colectores | `Q-DISC-IDENTITY-001` (variante V3 `modern_18plus`, hash verificado). Desde `CHG-ESTACK-ORA19C-LAB-002`: `Q-ORA-RESOURCE-LIMITS-001` (variante implícita). Desde `CHG-ESTACK-ORA19C-LAB-003` (`0.16.0`): `Q-CDB-TABLESPACES-001` (sólo `CDB_ROOT`) y `Q-RMAN-FRA-USAGE-001`. Desde `CHG-ESTACK-ORA19C-LAB-004` (propuesto): `Q-RMAN-BACKUP-FRESHNESS-001` y `Q-RMAN-JOB-SUMMARY-001` — ver [ORACLE19C_LAB_RMAN.md](ORACLE19C_LAB_RMAN.md) — ver [ORACLE19C_LAB_DOMAINS.md](ORACLE19C_LAB_DOMAINS.md), sólo si el targets file privado los lista — ver [ORACLE19C_LAB_COLLECTORS.md](ORACLE19C_LAB_COLLECTORS.md) |
| Cuenta | Usuario diagnóstico dedicado: `CREATE SESSION` + `SELECT` sobre `V_$INSTANCE` y `V_$DATABASE` |
| Secreto | Keychain de macOS (`/usr/bin/security`), leído en cada conexión; nunca en prompts, Git, variables de entorno ni archivos compartidos |
| Driver | `python-oracledb` en modo **thin** (nunca `init_oracle_client`) |
| Transporte | `tcp` o `tcps`, declarado explícitamente en el perfil según lo que autorice la organización |
| Runtime por defecto | **Sin cambios**: `python -m mcp_gateway` sigue en modo fixture y `oracle_sql = DISABLED` |

Fuera de alcance: más targets, colectores distintos de los anteriores, `oracle_diag_file`, `os_readonly`, modo thick, Native Network Encryption, pooling, producción.

## 2. Arquitectura

```
Claude Code ──stdio MCP──▶ python -m mcp_gateway_lab serve
                              │  (mismas 5 tools estáticas; sin SQL/DSN/paths en argumentos)
                              ▼
                         mcp_gateway.Gateway ── autorización por target/colector/versión/rol/budget
                              │
                              ▼
                  mcp_gateway_lab.OracleSqlAdapter (LAB_ENABLED)
                    1. perfil: target único, autorización humana vigente, colector implementado
                    2. lock no bloqueante (concurrencia 1)
                    3. SQL certificado re-leído + SHA-256 == catálogo; variante por versión
                    4. Keychain → connect thin (sin reintentos, timeouts acotados)
                    5. SET TRANSACTION READ ONLY → guardas de sesión y privilegios
                    6. identidad: servicio, versión, rol, contenedor, db_name
                    7. límites de filas/bytes/tipos → minimización de columnas
                    8. rollback + close (siempre)
                              │ filas NO confiables
                              ▼
                  mcp_gateway.evidence.sanitize_rows (MASK/KEEP/DROP, default deny)
                              ▼
                  sobre sanitizado + EVR-* opaco, provenance REAL
```

- **Paquete separado.** `mcp_gateway/` sigue siendo stdlib-only y no importa `mcp_gateway_lab` ni `oracledb` (lo verifican `tests/p13`, `tests/p14` y `tests/p15`). El adaptador real sólo entra por `AdapterRegistry(extra=...)` desde el lanzador de laboratorio.
- **Nuevo estado `LAB_ENABLED`.** No es `VERIFIED_LAB` a propósito: `VERIFIED_LAB` equivale a `PILOT_VALIDATED` en el registro de Fase 14 y sería una afirmación falsa.
- **Procedencia honesta.** En modo laboratorio, las instrucciones MCP y las descripciones de tools ya no dicen "synthetic"; cada respuesta declara `provenance.kind` `FIXTURE` o `REAL`, también en `get_evidence` y `analyze_incident`.

## 3. Controles de seguridad

| Control | Dónde | Prueba |
|---|---|---|
| Sin SQL/shell/lectura de archivos genérica: tools estáticas, `additionalProperties: false` | `mcp_gateway/gateway.py` | `tool_arguments_cannot_carry_sql_connection_or_paths` |
| Sólo SQL certificado (hash verificado en cada llamada) + 3 sentencias de guarda constantes | `sqlsource.py`, `oracle_sql.py` | `only_certified_and_guard_sql_is_executed…`, `a_certified_query_changed_after_startup…` |
| Transacción de sólo lectura, nunca `commit`, `rollback`+`close` siempre | `oracle_sql.py` | ídem + mutación `commit instead of rollback` |
| Target autorizado: perfil con un solo target, `NON_PRODUCTION`, autorización ≤ 90 días, revalidada en cada llamada | `profile.py`, `oracle_sql.py` | `profile_structure_scope_and_limits_fail_closed`, `authorization_expiring_during_the_session…` |
| Validación post-conexión: servicio, versión 19c, rol, contenedor (`NON_CDB`/`CDB_ROOT`/`PDB` + `CON_NAME`), `db_name` | `oracle_sql.py` | `connected_identity_must_match…`, `pdb_container_name_mismatch…` |
| Cuenta no privilegiada: `ISDBA=FALSE`, no es cuenta mantenida por Oracle, privilegios de sistema ⊆ permitidos | `oracle_sql.py` | `privileged_or_over_granted_sessions…` |
| Límites: tiempo (connect, `call_timeout` y deadline global), filas (`fetchmany(n+1)`), bytes, tipos escalares, longitud de valor, concurrencia 1 | `oracle_sql.py`, `adapters.run_with_timeout` | `a_hung_query_times_out…`, `non_scalar_oversized…`, `call_timeouts_never_exceed…` |
| Minimización + sanitización antes del modelo (`instance_name`/`db_name` MASK) | `oracle_sql._minimize`, `evidence.sanitize_rows` | `identity_collection_returns_real_sanitized_evidence`, `undeclared_columns…` |
| Secreto: Keychain con argv fijo, sin shell, entorno mínimo; nunca en perfil, env, logs ni errores | `credentials.py` | `keychain_lookup_uses_a_fixed_argv…`, `keychain_failures_fail_closed…`, `driver_errors_never_leak…` |
| Perfil privado: absoluto, regular, no symlink, del usuario, `chmod 600`, fuera del repo, sin llaves de secreto | `profile.py` | `profile_file_must_be_private…`, `profile_with_a_secret…` |
| Modo thin obligatorio | `cli._load_driver`, `oracle_sql.py` | `thick_mode_is_refused` |
| CLI sin flags de conexión/SQL/secreto; variables de entorno no cambian nada; errores con texto fijo | `cli.py` | `lab_cli_has_no_connection…`, `startup_refusals_are_fixed_text…` |

Mutaciones verificadas manualmente (cada una hace fallar al menos una prueba): quitar la verificación de privilegios, de `db_name`, de versión, la transacción de sólo lectura, el lock, el límite de bytes o la autorización en runtime, y reemplazar `rollback` por `commit`.

## 4. Aprovisionamiento del usuario diagnóstico (ejecución humana del DBA)

El e-stack **no ejecuta** estas sentencias. El DBA las revisa y las ejecuta a mano en el laboratorio. Para un **PDB**, conéctate primero al PDB (`ALTER SESSION SET CONTAINER = <PDB>;` como usuario administrativo); para **non-CDB**, ejecútalas directamente.

```text
-- SQL*Plus / SQLcl, como usuario administrativo, SÓLO en el laboratorio no productivo
ACCEPT diag_pw CHAR PROMPT 'Password para ESTACK_DIAG: ' HIDE

CREATE PROFILE ESTACK_DIAG_PROF LIMIT
  SESSIONS_PER_USER 2  IDLE_TIME 15  CONNECT_TIME 60
  FAILED_LOGIN_ATTEMPTS 5  PASSWORD_LOCK_TIME 1  PASSWORD_LIFE_TIME 90;

CREATE USER ESTACK_DIAG IDENTIFIED BY "&&diag_pw"
  PROFILE ESTACK_DIAG_PROF
  DEFAULT TABLESPACE USERS QUOTA 0 ON USERS;

GRANT CREATE SESSION TO ESTACK_DIAG;
GRANT SELECT ON SYS.V_$INSTANCE TO ESTACK_DIAG;
GRANT SELECT ON SYS.V_$DATABASE TO ESTACK_DIAG;
UNDEFINE diag_pw
```

Para los colectores de `CHG-ESTACK-ORA19C-LAB-002` hace falta además `GRANT SELECT ON SYS.V_$RESOURCE_LIMIT` (ver [ORACLE19C_LAB_COLLECTORS.md §9](ORACLE19C_LAB_COLLECTORS.md#9-pasos-humanos-para-usarlo-en-el-lab-no-los-ejecuta-el-e-stack)). Sin el grant, el colector falla cerrado con `MISSING_OBJECT_PRIVILEGE`.

No otorgues roles (`DBA`, `SELECT_CATALOG_ROLE`, `RESOURCE`…) ni `SELECT ANY DICTIONARY` salvo decisión explícita; el adaptador rechaza la sesión si aparece cualquier privilegio de sistema fuera de lo que declara el perfil (techo: `CREATE SESSION`, `SELECT ANY DICTIONARY`).

Verificación (como `ESTACK_DIAG`) — también te da los valores exactos para `expected` en el perfil:

```sql
SELECT privilege FROM session_privs;                                  -- esperado: sólo CREATE SESSION
SELECT SYS_CONTEXT('USERENV','SERVICE_NAME') AS service_name,
       SYS_CONTEXT('USERENV','CON_NAME')     AS con_name FROM dual;
SELECT i.version_full, d.name AS db_name, d.database_role, d.cdb, d.open_mode
FROM   v$instance i, v$database d;
```

## 5. Instalación y configuración en macOS

Todos los comandos se ejecutan desde el checkout, en la rama `feature/oracle19c-readonly-lab`.

```bash
cd ~/Projects/oracle-diagnostic-estack
git switch feature/oracle19c-readonly-lab

# 5.1 Driver (sólo en el venv del proyecto; versión con la que se construyó y probó el adaptador)
python3 -m venv .venv                        # si aún no existe
.venv/bin/python -m pip install "oracledb==26.0.1"
.venv/bin/python -c "import oracledb; print(oracledb.__version__, oracledb.is_thin_mode())"   # 26.0.1 True

# 5.2 Secreto en Keychain (pide el password de forma interactiva; no queda en el historial)
security add-generic-password -s oracle-estack-lab -a lab-ol8-19c -T /usr/bin/security -U -w
security find-generic-password -s oracle-estack-lab -a lab-ol8-19c >/dev/null && echo "keychain item OK"

# 5.3 Configuración privada, fuera del repositorio
install -d -m 700 "$HOME/.config/oracle-diagnostic-estack"
install -m 600 mcp_gateway_lab/examples/lab-profile.example.json "$HOME/.config/oracle-diagnostic-estack/lab-profile.json"
install -m 600 mcp_gateway_lab/examples/targets.lab.example.json "$HOME/.config/oracle-diagnostic-estack/targets.lab.json"
${EDITOR:-vi} "$HOME/.config/oracle-diagnostic-estack/lab-profile.json"    # reemplaza cada <...>
${EDITOR:-vi} "$HOME/.config/oracle-diagnostic-estack/targets.lab.json"    # container = expected.container
```

Campos del perfil que debes completar:

- `connection.host`, `connection.port`, `connection.service_name`: los mismos que usaste en tu prueba independiente con `python-oracledb`.
- `connection.transport`: `tcp`, o `tcps` si la organización exige TLS (opcional: `"tcps": {"wallet_location": "/ruta/absoluta", "server_cert_dn": "CN=..."}`). Si la organización exige **Native Network Encryption**, el modo thin no la soporta (categoría `NATIVE_NETWORK_ENCRYPTION_NEEDS_THICK_MODE`): detente y escala; no está en el alcance.
- `expected.container`: `NON_CDB`, `PDB` (requiere `expected.con_name`) o `CDB_ROOT`. `expected.db_name` es `V$DATABASE.NAME` (en un PDB, el nombre del CDB).
- `authorization`: rol del aprobador, `change_ref`, ventana UTC vigente de hasta 90 días. Al vencer, el adaptador deja de conectarse.

Si `SYS_CONTEXT('USERENV','SERVICE_NAME')` devuelve un nombre distinto del que usas para conectarte (por ejemplo, con dominio), declara `expected.service_name` con el valor observado.

## 6. Prueba

```bash
LAB="$HOME/.config/oracle-diagnostic-estack"

# 6.1 Validación offline (no conecta)
.venv/bin/python -m mcp_gateway_lab validate-config --targets "$LAB/targets.lab.json" --lab-profile "$LAB/lab-profile.json"

# 6.2 Smoke test real: UNA colección por el camino completo del gateway; imprime sólo el sobre sanitizado
EVD="$HOME/.local/share/oracle-diagnostic-estack/lab-evidence"; install -d -m 700 "$EVD"
TS=$(date -u +%Y%m%dT%H%M%SZ)
.venv/bin/python -m mcp_gateway_lab check --targets "$LAB/targets.lab.json" --lab-profile "$LAB/lab-profile.json" \
  | tee "$EVD/check-$TS.json"
shasum -a 256 "$EVD/check-$TS.json" | tee "$EVD/check-$TS.json.sha256"

# 6.3 Suite automatizada (sin Oracle, sin red, sin Keychain: driver y Keychain simulados)
bash tests/test_p15_oracle_lab_adapter.sh
bash tests/test_p15_oracle_lab_security.sh
```

Resultado esperado de 6.2: `"result": "PASS"`, `provenance.kind = "REAL"`, `instance_name`/`db_name` enmascarados (`inst-A1`, `db-A1`), `version`/`database_role`/`cdb`/`open_mode` en claro. Si falla, `failure_category` indica la causa sin exponer el mensaje del driver:

| Categoría | Qué revisar |
|---|---|
| `CREDENTIAL_UNAVAILABLE` | ítem de Keychain (servicio/cuenta), acceso de `/usr/bin/security` al ítem |
| `CREDENTIALS_REJECTED` / `ACCOUNT_LOCKED` / `PASSWORD_EXPIRED` | password en Keychain vs. base; estado de la cuenta (DBA) |
| `NETWORK_UNREACHABLE` / `NO_LISTENER` / `NETWORK_TIMEOUT` / `NETWORK_OR_LISTENER` | host/puerto, VPN, firewall, listener |
| `SERVICE_NOT_REGISTERED` | `service_name` (`lsnrctl status` en el servidor, lo ejecuta el DBA) |
| `NATIVE_NETWORK_ENCRYPTION_NEEDS_THICK_MODE` | la base exige NNE: fuera de alcance, escalar |
| `MISMATCH_*` | la base conectada no es la autorizada: corrige el perfil **sólo** si el target es el correcto |
| `PRIVILEGED_SESSION` / `EXCESSIVE_SYSTEM_PRIVILEGES` | la cuenta no es la dedicada o tiene privilegios de más (DBA) |
| `MISSING_OBJECT_PRIVILEGE` | faltan los `GRANT SELECT` sobre `V_$INSTANCE`/`V_$DATABASE` (o, para LAB-002, `V_$RESOURCE_LIMIT`) |
| `CALL_TIMEOUT` / `DEADLINE` | latencia; los límites no se pueden subir por encima de los certificados |

## 7. Registro en Claude Code

Con alcance `local` (queda en tu configuración de usuario para este proyecto; no se versiona):

```bash
cd ~/Projects/oracle-diagnostic-estack
claude mcp add --scope local oracle-estack-lab \
  -e PYTHONPATH="$PWD" -e PYTHONDONTWRITEBYTECODE=1 -e PYTHONUTF8=1 \
  -- "$PWD/.venv/bin/python" -m mcp_gateway_lab serve \
  --targets "$HOME/.config/oracle-diagnostic-estack/targets.lab.json" \
  --lab-profile "$HOME/.config/oracle-diagnostic-estack/lab-profile.json"
claude mcp get oracle-estack-lab
```

En la sesión de Claude Code: `/mcp` para confirmar que está conectado; luego pide `diagnostics.list_capabilities` y `diagnostics.collect` con `collector_id=Q-DISC-IDENTITY-001` y `target_alias=lab-ol8-19c`. El servidor fixture existente (`oracle-diagnostic-estack`) puede seguir registrado en paralelo; son procesos distintos.

## 8. Desconexión y retiro

No hay conexión persistente: cada `collect` abre, valida, lee, hace `rollback` y cierra. Para desconectar el laboratorio por completo:

```bash
# 8.1 Quitar el servidor MCP de Claude Code (detiene el proceso en la próxima sesión)
claude mcp remove oracle-estack-lab --scope local

# 8.2 Revocar el secreto local y la configuración privada
security delete-generic-password -s oracle-estack-lab -a lab-ol8-19c
rm -f "$HOME/.config/oracle-diagnostic-estack/lab-profile.json" "$HOME/.config/oracle-diagnostic-estack/targets.lab.json"

# 8.3 (Opcional) quitar el driver del venv
.venv/bin/python -m pip uninstall -y oracledb
```

Del lado de la base (ejecución humana del DBA): `ALTER USER ESTACK_DIAG ACCOUNT LOCK;` y, al cerrar el laboratorio, `DROP USER ESTACK_DIAG;` y `DROP PROFILE ESTACK_DIAG_PROF;`. Aunque no se haga nada, el adaptador deja de conectarse cuando vence `authorization.expires_at_utc`.

## 9. Evidencia de la regresión

La regresión completa se ejecuta con el tooling de Fase 14, que registra el fingerprint del árbol antes y después y permite verificar el paquete:

```bash
OUT="$HOME/.local/share/oracle-diagnostic-estack/release-evidence/CHG-ESTACK-ORA19C-LAB-001-$(date -u +%Y%m%dT%H%M%SZ)"
.venv/bin/python -m release_readiness run --out "$OUT"
.venv/bin/python -m release_readiness verify --package "$OUT" --root "$PWD"
.venv/bin/python -m release_readiness gate --evidence "$OUT" --format markdown
```

Baseline de `HEAD` (`cb3778f`) antes de este cambio: **947/960**. Los 13 fallos son preexistentes y ajenos al gateway (variantes `Q-RMAN-*` para 12c+, `must_not_delegate_to` de 5 agentes, allowlist de colectores de SO, columnas de `Q-PDB-*`); este cambio no los corrige ni los empeora.

## 10. Gobernanza propuesta (a aplicar por la revisión humana)

Este cambio **no** modifica `config/governance/*.json`: las pruebas de Fase 14 fijan que el registro sólo contiene aprobaciones humanas reales. Propuesta para que la aplique el revisor:

- `config/governance/lifecycle-records.json`: registro `GOV-LAB-ORA19C-001`, `artifact_type: adapter`, `artifact_id: oracle_sql`, `semver: 0.1.0`, `state: PROPOSED`, `compatibility: {oracle_versions: [19c], platforms: [macOS], breaking: false}`, `sources: [docs/ORACLE19C_LAB_ADAPTER.md]`.
- `config/governance/risk-register.json`: `RSK-010` "Lab launcher opens a real read-only Oracle connection" (probabilidad MEDIUM, impacto HIGH, OPEN). Mitigación: los controles de la §3. Condición de cierre: revisión humana aceptada, registro de piloto de laboratorio y confirmación independiente de privilegios por el DBA.
- `RSK-001`/`RSK-008` siguen abiertos: el runtime por defecto no ejecuta SQL real y el laboratorio no es un piloto aceptado.

## 11. Limitaciones y riesgos residuales

- **Probado sólo con driver y Keychain simulados** en esta rama. La ejecución contra la base 19c real es el smoke test de la §6.2, que corre una persona.
- Sólo macOS Keychain como almacén de secretos; otros almacenes (Vault, wallet SEPS) requieren un cambio nuevo.
- Modo thin: sin Native Network Encryption ni autenticación externa por wallet.
- Si la llamada supera el deadline, el hilo abandonado conserva el lock hasta que el driver vuelve (acotado por `call_timeout`); mientras tanto las llamadas reciben `E_BUSY`.
- La auditoría local sigue siendo stderr (sin argumentos ni evidencia). Del lado de Oracle, la sesión se identifica con `program`/`module = estack-diag-lab` y `action = <collector_id>` para la auditoría del DBA.
- El release gate no escanea `mcp_gateway_lab/`, porque su política prohíbe `oracledb` y `subprocess`. El escaneo estático equivalente está en `tests/p15/check_lab_security.py`. Extender `SCAN_PACKAGES` con una política propia queda como seguimiento.
