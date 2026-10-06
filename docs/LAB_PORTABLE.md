# Recolección real en Windows, Linux y macOS (Oracle Wallet / SEPS)

`/change security|compatibility|documentation` — `CHG-ESTACK-LAB-PORTABLE-001`. Rama `change/lab-portable` sobre `main` (`46e14fa`, con el lote B2).

## Qué cambia

Antes de este cambio, el adaptador real (`python -m mcp_gateway_lab`) solo funcionaba en macOS. Ahora funciona igual en los tres sistemas:

| Proveedor de credencial | Modo del driver | Dónde se usa | Contraseña |
|---|---|---|---|
| `macos_keychain` (existente, **sin cambios**) | Thin | macOS | La toma del llavero solo para conectar y la descarta |
| `oracle_wallet` (nuevo) | **Thick, solo en este caso** | Windows, Linux, macOS | **El e-stack nunca la ve**: el Oracle Client autentica con el Wallet (SEPS, `/@alias`) |

- **El modo Thick lo aprobó el revisor** solo para `oracle_wallet` (2026-10-02), porque python-oracledb en Thin no soporta SEPS. Un target con llavero sigue en Thin. Una prueba falla si alguien intenta Thick con el llavero o Thin con el Wallet. Thick y Thin no se mezclan en un proceso, y el lanzador atiende un solo target por proceso.
- **Los controles de siempre se mantienen en ambos modos:**
  - sesión de solo lectura;
  - el usuario de la sesión debe ser el del perfil;
  - techo de privilegios de sistema;
  - identidad del target (versión, rol, contenedor, base, servicio);
  - SQL certificado y verificado por hash;
  - límites y fallo cerrado.

  Con el Wallet apuntando a `KIO_ORQUESTA`, como en la primera corrida sobre LAB19S, el adaptador **rechaza** la sesión (`MISMATCH_SESSION_USER`).
- **Archivos privados en los tres sistemas** (`mcp_gateway_lab/filesec.py`):
  - en POSIX: dueño y permisos, como antes;
  - en Windows: dueño y ACL leídos con la API nativa, sin dependencias. Solo pueden tener acceso tu usuario, SYSTEM y Administradores.

  Aplica al perfil, al Wallet y a los archivos crudos de `human_evidence`. `sqlnet.ora` y `tnsnames.ora` pueden ser legibles por otros, pero no modificables.

## Qué valida el lanzador al arrancar con `oracle_wallet`

1. El directorio del Wallet es **privado**, contiene `cwallet.sso`, y sus archivos (`cwallet.sso`, `ewallet.p12`) también son privados.
2. `tns_admin` tiene `sqlnet.ora` y `tnsnames.ora`, que nadie más puede modificar.
3. `sqlnet.ora` declara `WALLET_LOCATION` **exactamente** con el Wallet del perfil y `SQLNET.WALLET_OVERRIDE = TRUE`.
4. El alias está definido en `tnsnames.ora`.
5. El Wallet y la configuración de red están **fuera del repositorio**.
6. Las bibliotecas del Oracle Client cargan y el driver queda en Thick.

Cualquier falla detiene el arranque con un mensaje fijo, sin rutas ni valores.

## Instalación paso a paso

> Todo esto lo hace el operador. El e-stack no crea Wallets, no edita `sqlnet.ora` y no conecta con otra cuenta.

### 1. Usuario de diagnóstico en la base (DBA)

Usa `ESTACK_DIAG` (o `C##ESTACK_DIAG` en un CDB) con `CREATE SESSION` + `SELECT_CATALOG_ROLE`, más `CONTAINER_DATA` si es CDB. Para el assessment de seguridad agrega `GRANT SELECT ON SYS.DBA_USERS_WITH_DEFPWD` y el rol `AUDIT_VIEWER` (ver [SEC_QUERIES.md](SEC_QUERIES.md#privilegios-de-la-cuenta-de-diagnóstico)). El DDL está en [ORACLE19C_LAB_ADAPTER.md](ORACLE19C_LAB_ADAPTER.md#4-aprovisionamiento-del-usuario-diagnóstico-ejecución-humana-del-dba).

### 2. Oracle Client y Python

| | Windows | Linux | macOS |
|---|---|---|---|
| Oracle Client | Client 19c+ (o Instant Client + herramientas con `mkstore`) | Instant Client en `ldconfig` o `LD_LIBRARY_PATH` | Instant Client (`client_lib_dir`); o el llavero, sin cliente |
| Python | 3.13 o 3.14 (ambos en la CI) | igual | igual |
| Driver | `.venv\Scripts\python -m pip install oracledb` | `.venv/bin/python -m pip install oracledb` | igual que Linux |

### 3. Wallet con la credencial de diagnóstico

Las contraseñas **nunca** van en la línea de comando: `mkstore` las pide en pantalla.

```text
mkstore -wrl <DIR_WALLET> -create
mkstore -wrl <DIR_WALLET> -createCredential LAB19S_DIAG ESTACK_DIAG
mkstore -wrl <DIR_WALLET> -listCredential        # debe listar sólo la credencial de diagnóstico
```

Hazlo privado:

- **Windows (cmd):**
  ```text
  icacls "<DIR_WALLET>" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F"
  ```
- **Linux / macOS:**
  ```text
  chmod 700 <DIR_WALLET>; chmod 600 <DIR_WALLET>/*
  ```

### 4. Oracle Net (`<TNS_ADMIN>`)

`sqlnet.ora`:

```text
WALLET_LOCATION = (SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = <DIR_WALLET>)))
SQLNET.WALLET_OVERRIDE = TRUE
SQLNET.OUTBOUND_CONNECT_TIMEOUT = 5
```

`tnsnames.ora`:

```text
LAB19S_DIAG = (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = <host>)(PORT = 1521))
                (CONNECT_DATA = (SERVICE_NAME = LAB19S)))
```

Compruébalo antes de usar el e-stack: `sqlplus /@LAB19S_DIAG` y `SELECT USER FROM dual;` deben devolver `ESTACK_DIAG`.

### 5. Perfil y targets (fuera del repositorio, privados)

`lab-profile.json`. En Windows usa `/` o `\\` en las rutas:

```json
{
  "schema_version": "1.0.0",
  "profile_id": "LAB19S-WIN-001",
  "targets": {
    "lab19s": {
      "environment_class": "NON_PRODUCTION",
      "connection": {"username": "ESTACK_DIAG", "service_name": "LAB19S"},
      "credential": {"provider": "oracle_wallet", "tns_alias": "LAB19S_DIAG",
                     "tns_admin": "C:/Users/<usuario>/Oracle/network/admin",
                     "wallet_location": "C:/Users/<usuario>/Oracle/wallet",
                     "client_lib_dir": "C:/oracle/product/19.0.0/client_1/bin"},
      "expected": {"oracle_version_family": "19c", "database_role": "PRIMARY", "container": "NON_CDB", "db_name": "LAB19S"},
      "allowed_system_privileges": ["CREATE SESSION"],
      "limits": {"connect_timeout_seconds": 5, "call_timeout_ms": 15000, "max_rows": 100, "max_output_bytes": 32768},
      "authorization": {"approved_by": "DBA Manager", "change_ref": "CHG-ESTACK-LAB-PORTABLE-001",
                        "approved_at_utc": "2026-10-02T00:00:00Z", "expires_at_utc": "2026-12-31T00:00:00Z"}
    }
  }
}
```

- `client_lib_dir` es opcional en Windows si el `bin` del cliente ya está en el `PATH`. En macOS es obligatorio con Instant Client. En Linux no se usa.
- `targets.lab.json` es igual que el del lab: un target `oracle_sql` con su lista de collectors.

### 6. Validar y probar

Windows:

```text
cd C:\Users\<usuario>\Projects\oracle-diagnostic-estack
.venv\Scripts\python -m mcp_gateway_lab validate-config --targets <ruta>\targets.lab.json --lab-profile <ruta>\lab-profile.json
.venv\Scripts\python -m mcp_gateway_lab check --targets <ruta>\targets.lab.json --lab-profile <ruta>\lab-profile.json
```

Linux y macOS: lo mismo con `.venv/bin/python`. Si `check` falla, `failure_category` dice por qué:

| Categoría | Causa |
|---|---|
| `TNS_ALIAS_NOT_RESOLVED` | El alias no está en `tnsnames.ora` o `TNS_ADMIN` no es el correcto |
| `WALLET_NOT_READABLE` | El Wallet no se puede leer |
| `WALLET_HAS_NO_CREDENTIAL_FOR_ALIAS` | El Wallet no tiene credencial para ese alias |
| `ORACLE_CLIENT_NOT_FOUND` | No se encontraron las bibliotecas del Oracle Client |
| `MISMATCH_SESSION_USER` | La credencial del Wallet es de otra cuenta |

### 7. Registrar el MCP en Claude Code

Ejecútalo desde la carpeta del repositorio (alcance de proyecto).

Windows:

```text
claude mcp add oracle-estack-lab -- C:\Users\<usuario>\Projects\oracle-diagnostic-estack\.venv\Scripts\python.exe -m mcp_gateway_lab serve --targets <ruta>\targets.lab.json --lab-profile <ruta>\lab-profile.json
```

Linux y macOS: lo mismo con `.venv/bin/python`. Después, `/mcp` → `oracle-estack-lab` → **Reconnect**. Cada vez que cambie el perfil, el código o una query, hay que reconectar: el servidor carga el catálogo al arrancar y rechaza SQL cuyo hash haya cambiado.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | La corrida sobre LAB19S desde Windows (2026-10-01) mostró que el stack solo podía recolectar en real desde macOS. En Windows hubo que usar la ruta `HUMAN_REPORTED` |
| PROPOSAL | Proveedor `oracle_wallet` (SEPS) con Thick solo para él; verificación de privacidad nativa por sistema; Python 3.14 en la CI. Thick aprobado por el revisor el 2026-10-02 |
| IMPLEMENT | `mcp_gateway_lab/filesec.py` (nuevo), `credentials.py`, `profile.py` (esquema por proveedor y validación de Wallet y Oracle Net), `cli.py` (`prepare_driver`), `oracle_sql.py` (modo por proveedor, `externalauth`, categorías de error), `human_evidence/cli.py` (archivos privados verificados), `.github/workflows/tests.yml` (Python 3.13 y 3.14) |
| TEST | `tests/test_lab_portable.sh` (P19, 12 casos, en los tres sistemas). Las pruebas del lab (P15) ahora corren también en Windows; solo la de `chmod`/symlink sigue siendo exclusiva de POSIX, y su equivalente con `icacls` está en P19 |
| SECURITY | 15/15 mutaciones detectadas: DACL nula, lectura por otro SID, ACE desconocida, dueño ajeno, bits de grupo en POSIX, Thick con llavero, contraseña en la ruta Wallet, `WALLET_LOCATION` sin comparar, `WALLET_OVERRIDE` sin exigir, Wallet no privado, `sqlnet.ora` modificable, Thick sin inicializar, Wallet en Thin, alias sin verificar, privacidad del perfil omitida. El escaneo estático solo permite `ctypes` en `filesec.py` e `init_oracle_client` en `cli.prepare_driver` |
| REGRESSION | 972/972 en macOS (bash 5.3). CI de la PR #31 (`e8f865a`) en verde en los 6 jobs: ubuntu, macOS y Windows con Python 3.13 y 3.14. Las corridas previas detectaron, y se corrigió, la entrada OWNER RIGHTS (`S-1-3-4`) que Python 3.13+ pone en las ACL de Windows, y dos pruebas con simulación de plataforma incorrecta |
| LAB | **macOS con el llavero (`cb35b48`, 2026-10-02T17:47Z): sin cambios.** `Q-DISC-IDENTITY-001` (`REQ-b9f7fa9b1752`, `EVR-ee20a89f3e0e6c3b27f9a269`), `Q-PERF-WAIT-CLASS-001` (`REQ-0a2ee951c9ca`, `EVR-f7b9b0614c2f55ae4759f5bc`) y `Q-CDB-TABLESPACES-001` (`REQ-caf0f29c82e7`, `EVR-4ea502398e0379b175e5a62b`) corren en real, en Thin, con el mismo perfil y siguen `FIELD_VALIDATED`. **Windows con el Wallet (`e8f865a`, 2026-10-02T21:33Z, operador en Windows 11, Python 3.14, Oracle Client 19c, VPN):** `validate-config` pasó: ACL del perfil, targets y Wallet; `sqlnet.ora` → Wallet del perfil con `WALLET_OVERRIDE`; alias en `tnsnames.ora`; cliente cargado en Thick. El primer `check` dio `CREDENTIALS_REJECTED` (ORA-01017): el Wallet nuevo no tenía todavía la credencial de `LAB19S_DIAG`, el stack falló cerrado y no corrió ningún SQL. Con la credencial creada con `mkstore`, `check` dio **PASS**: `Q-DISC-IDENTITY-001` real (`REQ-b5eef607d34f`, `EVR-49c782a820b9bd0b5549b797`), 19.30 non-CDB PRIMARY, nombres enmascarados, `FIELD_VALIDATED_OTHER_CONTEXT` (difieren RU 19.30 frente a 19.32 y contenedor NON_CDB frente a CDB_ROOT, como corresponde). El registro del MCP en Claude Code en Windows (paso 7) queda como paso del operador; `check` recorre el mismo camino del gateway |
| HUMAN REVIEW | Aprobado: `AUTH-LAB-PORTABLE-001`, revisor `REV-DBAMANAGER`, `2026-10-02T21:47:22Z`, digest `190a4fe2…a97948b0`. El modo Thick solo con `oracle_wallet` fue aprobado por el revisor el 2026-10-02. PROMOTE: PR #31, merge `8b3ed0a` |

**Límites:**
- `tnsnames.ora` con `IFILE`, o alias definidos fuera de ese archivo, no se siguen: el alias debe estar en `tnsnames.ora`.
- Wallets en LDAP o en el registro de Windows no están soportados: solo `METHOD = FILE`.
- El timeout de conexión con Wallet viene de `SQLNET.OUTBOUND_CONNECT_TIMEOUT`.
- El perfil y los targets se leen como UTF-8 estricto: un archivo guardado con BOM (algunos editores de Windows) se rechaza como «not valid JSON». Créalos con `Set-Content -Encoding ASCII` o UTF-8 sin BOM. Aceptar el BOM queda propuesto como `CHG-REQ-LAB-JSON-BOM`.
- `CREDENTIALS_REJECTED` con Wallet suele ser una credencial faltante o desactualizada en el Wallet (`mkstore -listCredential` / `-modifyCredential`). Cada intento fallido cuenta para `FAILED_LOGIN_ATTEMPTS` del perfil de la cuenta.
