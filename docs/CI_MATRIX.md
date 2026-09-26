# CHG-ESTACK-CI-MATRIX-001 — Suite en CI: Windows, Linux y macOS

**Tipo:** `/change security|documentation` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/ci-matrix` (desde `main` `ab6c90c`, `v0.18.0-portability`)
**Origen:** `CHG-REQ-CI-MATRIX` (propuesto en `CHG-ESTACK-PORTABILITY-001`)
**Estado:** propuesto. Validado en GitHub Actions en los tres sistemas (§8, ejecución 2). Pendiente: HUMAN REVIEW. `PROMOTE`, commit, merge, tag y push son acciones humanas.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. La CI no toca Oracle, el lab ni credenciales.

## 1. DETECT GAP

En `CHG-ESTACK-PORTABILITY-001`, los defectos de portabilidad se acumularon durante tres versiones (0.15–0.17) porque cada cambio se validaba en un solo sistema operativo. La validación en Windows depende de una estación de trabajo (≈3 h por corrida completa), y Linux no se probaba en ningún lado.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `.github/workflows/tests.yml` (nuevo) | `tests/run-all.sh` en `ubuntu-latest`, `windows-latest` y `macos-latest`, en cada PR, en cada push a `main` y a demanda |
| `tests/test_ci_workflow_is_read_only.sh` (nuevo) | Guard de seguridad de los workflows |
| `tests/p15/harness.py`, `check_lab_{adapter,security}.py` | `macos_test`: 4 casos que lanzan el CLI lab real con el perfil `macos_keychain` salen `[SKIP]` explícito fuera de macOS (defecto de `v0.18.0` detectado por la primera ejecución en Linux, §8) |

## 3. GAP ANALYSIS

1. **Toolchain por SO:**
   - Python 3.13 con `actions/setup-python`. La suite usa solo la biblioteca estándar, y `python-oracledb` no se instala.
   - En Windows se asegura `python3`. La suite corre con `shell: bash` (Git Bash).
   - En macOS, `brew install bash` antepone bash ≥ 4 al PATH (`/bin/bash` es 3.2; ver `CHG-ESTACK-PORTABILITY-001`).
   - El paso `toolchain` registra `which bash`, `bash --version`, `python3 --version` y `grep --version` en cada SO.
2. **Line endings:** `.gitattributes` ya fuerza `eol=lf`, así que el checkout en Windows no introduce CRLF.
3. **Git sintético:** los repos temporales de P14 configuran su propia identidad (`tests/p14/harness.py`) y no dependen de la configuración del runner.
4. **Lab:** fuera de alcance por diseño. En Linux/macOS los casos P15 corren contra el `FakeDriver`; en Windows salen `[SKIP]` explícitos. La validación contra Oracle real sigue siendo humana, desde la Mac.
5. **Duración en Windows:** `timeout-minutes: 300` (límite de GitHub: 360). La primera ejecución mide el tiempo real y alimenta `CHG-REQ-TEST-SUITE-WINDOWS-PERF`.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries / diccionario / skills / agentes / gateway | Ninguno |
| Suite | +1 test (guard); ningún test existente cambia |
| Repositorio | Nuevo directorio `.github/workflows/`. Cada PR muestra el resultado de los tres SO |
| Costo | Minutos de GitHub Actions. En repos públicos es gratis, y Windows y macOS consumen el doble y 10× en repos privados |

## 5. TEST

- Guard: 10 mutaciones, todas detectadas:
  - permiso `write`;
  - uso de `secrets.`;
  - `pull_request_target`;
  - acción por tag en vez de SHA;
  - matriz sin Windows;
  - `fail-fast: true`;
  - `persist-credentials: true`;
  - invocar `mcp_gateway_lab`;
  - `git push`;
  - `brew install bash` solo en un comentario.
- Los comentarios del YAML no cuentan: el guard revisa solo YAML efectivo.

## 6. SECURITY VALIDATION

- `permissions: contents: read` a nivel de workflow y ningún permiso de escritura.
- No hay `secrets.*` ni `GITHUB_TOKEN` explícito, y `checkout` usa `persist-credentials: false`.
- Solo triggers no privilegiados (`pull_request`, `push` a `main`, `workflow_dispatch`); no hay `pull_request_target` ni `workflow_run`.
- Acciones de terceros fijadas por SHA completo, resuelto con `git ls-remote` el 2026-09-24:
  - `actions/checkout` v7.0.1 → `3d3c42e5…ba90b1`;
  - `actions/setup-python` v6.3.0 → `ece7cb06…78c61a1`.
- No hay acceso al lab, a Oracle, al Keychain ni a perfiles privados. Todo esto lo hace cumplir `tests/test_ci_workflow_is_read_only.sh`.
- Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

| Plataforma | Resultado |
|---|---|
| macOS local (bash 5.3.20 Homebrew) | **963/963** (962 de `v0.18.0` + guard). Primera corrida en macOS con el validador SQL realmente activo: 962/962 antes del cambio |
| GitHub Actions (ubuntu / windows / macos) | **963/963** en los tres (§8, ejecución 2) |

## 8. Validación en GitHub Actions

Requisito para HUMAN REVIEW: los tres jobs en verde, o fallos explicados y registrados. También se registran la duración por SO y la salida del paso `toolchain`.

**Ejecución 1** (PR #12, run `36082396894`, commit `f00f0f5`, 2026-09-25):

| Job | Toolchain | Resultado | Duración |
|---|---|---|---|
| ubuntu-latest | bash 5.2.21, Python 3.13.15, GNU grep 3.11 | **FAIL 961/963**: `test_p15_oracle_lab_{adapter,security}` | 3 min |
| macos-latest | bash 5.3.15 (Homebrew), **Python 3.14.7**, BSD grep 2.6.0 | 963/963 | 5 min |
| windows-latest | bash 5.3.15 (Git Bash), Python 3.13.15 | **FAIL 960/963**: `test_p14_{evidence_packager,operability,release_gate}` | 41 min |

Tres defectos encontrados, y una observación:

1. **Linux (defecto de `v0.18.0`, `CHG-ESTACK-PORTABILITY-001`):** el rechazo de `macos_keychain` fuera de darwin también se dispara en Linux. Cuatro casos P15 lanzan el CLI lab real como subproceso sin runner inyectado (`validate_config_…`, `serve_subcommand_…`, `startup_refusals_…`, `missing_driver_…`) y recibían ese rechazo. El comportamiento del lanzador es el correcto (el lab es solo macOS); los casos pasan a `macos_test` (`[SKIP]` explícito fuera de macOS). El rechazo sigue cubierto en toda plataforma por `the_keychain_provider_is_refused_at_startup_off_macos_…`. Linux nunca se había probado.
2. **macOS (defecto del workflow):** anteponer todo `$(brew --prefix)/bin` a `GITHUB_PATH` tapaba el `python3` de `setup-python` con el de Homebrew (3.14). Ahora solo se expone un symlink a `bash`, y `toolchain` exige Python 3.13. El guard detecta ambas regresiones (2 mutaciones nuevas).

3. **Windows (defecto de `release_readiness`, anterior a este cambio):** `runner.run_to_file` y `runner.version_line` lanzaban `["bash", …]` con `subprocess`. En Windows, `CreateProcess` busca en `System32` **antes** que en el PATH, y los runners de GitHub traen `System32\bash.exe` (el lanzador de WSL, sin distro): no ejecuta nada, y el log de evidencia salía vacío (`LOG_EMPTY`/`LOG_TRUNCATED`). De ahí salen los fallos de `evidence_packager` y `release_gate`. En la estación del usuario pasa, probablemente porque no tiene ese `bash.exe`. Ahora `bash`/`git` se resuelven por PATH (`shutil.which`), el mismo orden que usa Git Bash; si no se resuelven, se usa el nombre sin cambios y falla igual que antes. El manifiesto sigue registrando `["bash", "tests/run-all.sh"]`.
4. **Observación, `test_p14_operability`:** el caso `malformed_adapter_payloads_…` falló en Windows con un `AssertionError` sin mensaje; el log no permite diagnosticarlo y no se adivina la causa. Sus asserts ahora reportan código de error, número de llamadas y si hubo fuga (booleanos, nunca el marcador). La ejecución 2 lo mostrará.

Duración: Windows **41 min** en la CI, contra ~3 h en la estación del usuario. Alimenta `CHG-REQ-TEST-SUITE-WINDOWS-PERF`: la lentitud es de esa estación (antivirus u otro factor local), no de la suite.

Local tras las correcciones (macOS, bash 5.3.20): 963/963. Simulación Linux de P15: 4 `[SKIP]` y el resto en verde.

**Ejecución 2** (run `36088771415`, commit `1ba3722`, 2026-09-25):

| Job | Toolchain | Resultado | `[SKIP]` | Duración |
|---|---|---|---|---|
| ubuntu-latest | bash 5.2.21, Python 3.13.15, GNU grep 3.11 | **963/963** | 4 (`macos_test`) | 3 min |
| macos-latest | bash 5.3.15 (solo el symlink `bash4`), **Python 3.13.15**, BSD grep 2.6.0 | **963/963** | 0 | 5 min |
| windows-latest | bash 5.3.15 (Git Bash), Python 3.13.15, GNU grep 3.0 | **963/963** | 51 (23 + 28 `posix_test`) | 33 min |

`test_p14_operability` pasó en Windows con los asserts diagnósticos nuevos. El fallo de la ejecución 1 **no se reprodujo** y su causa queda sin determinar: si reaparece, el mensaje dirá código, llamadas y fuga.

## 9–10. Registros relacionados

- Cierra `CHG-REQ-CI-MATRIX`.
- Alimenta `CHG-REQ-TEST-SUITE-WINDOWS-PERF` (duración medida) y `CHG-REQ-TEST-P14-WINDOWS-SUITE` (corrida completa sin intervención humana).
- Siguiente: `CHG-REQ-LAB-DICT-VERIFY`.

## 11. HUMAN REVIEW — aprobado

`AUTH-CI-MATRIX-001`, revisor `REV-DBAMANAGER` (distinto del proponente `REV-CLAUDEAGENT`), `2026-09-26T04:46:29Z`, contra el digest `5c1282f8…79dc9ef`. El motor informa `review_status: APPROVED_BY_HUMAN` con verificación `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`: comprueba la estructura y el digest, no la identidad del firmante. `PROMOTE` (merge, tag) sigue siendo acción humana.

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-25T03:37:33Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 5c1282f87fd7508284a83f52acb7abae9cd6fb428ab0534ced632e36d79dc9ef`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-CI-MATRIX-001/`.
