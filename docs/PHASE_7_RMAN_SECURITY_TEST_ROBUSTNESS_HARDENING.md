# PHASE 7 — RMAN Security Test Robustness Micro-Hardening

Micro-hardening puntual sobre `phase/7-backup-recovery-rman`, posterior a **PHASE 7 — RMAN
Legacy SQL Syntax & Query Certification Hardening**. No reconstruye ninguna parte de Fase 7. El
único objetivo es cerrar un falso negativo en `tests/test_no_arbitrary_rman.sh` antes de aprobar
`v0.7.0-backup-recovery-rman`.

## False-negative cause

`tests/test_no_arbitrary_rman.sh` escanea todo el dominio `agents/oracle-backup-recovery-analyst`,
`skills/rman`, `queries/rman`, `parsers/rman` en busca de los nombres peligrosos
`execute_rman(`, `run_rman(`, `rman_shell(`. Al encontrar una ocurrencia, el test original
tomaba una ventana de sólo 3 líneas hacia atrás y buscaba lenguaje de prohibición
(`nunca|never|prohibid|forbidden|no existe|not implement|ning.n`) dentro de esa ventana.

`agents/oracle-backup-recovery-analyst/manifest.yaml:91` declara:

```yaml
forbidden_capabilities:            # línea 78
  ...
  - "execute_rman(command) / run_rman(command) / rman_shell(command) — ningún wrapper de
     ejecución arbitraria de RMAN (# 15 del prompt)"   # línea 91
```

Esto producía un falso `[FAIL]` por dos causas combinadas:

1. **Ventana insuficiente para ver el contexto estructural.** La clave YAML envolvente
   `forbidden_capabilities:` está 13 líneas antes de la ocurrencia — muy fuera de la ventana de 3
   líneas. El test nunca sabía que la línea vivía dentro de un bloque de prohibición declarativo.
2. **Wildcard frágil sobre bytes multibyte.** El propio texto de la línea 91 contiene la palabra
   de prohibición "ningún", que debería haber sido suficiente incluso con la ventana estrecha. El
   patrón `ning.n` fallaba en emparejarla porque, en este entorno (Git Bash / MSYS sobre Windows),
   `.` en una expresión regular POSIX no cruza de forma fiable los 2 bytes UTF-8 de la `ú`
   (`0xC3 0xBA`) — `ning.n` sólo empareja 6 bytes consecutivos, y "ningún" codificado en UTF-8
   ocupa 7. Verificado directamente: `echo "ningún" | grep -qiE 'ning.n'` no empareja en este
   shell/locale, pese a que `LC_CTYPE=C.UTF-8`.

El problema estaba en el test, no en la arquitectura: el manifest ya declaraba correctamente la
prohibición (el primer chequeo del test, una búsqueda literal de la frase completa, ya pasaba).

## Old behavior

- Ventana fija de 3 líneas hacia atrás, sin noción de estructura YAML.
- Lenguaje de prohibición dependiente de un wildcard (`ning.n`) frágil ante multibyte.
- Un bloque `forbidden_capabilities:` largo (más de 3 líneas por entrada) podía producir falsos
  `[FAIL]` en cualquier entrada que no repitiera una palabra de prohibición en sus 3 líneas
  inmediatas — exactamente lo que ocurrió en la línea 91.

## New behavior

`check_match()` clasifica cada ocurrencia con una regla structure-aware para archivos YAML,
NO un parser YAML completo — sólo localiza la última clave YAML top-level (sin indentación) que
aparece antes de la línea de la ocurrencia (`classify_yaml_section()`, vía `awk`):

- Si esa clave es `forbidden_capabilities` / `blocked_capabilities` / `prohibited_capabilities` /
  `prohibited` → **PASS estructural**, sin depender de lenguaje natural cercano.
- Si esa clave es `allowed_tools` / `allowed_capabilities` / `collectors` / `tools` /
  `execution` / `runtime` / `actions` → **FAIL duro**, sin excepción.
- Si la clave no se reconoce, o el archivo no es `.yaml`/`.yml` (p. ej. `AGENT.md`,
  `parsers/rman/common.py`) → fallback al chequeo de ventana de lenguaje de prohibición ya
  existente, con el wildcard UTF-8 corregido (`ningún|ningun` explícitos en vez de `ning.n`).

Nada de esto reduce la detección: `execute_rman(`, `run_rman(`, `rman_shell(` se siguen buscando
en todo el dominio; la mejora es de clasificación de contexto, no de cobertura de patrones (# 14
del prompt: "better context classification, not less detection").

## Forbidden-capability handling

Fixture controlada (`# 11`/`# 12` del prompt) embebida en el propio test — sin tocar
`queries/rman/**`, `skills/rman/**` ni `parsers/rman/**`:

```yaml
forbidden_capabilities:
  - execute_rman(command)
  - run_rman(command)
  - rman_shell(command)
```

Resultado: **PASS** para los 3 nombres — documentación de prohibición, correctamente reconocida
por estructura sin depender de la palabra "ningún"/"nunca" en cada entrada.

## Allowed-capability handling

```yaml
allowed_tools:
  - execute_rman(command)
  - run_rman(command)
  - rman_shell(command)
```

Resultado: **FAIL** para los 3 nombres — capacidad real ejecutable, detectada por estructura sin
excepción.

## UTF-8 handling

Fixture no-YAML (`.md`) con la palabra de prohibición acentuada:

```text
No existe execute_rman(command) — ningún wrapper de ejecución arbitraria.
```

Resultado: **PASS** — `ningún` (con tilde) ahora se reconoce vía alternación explícita
(`ningún|ningun`), sin wildcard sobre bytes multibyte.

## Security regression

No se debilitó ninguna prohibición: `execute_rman`, `run_rman`, `rman_shell` se siguen
detectando en los 4 directorios del dominio (`agents/oracle-backup-recovery-analyst`,
`skills/rman`, `queries/rman`, `parsers/rman`); un contexto no reconocido (ni `forbidden_*` ni
`allowed_*`/`tools`/`execution`/`runtime`/`actions`) sigue exigiendo lenguaje de prohibición
cercano vía el fallback — verificado manualmente con una clave YAML sintética sin reconocer
(`some_random_new_section:`), que correctamente cae al fallback y no pasa sin lenguaje de
prohibición cercano.

## Targeted test scope

```text
TEST_SCOPE:
TARGETED

WHY_NO_FULL_REGRESSION:
Only RMAN security-test logic changed (tests/test_no_arbitrary_rman.sh). No production/runtime/
query/shared resolver code changed — scripts/lib/version.sh, el Static Validator, el Query Variant
Resolver, el harness global de tests y el escáner de seguridad global no se tocaron.
```

Tests ejecutados: `test_no_arbitrary_rman`, `test_no_restore_execution`,
`test_no_recover_execution`, `test_no_delete_execution`, `test_no_crosscheck_execution`,
`test_no_change_execution`, `test_no_configure_execution`, `test_no_catalog_execution`,
`test_no_uncatalog_execution`, `test_no_duplicate_execution`,
`test_no_channel_allocate_execution`, `test_no_arbitrary_sql`, `test_no_arbitrary_shell`,
`test_no_secrets`, más el smoke de contrato de agente
`test_backup_recovery_agent_manifest.sh` y `test_repository_text_files_are_lf.sh` — 16/16 PASS.
