# Evidencia reportada por humano (HUMAN_REPORTED)

`/change security|documentation` — `CHG-ESTACK-HUMAN-EVIDENCE-001`. Rama `change/human-evidence` sobre `main` (`6f09471`, con la fábrica de collectors B1).

## Para qué sirve

El gateway recolecta en real con **34 collectors habilitados en el lab** (con B1, [docs/COLLECTOR_FACTORY.md](COLLECTOR_FACTORY.md)), pero el catálogo tiene **129 queries certificadas**. La ruta normal es que el stack recolecte solo; ésta es el **respaldo** para una query sin collector todavía o para una base a la que el stack no puede conectarse. Sin ella, ese análisis se queda en `capability_status` sin evidencia.

Con esta ruta, el agente pide la query certificada que falta, el DBA la ejecuta y entrega el CSV, y el e-stack lo sanea **localmente** antes de que el modelo lo vea.

Se mantienen las reglas del stack:

- **READ-ONLY ALWAYS. HUMAN EXECUTION ONLY.** El e-stack no se conecta a la base de datos: quien ejecuta es el DBA.
- **Sólo SQL certificado.** El script sale de `queries/`, resuelto por versión con el mismo guard del lab (`mcp_gateway_lab.sqlsource`). No se acepta SQL del agente ni del usuario.
- **Lo crudo nunca va al modelo.** El CSV se queda en `evidence/inbox/` y los tokens en `evidence/raw/`, ambos ignorados por git y con permisos `0600`. El modelo lee sólo `evidence/sanitized/EVD-HR-*.json`.

## Flujo para el equipo

1. **El agente (o el DBA) crea la solicitud.**

   ```
   python -m human_evidence request --query Q-ORA-PARAMETERS-001 --target <alias> --version 19c --scope ANA-20260930-001
   ```

   Crea `evidence/requests/ER-*.json` y `ER-*.sql`. El `.sql` contiene:
   - el SELECT certificado exacto, con su `sha256` en el encabezado;
   - `SET MARKUP CSV ON QUOTE ON`;
   - `SPOOL` a `evidence/inbox/ER-*.csv`.

2. **El DBA revisa y ejecuta el script** con el usuario de diagnóstico de sólo lectura, en SQL*Plus 12.2 o superior, por la opción `MARKUP CSV`. Luego copia el CSV a la ruta indicada. Si lo ejecuta en otro equipo, copia el CSV a esa misma ruta.

3. **El DBA ingiere el CSV.**

   ```
   python -m human_evidence ingest --request ER-... --file evidence/inbox/ER-....csv --reporter REV-DBA01
   ```

   Produce `evidence/sanitized/EVD-HR-*.json`. La salida lista las políticas por columna y las limitaciones.

4. **El agente cita `EVD-HR-*`** en el análisis:
   - con `validation_level: HUMAN_REPORTED` y confianza máxima `PROBABLE_CAUSE`;
   - declarando las columnas y los valores descartados como limitaciones.

   Ver [policies/field-validation-policy.md](../policies/field-validation-policy.md).

`--scope` agrupa un análisis. Los alias (`ts-…`, `own-…`, `tok-…`) son estables dentro del mismo scope, lo que permite correlacionar entre queries, y distintos entre scopes. La clave HMAC de cada scope vive en `evidence/raw/.human-evidence-keys/`.

## Qué se rechaza (código de salida 2, `human_evidence: refused (…)`)

| Caso | Motivo |
|---|---|
| Query inexistente, no `active`, no `READ_ONLY`, o sin variante segura para la versión | Sólo SQL certificado |
| Alias, scope, reporter o request id con formato inválido | Evita rutas o texto libre |
| El SQL certificado cambió desde la solicitud (sha distinto) | El CSV correspondería a otro SQL: se crea una solicitud nueva |
| CSV > 5 MB, encabezado inesperado o duplicado, filas irregulares | Entrada no confiable |
| La salida saneada aún contiene algo con forma de secreto | Última barrera, no se escribe nada |

Las filas que superan `max_rows` de la query (tope 5000) se truncan y se declara `ROWS_TRUNCATED_TO_LIMIT`.

## Cómo se sanea cada columna

1. **Si la query tiene collector en el gateway** (catálogo manual o generado por la fábrica):
   - sus `output_fields` son la autoridad: misma política y mismo prefijo de alias que el collector;
   - las columnas del CSV se renombran igual que en el adaptador del lab (por ejemplo `NAME` → `parameter_name`);
   - cada valor debe tener la forma del tipo del spec (entero, número, versión, nombre de parámetro); si no, se descarta;
   - toda columna fuera del spec se descarta (`not_in_collector_spec`);
   - un valor fuera del `enum` del spec no se conserva.
2. **Si no tiene collector**:
   - se aplican primero los overrides de [`config/human-evidence-policies.json`](../config/human-evidence-policies.json); agregar uno es un `/change security`;
   - después, la heurística de `human_evidence/classify.py`:

   | Orden | Regla | Política |
   |---|---|---|
   | 1 | Nombre sensible (`password`, `secret`, `token`, `wallet`, `*_key`, `bind`, `sql_text`, `spare*`…). Ningún override lo revierte | `DROP` |
   | 2 | Todos los valores numéricos | `KEEP` |
   | 3 | Nombre de identidad (`owner`, `user`, `host`, `tablespace`, `file_name`, `path`, `service`…) | `MASK` |
   | 4 | Algún valor de más de 128 caracteres | `DROP` |
   | 5 | Nombre de estado o tipo (`status`, `type`, `mode`, `event`…) o valores tipo enum | `KEEP` |
   | 6 | Resto | `TOKENIZE`; los números se conservan |

3. **Por valor, en cualquier columna:**
   - se descartan (`SENSITIVE_VALUES_DROPPED:n`):
     - pares clave=valor de credenciales, tokens Bearer, llaves de acceso AWS, bloques PEM, hex largos;
     - `usuario/clave@db`, credenciales en URL, correos;
     - palabras con forma de token aleatorio;
   - las rutas, IPs y FQDN dentro de una columna `KEEP` se enmascaran.

   Los identificadores Oracle legibles, como `remote_login_passwordfile`, `_optimizer_adaptive_plans`, `DBA_HIST_ACTIVE_SESS_HISTORY` o `+DATA/ORCL/...`, **no** cuentan como secretos.

## Límites conocidos

- **El e-stack no observa la ejecución.** No puede verificar el target, el usuario, el contenedor ni que el SQL ejecutado sea el entregado. Por eso el nivel es `HUMAN_REPORTED`, con `observed_by_estack: false` y techo `PROBABLE_CAUSE`.
- **Cobertura de solicitudes:**

  | Familia | Queries que se pueden solicitar |
  |---|---|
  | 19c | 116 de 129 |
  | 12c | 111 de 129 |
  | 23ai | 111 de 129 |
  | 11g | 93 de 129 |

  Las 12 que no resuelven en 19c lo hacen por el guard del lab (`certified SQL could not be resolved safely`): varios bloques SQL, palabras vetadas como `lock` o `sys.`, o variantes sin rango. Son Q-DISC-ASM-001, Q-ORA-DIAGNOSTICS-ALERTLOG-001, Q-PERF-HARDPARSE-001, Q-PERF-LOCKS-001, Q-PERF-WAIT-ASH-001, Q-PERF-WAIT-STATSPACK-001, Q-RAC-GES-GCS-001, Q-SEC-DATA-REDACTION-POLICIES-001, Q-SEC-DATABASE-VAULT-STATUS-001, Q-SEC-DIRECTORIES-001, Q-SEC-PASSWORD-VERIFY-SOURCE-001 y Q-SEC-UNIFIED-AUDIT-TRAIL-001. Q-SEC-NETWORK-ENCRYPTION-PARAMS-001 no está certificada como `active`. Queda como cambio aparte (`CHG-REQ-HUMAN-EVIDENCE-UNRESOLVED-QUERIES`).
- **Un secreto con forma de identificador** (snake_case de sólo letras) dentro de una columna `KEEP` no se detecta por forma. Lo mitigan dos cosas: las columnas con nombre sensible siempre se descartan, y las de texto libre se tokenizan.
- El CSV debe venir de SQL*Plus con `MARKUP CSV` (12.2+). En 11g, el DBA exporta con otra herramienta a CSV con encabezado.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Sólo 12 de 170 skills con evidencia SQL se ejecutan completos en real; un análisis sin collector no tiene ruta para obtener evidencia |
| PROPOSAL | Solicitud con SQL certificado → ejecución humana → saneamiento local → `HUMAN_REPORTED` |
| IMPLEMENT | Paquete `human_evidence/` (`request`, `ingest`, clasificador), `config/human-evidence-policies.json`, `evidence/.gitignore` (`requests/*`, `inbox/*`) |
| TEST | `tests/test_human_evidence.sh` (P17): 18/18 |
| SECURITY | 11/11 mutaciones detectadas: sin descarte por valor, override sobre nombre sensible, sin máscara en `KEEP`, sin re-check del sha, spec del collector ignorado, exención de identificadores amplia, enum no aplicado, clave sin scope, sin tope de filas, alias del lab ignorados, tipo del spec no aplicado. El paquete no importa drivers, red, `subprocess` ni keyring |
| REGRESSION | 971/971 en macOS con bash 5.3, ya integrado sobre B1 (antes, el escáner de secretos marcó un ejemplo en este documento; se reformuló); CI de la PR #28 en verde en ubuntu, macOS y Windows |
| DOCUMENT | Este documento, la política de validación en campo, `docs/CONTRACTS.md`, el orquestador y `CHANGELOG.md` |
| HUMAN REVIEW | Aprobado: `AUTH-HUMAN-EVIDENCE-001`, revisor `REV-DBAMANAGER`, `2026-09-30T22:00:14Z`, digest `13b45f65…d008c7bf`. PROMOTE: PR #28, merge `0245579` |

Relación con la fábrica de collectors (B1, ya en `main`): para las 18 queries del lote B1, la ruta humana aplica exactamente el spec generado y los mismos alias.
