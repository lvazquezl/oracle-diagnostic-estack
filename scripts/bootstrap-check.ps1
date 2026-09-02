# Bootstrap check (Windows) — valida prerrequisitos mínimos de la estación de trabajo del DBA.
# Ver DISTRIBUTION.md#bootstrap-validación-de-estación-de-trabajo.
# No modifica nada; sólo reporta. Exit code != 0 si algún check obligatorio falla.

$ErrorActionPreference = "SilentlyContinue"
$Root = Split-Path -Parent $PSScriptRoot
$Fail = $false

function Check($desc, [bool]$cond, [string]$required) {
  if ($cond) {
    Write-Host "[OK]   $desc"
  } elseif ($required -eq "required") {
    Write-Host "[FAIL] $desc"
    $script:Fail = $true
  } else {
    Write-Host "[WARN] $desc"
  }
}

Write-Host "== oracle-diagnostic-estack bootstrap check =="
Write-Host "Repo root: $Root"
Write-Host ""

$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
Check "Claude Code CLI disponible en PATH" ($null -ne $claudeCmd) "required"
Check "CLAUDE.md presente" (Test-Path "$Root\CLAUDE.md") "required"
Check "SECURITY.md presente" (Test-Path "$Root\SECURITY.md") "required"
Check "policies\forbidden-operations.md presente" (Test-Path "$Root\policies\forbidden-operations.md") "required"
Check "policies\identity-model.md presente" (Test-Path "$Root\policies\identity-model.md") "required"
Check "sanitizers\data-classification-policy.md presente" (Test-Path "$Root\sanitizers\data-classification-policy.md") "required"
Check "mcp\tool-manifest.md presente" (Test-Path "$Root\mcp\tool-manifest.md") "required"
Check "agents\REGISTRY.md presente" (Test-Path "$Root\agents\REGISTRY.md") "required"
Check "skills\REGISTRY.md presente" (Test-Path "$Root\skills\REGISTRY.md") "required"
Check "queries\REGISTRY.md presente" (Test-Path "$Root\queries\REGISTRY.md") "required"

$cmdCount = 0
if (Test-Path "$Root\.claude\commands") {
  $cmdCount = (Get-ChildItem "$Root\.claude\commands" -Filter *.md).Count
}
Check ".claude\commands presente con comandos" ($cmdCount -ge 13) "required"

Write-Host ""
$localConfig = Test-Path "$Root\config\estack.config.local.yaml"
$localTargets = Test-Path "$Root\config\allowed-targets.local.yaml"
Check "config\estack.config.local.yaml existe (config local del DBA)" $localConfig "optional"
Check "config\allowed-targets.local.yaml existe (lista blanca de targets)" $localTargets "optional"
if (-not $localConfig) { Write-Host "       -> copiar config\estack.config.example.yaml a config\estack.config.local.yaml y ajustar" }
if (-not $localTargets) { Write-Host "       -> copiar config\allowed-targets.example.yaml a config\allowed-targets.local.yaml y definir targets permitidos" }

Write-Host ""
Check "evidence\, analysis\, reports\ presentes" ((Test-Path "$Root\evidence") -and (Test-Path "$Root\analysis") -and (Test-Path "$Root\reports")) "required"

Write-Host ""
if ($env:ORACLE_HOME) {
  Write-Host "[OK]   Oracle Client detectado (ORACLE_HOME definido)"
} else {
  Write-Host "[WARN] Oracle Client no detectado (ORACLE_HOME no definido) — requerido para collectors reales (Fase 2+); no bloquea Fase 1"
}

Write-Host ""
Write-Host "== Resultado =="
if (-not $Fail) {
  Write-Host "Bootstrap OK. El repositorio de Fase 1 está completo. Configura los archivos *.local.* antes de operar sobre un ambiente real."
  exit 0
} else {
  Write-Host "Bootstrap FALLÓ uno o más checks obligatorios. Revisa los [FAIL] arriba."
  exit 1
}
