# Tests — change-advisor

Todos los tests viven en `tests/` (convención del proyecto). Este directorio existe por consistencia estructural con el Agent Contract.

- `tests/test_p12_change_advisory.sh`
- `tests/test_p12_cross_domain.sh`
- `tests/test_p12_phase11_integration.sh`
- `tests/test_p12_security_threat_model.sh`
- `tests/test_change_proposal_completeness.sh (Foundation)`

Los tests `test_p12_*.sh` son **funcionales**: ejecutan el CLI/API real de `change_documentation_knowledge` sobre fixtures sintéticos y afirman sobre el JSON/Markdown/KB producido.
