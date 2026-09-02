# Data Classification & Sanitization Policy

## Flujo obligatorio

```
RAW DATA → LOCAL PARSER → FILTER → AGGREGATION → REDACTION/TOKENIZATION → SANITIZED EVIDENCE → MODELO
```

Este componente corre **localmente**, antes de que cualquier evidencia entre a un Task/Result Package. `evidence/raw` nunca se envía completo al modelo.

## Clasificación de campos

| Clase | Significado | Acción |
|---|---|---|
| `KEEP` | Dato no sensible, necesario para el diagnóstico | Se envía tal cual |
| `MASK` | Dato potencialmente identificador pero no secreto (hostname, IP, nombre de servicio/schema) | Se reemplaza por un alias estable (`host-A1`, `svc-X1`) consistente dentro del mismo análisis |
| `HASH` | Dato que debe poder compararse pero no revelarse (ej. nombre de usuario en contexto de auditoría) | Se reemplaza por hash determinístico truncado |
| `TOKENIZE` | Dato reversible sólo por el DBA (requiere mapeo local) | Se reemplaza por token; el mapeo token↔valor real queda sólo en `evidence/raw` local, nunca sale de la estación |
| `DROP` | Secreto o dato de aplicación fuera de alcance | Se elimina antes de construir el `EVD-*` sanitizado; nunca llega ni siquiera enmascarado |

## Reglas por defecto

- **Enmascarables por defecto (`MASK`)**: hostnames, IPs, service names, schema names, nombres internos de objetos que puedan revelar cliente/aplicación.
- **`DROP` siempre**: passwords, password hashes, wallets, API keys, tokens de sesión, bind values, contenido de tablas de aplicación, credenciales embebidas en archivos de configuración.
- **SQL text**: condicional. Por defecto se envía SQL_ID + plan hash + métricas (`KEEP`); el texto SQL completo requiere autorización explícita del DBA para la sesión y aun así pasa por `DROP` de literales que parezcan datos de negocio.
- **AWR/ASH/Statspack/logs**: preprocesados localmente; se envían por secciones relevantes a la pregunta activa, nunca el artefacto completo salvo decisión explícita de política para esa sesión.
- **Nombres de tablespace/servicio/PDB**: `MASK` por defecto si el DBA no autoriza lo contrario explícitamente para la sesión.

## Consistencia dentro de un análisis

Los alias de `MASK`/`TOKENIZE` son estables dentro de un mismo `ANA-*`/`INC-*` (el mismo host siempre recibe el mismo alias), para que la correlación entre agentes siga siendo posible sin exponer el valor real.

## Detección de secretos

Antes de construir cualquier `EVD-*` sanitizado, el parser local ejecuta detección de patrones de secretos (passwords en URLs de conexión, API keys, tokens, wallets) y aplica `DROP` automáticamente si hay coincidencia, sin excepción configurable por el modelo.

## Excepciones

Cualquier excepción a `MASK`/`DROP` por defecto (ej. "no enmascares hostnames en esta sesión") requiere autorización explícita del DBA en la solicitud, se registra en `metadata.yaml` del análisis, y nunca se aplica retroactivamente a evidencia ya sanitizada.

## Referencia cruzada

Ver `docs/CONTRACTS.md#evidence-model`, `policies/data-minimization-policy.md`, `tests/test_secret_detection.*`, `tests/test_hostname_masking.*`.
