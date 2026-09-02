# Evidence Retention Policy

## Separación

- `evidence/raw/` — nunca versionado en Git, nunca modificado tras su captura. Retención local por defecto: 30 días (configurable en `config/estack.config.example.yaml`).
- `evidence/sanitized/` — derivado de `raw`, es lo que efectivamente cruza hacia el modelo. Retención ligada al `ANA-*`/`INC-*` que la referencia; no se purga mientras el análisis esté activo.
- `evidence/derived/` — agregaciones/resúmenes producidos por skills a partir de `sanitized`. Misma retención que `sanitized`.

## Reglas

- `evidence/raw` no se modifica jamás — cualquier corrección pasa por generar una nueva captura, nunca editar la existente.
- El modelo trabaja preferentemente con `sanitized`/`derived`; el acceso a `raw` es exclusivamente local (Sanitizer, auditoría) y nunca se envía completo al modelo.
- Cada `EVD-*` registra `retention metadata` (ver `docs/CONTRACTS.md#evidence-model`): cuándo puede purgarse y por qué política.
- Evidencia productiva nunca se distribuye (ver `DISTRIBUTION.md`) ni se sube al repositorio Git corporativo.

## Purga

- `raw` se purga automáticamente tras su ventana de retención salvo que esté referenciada por un `ANA-*`/`INC-*` sin cerrar.
- `sanitized`/`derived` se purgan junto con el `analysis/ANA-*` correspondiente según la política de retención de análisis del sitio (fuera del alcance de este e-stack — el DBA/equipo define esa política operativa).

## Referencia

`docs/CONTRACTS.md#evidence-model`, `sanitizers/data-classification-policy.md`, `DISTRIBUTION.md#separación-de-contenido`.
