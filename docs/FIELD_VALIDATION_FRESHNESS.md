# Registro de validaciones vigente en un gateway en ejecución

`/change security|compatibility|documentation` — `CHG-ESTACK-FIELD-VALIDATION-FRESHNESS-001`. Rama `change/field-validation-freshness` sobre `main` (`b3d22d7`, `v0.29.0-assessment-accuracy`). Origen: REC-0015 de `ANA-20261019-001` (FND-0025).

## Por qué

El gateway leía `config/field-validation-registry.json` **una sola vez**, al arrancar. Un proceso que seguía vivo después de un merge decidía los niveles con el registro viejo, y nada lo advertía.

| Caso | Qué pasa con el registro viejo | Riesgo |
|---|---|---|
| Se **agrega** una validación (lo que ocurrió) | Una query validada sale `DOCUMENTATION_ONLY` | Seguro, pero rebaja conclusiones sin motivo |
| Se **retira** una validación (p. ej. por un resultado no representativo) | Una query sin validación vigente sale `FIELD_VALIDATED` | **Peligroso:** un análisis hereda una confianza que el registro ya no respalda |

**Antecedente:** en `ANA-20261019-001` el proceso del lab arrancó el 2026-10-12T19:18:04Z con el checkout en `db71836`. A las 19:20:45Z el checkout pasó a `0facc67`, el merge que trajo las 13 validaciones de `CHG-ESTACK-ASSESSMENT-ACCURACY-001`. Una semana después, esos 13 collectors seguían saliendo `DOCUMENTATION_ONLY`. Se resolvió a mano: el usuario reconectó el MCP y se repitieron los 13.

## Análisis del gap

- **El catálogo de SQL no tiene este problema:** el lab rechaza SQL cuyo hash cambió (allowlist del perfil), y `docs/LAB_PORTABLE.md` ya pide reconectar ante cambios de código, perfil o query. El registro no estaba en esa lista y nada lo vigilaba.
- **Recargar el registro es seguro aunque el SQL en memoria sea viejo:** `assess` compara el `query_sha256` del SQL que **corre** con las entradas del registro. Un registro nuevo con un SQL viejo da `DOCUMENTATION_ONLY`, que es fallo cerrado.
- **REC-0015 pedía, además:**
  - **el commit del checkout:** se descarta. El gateway no ejecuta `git` ni lee `.git`, y una distribución puede no tenerlo. El `sha256` del archivo identifica el registro igual y se puede comparar con `shasum`/`Get-FileHash`;
  - **distinguir "SQL cambiado" de "registro sin la entrada":** se descarta, porque ya ocurre. `SQL_CHANGED_SINCE_FIELD_VALIDATION` solo aparece si el registro **tiene** entradas de esa query con otro hash. En `ANA-20261019-001`, `Q-DICT-VERIFY-003` lo reportó porque el registro de `db71836` tenía su validación anterior a `CHG-ESTACK-ASSESSMENT-ACCURACY-001`. El motivo era correcto: FND-0025 lo llamó engañoso por error.

## Cambios

| Artefacto | Cambio |
|---|---|
| `mcp_gateway/field_validation.py` | `load` guarda la fuente del registro: ruta interna, tamaño y fecha, `sha256` de los bytes del archivo y número de recargas. `refresh` relee el archivo si cambió el tamaño o la fecha **y** el `sha256`; un archivo solo tocado no se recarga. Un archivo inválido o borrado mientras corre falla cerrado (todo `DOCUMENTATION_ONLY`), igual que al arrancar. Un registro inyectado por quien construye el gateway (pruebas) no se recarga. `summary` describe el registro sin la ruta. `assess` agrega `registry_sha256` a cada nivel |
| `mcp_gateway/gateway.py` | `call` refresca el registro antes de cada tool. `diagnostics.list_capabilities` agrega `field_validation_registry`: `status` (`LOADED`, `INVALID_FAIL_CLOSED` o `INJECTED`), `sha256`, `reloads`, `validations`, `contexts` y `file`. `file` es `config/field-validation-registry.json`, o `other` si la ruta no es la del repositorio; nunca la ruta real |
| `docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md`, `policies/field-validation-policy.md`, `docs/LAB_PORTABLE.md` | Documentan la recarga, el digest y cómo compararlo |

Aplica al gateway de fixtures (`mcp_gateway`) y al del lab (`mcp_gateway_lab`), que usan la misma clase `Gateway`.

**Costo:** un `os.stat` por llamada. El archivo se lee y se hashea solo cuando cambian su tamaño o su fecha.

## Impacto

- **Contratos de salida:** se agregan dos campos (`field_validation.registry_sha256` y `field_validation_registry` en `list_capabilities`). No se quita ni renombra ninguno.
- **Sin efecto en:** queries, SQL, Query Contracts, matriz de capacidades, licencias, privilegios y saneamiento. No hay tools nuevas ni entradas nuevas.
- **Seguridad:** la ruta del registro es fija (no viene de ninguna entrada) y no sale del gateway.
- **Agentes y workflows:** un análisis puede citar el `registry_sha256` de su evidencia. Ningún workflow cambia de paso.
- **Plataformas:** solo stdlib (`os.stat`, `hashlib`). `st_mtime_ns` existe en Windows, macOS y Linux.

## Validación

| Fase | Resultado |
|---|---|
| DETECT GAP | FND-0025 de `ANA-20261019-001`: 13 collectors `DOCUMENTATION_ONLY` por un proceso con el registro de `db71836` |
| CHANGE REQUEST | `CHG-ESTACK-FIELD-VALIDATION-FRESHNESS-001`, tipos `security`, `compatibility` y `documentation` |
| GAP ANALYSIS | Carga única en `Gateway.__init__`; el catálogo sí está protegido por el hash de la allowlist. Se descartan el commit y la distinción de motivos (arriba) |
| IMPACT ANALYSIS | 2 campos nuevos de salida; sin efecto en queries, licencias, privilegios ni saneamiento |
| PROPOSAL | Este documento |
| IMPLEMENT | `field_validation.py` (`load` con fuente y digest, `refresh`, `summary`, `registry_sha256`) y `gateway.py` (refresco en `call`, `field_validation_registry`) |
| TEST | P16 20/20, con 6 casos nuevos: digest del archivo, validación agregada y **retirada** sin reiniciar, archivo sin cambios o solo tocado, archivo roto o borrado (fallo cerrado), registro inyectado, y gateway de punta a punta (sin rutas en la salida) |
| SECURITY | 8/8 mutaciones detectadas: refresco omitido, refresco que devuelve siempre el viejo, conservar el registro viejo ante un archivo roto (fallo abierto), ruta real en `summary`, digest del JSON en vez del archivo, `registry_sha256` omitido, recarga por solo tocar el archivo, y `list_capabilities` sin el registro |
| REGRESSION | 973/973 en macOS (bash 5.3), sin fallos |
| LAB | Pendiente: con el MCP del lab reconectado sobre esta rama, `list_capabilities` debe mostrar el `sha256` del registro, y una edición del registro debe verse sin reconectar |
| HUMAN REVIEW | Pendiente |
