# Change history — oracle-dataguard-analyst

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Foundation | Manifest plano `agents/oracle-dataguard-analyst.md`, responsabilidades declaradas, sin materialización profunda de skills/queries. |
| 2.0.0 | Fase 5 (Data Guard) | Materializado en contrato estructurado (`manifest.yaml`/`routing.yaml`/`context-policy.yaml`/`collaboration.yaml`/`output-schema.yaml`), 21 skills `dataguard/*`, Broker Collector Contract (reutiliza Fase 4) con 4 collectors semánticos y parser local, modelos de readiness de switchover/failover, distinción explícita transport lag vs. apply lag, gaps thread-aware, Active Data Guard Licensing Gate. |
