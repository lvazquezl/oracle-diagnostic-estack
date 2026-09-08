"""Local filter for alert.log excerpts relevant to Data Guard (# 50 del prompt
de Fase 5). Reutiliza la captura acotada de `oracle-diag-collector` (Fase 2) —
este módulo sólo filtra/estructura, nunca lee el archivo completo.

Detecta términos MRP/RFS/LNS/archive destination/gap/transport/apply/broker
dentro de una ventana ya acotada por tiempo/líneas — no implementa
observability masiva (# 50: "No implementar observability masiva").
"""
from __future__ import annotations

import re

from .common import (
    DEFAULT_SIZE_LIMITS,
    ParsedCollectorOutput,
    ParseStatus,
    SizeLimitPolicy,
    now_iso,
    sha256_of_text,
    truncate_rows,
)

PARSER_VERSION = "1.0.0"

_RELEVANT_TERMS = re.compile(
    r"\b(MRP0?|RFS|LNS|LGWR|ARCH|DGRD|archive destination|gap|transport|"
    r"apply|broker|FAL|standby redo|switchover|failover)\b",
    re.IGNORECASE,
)


def filter_relevant_alertlog_excerpt(
    text: str,
    limits: SizeLimitPolicy = DEFAULT_SIZE_LIMITS,
) -> ParsedCollectorOutput:
    src_hash = sha256_of_text(text)
    if not text.strip():
        return ParsedCollectorOutput(
            collector_id="get_relevant_alertlog_excerpt",
            source_command="alert.log (ventana acotada)",
            parser_version=PARSER_VERSION,
            status=ParseStatus.EMPTY_OUTPUT,
            source_output_hash=src_hash,
            parse_timestamp=now_iso(),
        )

    warnings: list[str] = []
    lines = text.splitlines()
    if len(lines) > limits.max_alertlog_lines:
        warnings.append(
            f"entrada truncada a {limits.max_alertlog_lines} lineas (de {len(lines)}) antes de filtrar"
        )
        lines = lines[: limits.max_alertlog_lines]

    relevant = [line for line in lines if _RELEVANT_TERMS.search(line)]
    relevant = truncate_rows(relevant, limits.max_alertlog_lines, warnings, "relevant_lines")

    status = ParseStatus.SUCCESS if relevant else ParseStatus.PARTIAL
    return ParsedCollectorOutput(
        collector_id="get_relevant_alertlog_excerpt",
        source_command="alert.log (ventana acotada)",
        parser_version=PARSER_VERSION,
        status=status,
        sections={"relevant_lines": relevant, "total_lines_scanned": len(lines)},
        warnings=warnings,
        source_output_hash=src_hash,
        parse_timestamp=now_iso(),
    )
