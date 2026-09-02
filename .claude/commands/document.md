---
description: Generar un entregable binario (DOCX/XLSX/PDF/PPTX) a partir de un análisis existente
---

Actúa como `oracle-operations-orchestrator` y ejecuta el workflow `workflows/document.md` para:

$ARGUMENTS

Invoca `technical-documentation-manager`. Si no existe el `analysis/ANA-*`/`INC-*` de origen para el tipo de documento solicitado, rechaza la solicitud citando `NO ANALYSIS WITHOUT EVIDENCE RECORD`. Nunca reanalices evidencia — sólo transforma el Markdown existente al formato pedido (`--format docx|xlsx|pdf|pptx|all`).
