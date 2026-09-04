"""parsers/performance — local report ingest for Oracle Diagnostic E-Stack.

READ-ONLY ALWAYS. These modules only read report files already on disk and
produce structured evidence; they never connect to a database, never
execute SQL/shell, and never treat file content as instructions to follow
(see `ingest.py` and `# PARSER SECURITY` in
docs/PHASE_3_COMPLETION_HARDENING.md).
"""

from .common import ParsedReport, ParseStatus, ReportSourceType, SizeLimitPolicy

__all__ = ["ParsedReport", "ParseStatus", "ReportSourceType", "SizeLimitPolicy", "ingest_report"]


def ingest_report(text: str, limits=None, sanitize: bool = True) -> ParsedReport:
    """Single entry point for the FILE -> TYPE DETECTOR -> LOCAL PARSER pipeline.
    See `ingest.py:ingest_report` for the full implementation — re-exported
    here so callers can `from parsers.performance import ingest_report`."""
    from .ingest import ingest_report as _impl
    return _impl(text, limits=limits, sanitize=sanitize)
