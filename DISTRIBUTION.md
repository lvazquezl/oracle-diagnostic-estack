# DISTRIBUTION.md

Estado en Fase 1: **diseño de distribución**. El empaquetado, firma y releases reales son Fase 10 (Hardening & Distribution). Este documento fija las reglas desde el inicio para que ningún artefacto de fases tempranas las viole.

## Separación de contenido

| Capa | Contenido | ¿Va al repo Git corporativo? |
|---|---|---|
| Código/config base distribuible | `agents/`, `skills/`, `commands/`, `.claude/commands/`, `workflows/`, `queries/`, `collectors/`, `mcp/`, `sanitizers/`, `policies/`, `playbooks/`, `knowledge/`, `templates/`, `docs/`, `tests/`, `scripts/`, `config/*.example.*` | Sí |
| Configuración local por DBA | `config/*.local.*` (targets permitidos del DBA, credenciales de conexión no-secretas, preferencias) | No — `.gitignore` |
| Secretos locales | Wallets, passwords, API keys, tokens | No, nunca en el repo. Gestionados por el credential provider local del DBA (fuera del alcance del e-stack) |
| Evidencia local | `evidence/raw`, `evidence/sanitized`, `evidence/derived` de ambientes reales | No — `.gitignore` |
| Análisis y reportes reales | `analysis/ANA-*` y `reports/*` generados contra ambientes productivos | No — `.gitignore` (la plantilla `analysis/_TEMPLATE` sí se versiona) |

El paquete distribuible **nunca** contiene: passwords, wallets reales, tnsnames corporativos, API keys, evidencia productiva, análisis/reportes reales, ni ningún otro secreto.

## Bootstrap (validación de estación de trabajo)

`scripts/bootstrap-check.sh` / `scripts/bootstrap-check.ps1` validan antes de cualquier uso real:

- Claude Code instalado y versión mínima soportada.
- Versión del e-stack (`CHANGELOG.md` / tag) y su vigencia.
- Políticas presentes y sin modificar respecto al hash publicado (`policies/`).
- Configuración de MCP local presente (`mcp/`) y apuntando sólo a collectors certificados.
- Cliente Oracle disponible localmente (para collectors que lo requieran).
- Wallet/credential provider configurado localmente (nunca en el repo).
- Identidad read-only (`ESTACK_DIAG_*`) configurada y validada como no-privilegiada.
- Sanitizer local operativo (`sanitizers/`).
- Lista de targets permitidos definida (`config/allowed-targets.local.yaml`, no versionado).
- Workspace de evidencia/analysis/reports inicializado y con permisos correctos.
- Logging/auditoría local habilitado.

## Releases (Fase 10)

- Versionado semántico del e-stack completo (independiente del versionado por artefacto de `EVOLUTION.md`).
- Releases firmadas y con changelog obligatorio.
- Rollback: cada release conserva la anterior disponible; el bootstrap permite fijar (`pin`) una versión.
- Runbook de actualización/rollback para el equipo DBA se documenta en `docs/` al llegar a Fase 10.

## Multi-model / provider awareness

El diseño de agentes/skills evita acoplarse a features exclusivos de un proveedor de modelo cuando sea razonable (contratos basados en texto/JSON estructurado, no en tool-calling propietario no portable), para permitir adaptación futura sin reescribir el catálogo completo. Esto es un objetivo de diseño (criterio de aceptación, sección 25 del prompt maestro), no una garantía de portabilidad total en Fase 1.
