# Knowledge — Error Taxonomy

No hay un agente ni un skill por código de error individual (`ORA-*`, `TNS-*`, `RMAN-*`, `CRS-*`/`PRV*`/`PRK*`). El conocimiento validado vive aquí, curado por `knowledge-curator` a partir de `ANA-*`/`INC-*` cerrados con `CONFIRMED_ROOT_CAUSE`, y promovido vía `/change knowledge` con HUMAN REVIEW obligatoria.

## Estructura

```
knowledge/errors/
  ora/     patrones de errores ORA-*
  tns/     patrones de errores TNS-*
  rman/    patrones de errores RMAN-* / backup-recovery
  crs/     patrones de errores CRS-*/PRV*/PRK* (Grid Infrastructure)
```

## Formato de una entrada

```yaml
id: KC-<dominio>-<código o slug>-NNN
taxonomy: ora|tns|rman|crs
code: string|null           # ej. "ORA-01654", null si es un patrón sin código único
symptom: string
confirmed_root_cause: string
resolution_summary: string   # resumen del procedimiento, no el CHG-* completo
source_analysis_ids: [ANA-...|INC-...]
applies_to:
  versions: []
  platforms: []
  architectures: []
status: candidate|active|deprecated
```

Ninguna entrada incluye hostnames/IPs/nombres internos reales ni datos sensibles — el patrón se generaliza (ver `agents/knowledge-curator/AGENT.md`).

## Estado en Fase 1

Se materializan 2 entradas representativas (una por dominio con mayor probabilidad de reutilización temprana): [`ora/ORA-01653-tablespace-full.md`](ora/ORA-01653-tablespace-full.md) y [`tns/TNS-12514-service-not-registered.md`](tns/TNS-12514-service-not-registered.md). El resto de la taxonomía se puebla orgánicamente vía `knowledge-curator` a medida que se cierran análisis reales en Fases 2+.

## Fase 12 — ciclo de vida y catálogo local

`knowledge-curator` (v2.0.0) prepara **candidatos** con el motor `change_documentation_knowledge/` (`kb-candidate`): sólo un RCA `CONFIRMED` produce un candidato revisable (los demás generan un candidato `REJECTED` con `RCA_NOT_CONFIRMED`), y un candidato NO es conocimiento publicado. El catálogo local del motor (artículos inmutables + manifest) vive en un directorio de trabajo de desarrollo indicado por `--kb-root`; **este repositorio no publica ningún artículo del motor** — las entradas de `knowledge/errors/` siguen promoviéndose sólo vía `/change knowledge` con HUMAN REVIEW. Aprobar/publicar/deprecar/retirar exige un registro de autorización humano externo; el motor no puede verificar la identidad de quien lo escribió.
