---
description: Generar un entregable binario (DOCX/XLSX/PDF/PPTX) a partir de un análisis existente
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/document.md` para:

$ARGUMENTS

Invoca `technical-documentation-manager`. Si no existe el `analysis/ANA-*`/`INC-*` de origen para el tipo de documento solicitado, rechaza la solicitud citando `NO ANALYSIS WITHOUT EVIDENCE RECORD`. Nunca reanalices evidencia — sólo transforma el Markdown existente al formato pedido (`--format docx|xlsx|pdf|pptx|all`).

Fase 12: además de los binarios, el motor local genera documentos Markdown/JSON con `python -m change_documentation_knowledge.cli document --kind rca|executive|change|assessment|post-incident` desde un único análisis ya concluido (mismo estado de causa en todas las audiencias; secciones sin fuente = `NOT_PROVIDED_BY_SOURCE`; reporte `PARTIAL` con warnings cuando falten datos).
