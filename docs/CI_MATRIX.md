# CHG-ESTACK-CI-MATRIX-001 — Suite en CI: Windows, Linux y macOS

**Tipo:** `/change security|documentation` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/ci-matrix` (desde `main` `ab6c90c`, `v0.18.0-portability`)
**Origen:** `CHG-REQ-CI-MATRIX` (propuesto en `CHG-ESTACK-PORTABILITY-001`)
**Estado:** propuesto. Pendiente: primera ejecución en GitHub Actions (§8) y HUMAN REVIEW. `PROMOTE`, commit, merge, tag y push son acciones humanas.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. La CI no toca Oracle, el lab ni credenciales.

## 1. DETECT GAP

En `CHG-ESTACK-PORTABILITY-001`, los defectos de portabilidad se acumularon durante tres versiones (0.15–0.17) porque cada cambio se validaba en un solo sistema operativo. La validación en Windows depende de una estación de trabajo (≈3 h por corrida completa), y Linux no se probaba en ningún lado.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `.github/workflows/tests.yml` (nuevo) | `tests/run-all.sh` en `ubuntu-latest`, `windows-latest` y `macos-latest`, en cada PR, en cada push a `main` y a demanda |
| `tests/test_ci_workflow_is_read_only.sh` (nuevo) | Guard de seguridad de los workflows |

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
| GitHub Actions (ubuntu / windows / macos) | pendiente (§8) |

## 8. Validación en GitHub Actions (pendiente)

La primera ejecución ocurre al hacer push de la rama y abrir la PR. Requisito para HUMAN REVIEW: los tres jobs en verde, o fallos explicados y registrados. También se registran la duración por SO y la salida del paso `toolchain`.

## 9–10. Registros relacionados

- Cierra `CHG-REQ-CI-MATRIX`.
- Alimenta `CHG-REQ-TEST-SUITE-WINDOWS-PERF` (duración medida) y `CHG-REQ-TEST-P14-WINDOWS-SUITE` (corrida completa sin intervención humana).
- Siguiente: `CHG-REQ-LAB-DICT-VERIFY`.

## 11. HUMAN REVIEW (pendiente)

## 12. Motor de gobernanza (pendiente, después de §8)
