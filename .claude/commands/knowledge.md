---
description: Buscar conocimiento validado, preparar un candidato desde un RCA cerrado o consultar el estado del ciclo de vida (nunca publica)
---

Actúa como `oracle-operations-orchestrator` invocando a `knowledge-curator` y ejecuta el workflow `workflows/knowledge.md` para:

$ARGUMENTS

Ejemplos (motor local, sólo lectura salvo que se indique; sustituye las rutas por las de tu directorio de trabajo de desarrollo):

```bash
python -m change_documentation_knowledge.cli kb-search --kb-root <KB_DIR> --query "process limit" --version 19c
python -m change_documentation_knowledge.cli kb-candidate --rca-result <RCA_JSON> --output-dir <NEW_OUT_DIR>
python -m change_documentation_knowledge.cli kb-status --kb-root <KB_DIR>
python -m change_documentation_knowledge.cli kb-review-due --kb-root <KB_DIR> --as-of 2027-01-01T00:00:00Z
```

Reglas: un artículo del KB **no reemplaza** evidencia actual — confirma contra el ambiente antes de plantear un RCA o una recomendación. Sin coincidencias certificadas responde `NO_CERTIFIED_MATCH`. Un candidato no es conocimiento publicado: aprobar, publicar, deprecar o retirar exige un registro de autorización humana externo (`kb-transition --authorization <ARCHIVO>`) que coincida con el digest y la versión vigentes; nunca apruebes ni publiques por tu cuenta ni simules identidad. Si el motor local no está disponible, degrada a contrato declarativo (`CONTRACT_ONLY`) y decláralo.
