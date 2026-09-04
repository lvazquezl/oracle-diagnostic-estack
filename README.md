# oracle-diagnostic-estack

Enterprise e-stack de diagnóstico **read-only** para Oracle Database (10g–23ai), Grid Infrastructure/RAC, ASM, Data Guard y los sistemas operativos que los hospedan (Linux, RHEL, SUSE, Solaris, AIX, Windows Server, HP-UX).

> **READ-ONLY ALWAYS. HUMAN-EXECUTED REMEDIATION ONLY.**
> El stack observa, recolecta evidencia, analiza, correlaciona, diagnostica, documenta y **genera** comandos/procedimientos. Nunca ejecuta cambios sobre el ambiente.

## Qué hace

- Health checks, assessments y troubleshooting de bases Oracle standalone y RAC (CDB/PDB o NON-CDB), Data Guard, ASM, backup/RMAN, red/listener y OS.
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

Fase actual: **Fase 3 — Performance Completion & Portability Hardening** (sobre baseline `v0.2.0-oracle-core` + Fase 3 Oracle Performance). Statspack ahora cubre reportes multi-sección completos, arquitectura genérica de ingesta/parseo local de reportes (`parsers/performance/`), `oracle-performance-analyst` (`v4.0.0`) materializado en contrato estructurado, y line endings normalizados/gobernados por `.gitattributes` — ver [docs/PHASE_3_COMPLETION_HARDENING.md](docs/PHASE_3_COMPLETION_HARDENING.md). Base funcional previa: [docs/PHASE_3_ORACLE_PERFORMANCE.md](docs/PHASE_3_ORACLE_PERFORMANCE.md) (`oracle-performance-analyst` y 31 skills `performance/*`), [docs/PHASE_2_ORACLE_CORE.md](docs/PHASE_2_ORACLE_CORE.md) (`oracle-discovery-analyst`/`oracle-dba-analyst`, 18 skills `oracle/*`). Ver [CHANGELOG.md](CHANGELOG.md) y "Known limitations" en el reporte de cierre de cada fase.
