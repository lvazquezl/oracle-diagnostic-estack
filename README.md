# oracle-diagnostic-estack

Enterprise e-stack de diagnóstico **read-only** para Oracle Database (10g–23ai), Grid Infrastructure/RAC, ASM, Data Guard y los sistemas operativos que los hospedan (Linux, RHEL, SUSE, Solaris, AIX, Windows Server, HP-UX).

> **READ-ONLY ALWAYS. HUMAN-EXECUTED REMEDIATION ONLY.**
> El stack observa, recolecta evidencia, analiza, correlaciona, diagnostica, documenta y **genera** comandos/procedimientos. Nunca ejecuta cambios sobre el ambiente.

## Qué hace

- Health checks, assessments y troubleshooting de bases Oracle standalone y RAC (CDB/PDB o NON-CDB), Data Guard, ASM, backup/RMAN, seguridad/compliance, red/listener y OS.
- Root cause analysis correlacionando evidencia multi-dominio.
- Capacity management y forecasting.
- Generación de recomendaciones y propuestas de cambio (`/change`) para ejecución manual del DBA — nunca automática.
- Documentación automática Markdown de cada análisis, con entregables DOCX/XLSX/PDF/PPTX bajo demanda.

## Qué NO hace

- No ejecuta SQL/DDL/DML, `srvctl`/`crsctl` de cambio, `systemctl start/stop/restart`, restore/recover, switchover/failover, ni shell arbitrario.
- No requiere ni usa SYSDBA/SYSOPER/SYSASM/root/sudo.
- No es una fábrica de software.

## Estructura

Ver [ARCHITECTURE.md](ARCHITECTURE.md) para el detalle de cada carpeta. Punto de entrada de comportamiento: [CLAUDE.md](CLAUDE.md). Cobertura actual por dominio × versión Oracle: [docs/CAPABILITY_MATRIX.md](docs/CAPABILITY_MATRIX.md).

## Convenciones

Todo skill se referencia siempre por su `skill_id` completo (`dominio/skill`, ej. `oracle/tablespaces`) — nunca por un nombre corto suelto (`tablespaces`, `temp`, `undo`...); ver [skills/REGISTRY.md](skills/REGISTRY.md). Toda capability que no se ejecuta tal como se pidió (por versión, licencia, privilegio, costo...) devuelve un estado explícito en vez de fallar en silencio — ver [docs/CONTRACTS.md#capability-status-model](docs/CONTRACTS.md#capability-status-model). Un agente profundizado por una fase vive en `agents/<id>/AGENT.md` (ej. `oracle-discovery-analyst`, `oracle-dba-analyst`); el resto permanece `agents/<id>.md`. La identidad de un ambiente Oracle se publica una vez por análisis como **Target Profile** ([docs/TARGET_PROFILE.md](docs/TARGET_PROFILE.md)) y se reutiliza — ningún especialista vuelve a determinar versión/arquitectura/rol por su cuenta.

## Empezar

1. Lee [CLAUDE.md](CLAUDE.md) (rutas, política de contexto y evidencia).
2. Lee [SECURITY.md](SECURITY.md) antes de conectar cualquier ambiente real.
3. Corre `scripts/bootstrap-check.sh` (o `.ps1` en Windows) para validar prerrequisitos de tu estación. Los tests (`tests/run-all.sh`) requieren `bash` — en Windows, Git Bash (Git for Windows) o WSL; ver [docs/PHASE_3_COMPLETION_HARDENING.md#gap-4--cross-platform--crlf-hardening](docs/PHASE_3_COMPLETION_HARDENING.md#gap-4--cross-platform--crlf-hardening).
4. Usa los comandos en `.claude/commands/` (`/diagnose`, `/healthcheck`, `/assessment`, `/analyze`, `/awr`, `/rac`, `/dataguard`, `/capacity`, `/incident`, `/rca`, `/recommend`, `/document`, `/change`).

## Estado

Fase actual: **Fase 10 — Capacity Management & Forecasting** (sobre baseline `v0.9.0-os-platform`). `capacity-analyst` (`v2.0.0`, deepening de manifest plano real de Foundation a contrato estructurado completo, mismo patrón que Security/OS Platform) y 28 skills `capacity/*` completamente implementados y probados — Common Metric Model transversal a Oracle/Linux/Windows/SQL Server/VMware, forecasting reproducible y confidence-aware (1/3/6 meses), threshold crossing, análisis horizontal/vertical siempre advisory — ver [docs/PHASE_10_CAPACITY_MANAGEMENT_FORECASTING.md](docs/PHASE_10_CAPACITY_MANAGEMENT_FORECASTING.md). Base funcional previa: [docs/PHASE_9_OS_PLATFORM_DIAGNOSTICS_HARDENING.md](docs/PHASE_9_OS_PLATFORM_DIAGNOSTICS_HARDENING.md) (`os-platform-analyst`, 45 skills `os/*`), [docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md](docs/PHASE_8_ORACLE_SECURITY_COMPLIANCE.md) (`oracle-security-analyst`, 39 skills `security/*`), [docs/PHASE_7_ORACLE_BACKUP_RECOVERY_RMAN.md](docs/PHASE_7_ORACLE_BACKUP_RECOVERY_RMAN.md) (`oracle-backup-recovery-analyst`, 30 skills `rman/*`), [docs/PHASE_6_ORACLE_MULTITENANT.md](docs/PHASE_6_ORACLE_MULTITENANT.md) (`oracle-multitenant-analyst`, 26 skills `multitenant/*`), [docs/PHASE_5_ORACLE_DATAGUARD.md](docs/PHASE_5_ORACLE_DATAGUARD.md) (`oracle-dataguard-analyst`, 21 skills `dataguard/*`), [docs/PHASE_4_RAC_GI_ASM_NETWORK.md](docs/PHASE_4_RAC_GI_ASM_NETWORK.md) (`oracle-rac-analyst`/`oracle-asm-storage-analyst`/`oracle-network-analyst`, 57 skills), [docs/PHASE_3_COMPLETION_HARDENING.md](docs/PHASE_3_COMPLETION_HARDENING.md) + [docs/PHASE_3_ORACLE_PERFORMANCE.md](docs/PHASE_3_ORACLE_PERFORMANCE.md) (`oracle-performance-analyst`, 31 skills `performance/*`), [docs/PHASE_2_ORACLE_CORE.md](docs/PHASE_2_ORACLE_CORE.md) (`oracle-discovery-analyst`/`oracle-dba-analyst`, 18 skills `oracle/*`). Ver [CHANGELOG.md](CHANGELOG.md) y "Known limitations" en el reporte de cierre de cada fase.
