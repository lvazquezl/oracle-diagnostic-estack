# Change history — oracle-rac-analyst

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Foundation | Manifest plano `agents/oracle-rac-analyst.md`, responsabilidades declaradas, sin materialización profunda de skills/queries. |
| 2.0.0 | Fase 4 (RAC/GI/ASM/Network) | Materializado en contrato estructurado (`manifest.yaml`/`routing.yaml`/`context-policy.yaml`/`collaboration.yaml`/`output-schema.yaml`), absorbe Grid Infrastructure (sin agente GI separado), 31 skills `rac/*` (19 RAC + 12 GI bajo el mismo dominio), Collector Contract para `crsctl`/`srvctl`/`olsnodes`/`ocrcheck`/voting, correlación de session imbalance/Cache Fusion/eviction certificada. |
