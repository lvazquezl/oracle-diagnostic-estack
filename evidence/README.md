# Evidence

Ver [`policies/evidence-retention-policy.md`](../policies/evidence-retention-policy.md) y [`docs/CONTRACTS.md#evidence-model`](../docs/CONTRACTS.md#evidence-model).

- `raw/` — captura directa de collectors. Nunca se modifica. Nunca se distribuye ni se sube al repo Git corporativo (ver `.gitignore` en este directorio y `DISTRIBUTION.md`).
- `sanitized/` — salida del Sanitizer (`sanitizers/data-classification-policy.md`). Es lo que efectivamente puede llegar al modelo.
- `derived/` — agregaciones/resúmenes producidos por skills a partir de `sanitized/`.

Todo archivo bajo estos tres directorios corresponde a un `EVD-*` con su metadata (`evidence_id, analysis_id, timestamp, target, collector, source, classification, sensitivity, hash, retention`) registrada en `analysis/ANA-*/evidence-manifest.json`.
