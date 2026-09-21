# Release and Rollback — pruebas, evidencias, revisión y reversa manual

Proceso para publicar una versión del E-Stack **como marco fixture-only** y para revertirla. Todas las acciones de publicación (commit, merge, push, tag) las ejecuta una **persona**; las herramientas de este repositorio nunca las ejecutan. Contexto: [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md), [`GOVERNANCE_AND_EVOLUTION.md`](GOVERNANCE_AND_EVOLUTION.md), [`OPERATIONS_RUNBOOK.md`](OPERATIONS_RUNBOOK.md).

## Pruebas y evidencias

1. **Pruebas focalizadas durante el desarrollo:** cada suite es un script independiente, por ejemplo `bash tests/test_p14_release_gate.sh`; registre duración y código de salida.
2. **Regresión completa con evidencia íntegra.** El runner de pruebas no captura por sí mismo identidad de árbol, código de salida por archivo ni marcas de tiempo; `release_readiness` lo envuelve y lo hace verificable. La regresión completa tarda del orden de 2,5 h. Lance la corrida en segundo plano y **no modifique ningún archivo del repositorio mientras corre**:

```bash
python -m release_readiness run --out <EVIDENCE_DIR_OUTSIDE_REPO> --timeout-seconds 21600
```

   El comando toma el fingerprint SHA-256 de los archivos **antes y después**, ejecuta `bash tests/run-all.sh`, cuenta scripts **únicos** (nunca las líneas `[PASS]` internas), ejecuta `git diff --check`, redacta rutas personales y escribe el paquete fuera del repositorio (`manifest.json`, `manifest.md`, `full-regression.log`, `full-regression.exitcode`, fingerprints, `SHA256SUMS.txt`). El log crudo queda en `<EVIDENCE_DIR_OUTSIDE_REPO>.private` y nunca en el paquete.
3. **Veredictos, todos fail closed:**

| Situación | Veredicto |
|---|---|
| tiempo agotado, sin código de salida, log truncado, resumen que no cuadra, líneas duplicadas o huérfanas | `INCONCLUSIVE` |
| el árbol cambió durante la corrida (fingerprint inicial ≠ final) | `INCONCLUSIVE` + identidad `CHANGED_DURING_RUN` |
| un script falló, código de salida ≠ 0, scripts omitidos, líneas `[SKIP]`, `git diff --check` con problemas, script de seguridad fallido | `FAIL` |
| log con rutas personales o contenido tipo secreto | el log se **retiene** y el veredicto no es `PASS` |
| corrida completa, coherente, código 0, sin fallos ni omisiones, seguridad en `PASS`, árbol idéntico | `PASS` |

4. **Verificación independiente del paquete** (re-deriva conteos, veredicto y hashes en lugar de confiar en el manifiesto):

```bash
python -m release_readiness verify --package <EVIDENCE_DIR_OUTSIDE_REPO> --root .
```

   Código de salida 0 = `PASS`, 1 = `FAIL`, 2 = `INCONCLUSIVE`. Sin `--root` la identidad del árbol queda `UNVERIFIED`. Si el árbol cambió después de la corrida, la evidencia **no** aplica a este árbol y se debe repetir; nunca se reutiliza evidencia de un árbol distinto.
5. **Gate de release** (ejecuta código real: gateway por stdio, escaneo AST, evaluación de capacidades, registro, gobierno, documentación, `git diff --check`):

```bash
python -m release_readiness gate --evidence <EVIDENCE_DIR_OUTSIDE_REPO> --require-clean --format markdown --out <GATE_REPORT_DIR_OUTSIDE_REPO>
```

   Sale con 0 sólo si el veredicto es `PASS` **y** la identidad del árbol es `VERIFIED`. Los informes JSON y Markdown se sanean (sin rutas personales ni secretos).

Limitación declarada: los hashes dan **integridad, no autenticidad**; quien pueda reescribir de forma consistente el log, el manifiesto y `SHA256SUMS.txt` no queda detenido por la herramienta, por lo que la revisión humana del log y del manifiesto sigue siendo obligatoria (RSK-006).

## Revisión y publicación

Checklist humano previo a cualquier publicación (todo lo siguiente lo realiza y decide una persona autorizada):

- [ ] Leí `manifest.md` y el log redactado; cuadran los conteos (scripts únicos = scripts en disco) y no hay `[SKIP]` ni advertencias inesperadas.
- [ ] El gate de release está en `PASS` con identidad `VERIFIED`, y `READY_FOR_REAL_ENVIRONMENT_PILOT` sigue en `NO` mientras no existan adaptadores reales certificados.
- [ ] Revisé el diff: nuevos archivos, dependencias (ninguna nueva), cambios de superficie MCP y de privilegios.
- [ ] Revisé el registro de gobierno y de riesgos; ninguna excepción vencida ni revalidación atrasada.
- [ ] El alcance publicado está etiquetado como **fixture-only** (README/CHANGELOG).
- [ ] La aprobación quedó registrada en Git por una persona identificada (la herramienta sólo la valida estructuralmente).

Publicación (manual, fuera de las herramientas del E-Stack): commit → revisión → integración a la rama principal → etiqueta con nombre semántico. Ningún paso lo automatiza el repositorio y nada se despliega automáticamente.

## Reversa manual

La reversa afecta **sólo al repositorio y al gateway local**; nunca a Oracle ni a sistemas administrados.

| Qué se revierte | Cómo (persona autorizada) |
|---|---|
| Cambio aún no integrado | descartar la rama de trabajo o dejar de usarla |
| Integración en la rama principal | crear un cambio que revierta el merge (`git revert -m 1` sobre el commit de merge) y pasar por revisión, gate y publicación como cualquier otro cambio |
| Etiqueta publicada por error | decisión humana: eliminarla localmente y en el remoto sólo si nadie la ha consumido; lo habitual es publicar una etiqueta nueva |
| Gateway en uso | retirar la entrada MCP de Claude Code y detener el proceso; volver al commit o etiqueta anterior aprobado ([`OPERATIONS_RUNBOOK.md`](OPERATIONS_RUNBOOK.md#desinstalación)) |
| Esquemas de evidencias | los esquemas son versionados (`schema_version`); los datos originales nunca se mutan y los nuevos formatos se añaden sin reescribir los existentes; el verificador rechaza esquemas que no reconoce |

Después de revertir, repita las pruebas y el gate sobre el árbol resultante: la evidencia del árbol anterior **no** vale para el nuevo.
