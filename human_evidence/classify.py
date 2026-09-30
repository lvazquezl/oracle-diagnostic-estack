"""Column classification for tabular evidence (human-reported now; the collector factory reuses it).

Order: explicit per-query override → name rules (DROP, then MASK) → value shape. Conservative by design: a string
column that is neither an identity name nor enum-like is TOKENIZEd (reversible only locally), long text is DROPped,
and any value that looks like a secret or a connect string is dropped whatever the column policy is.
"""
import re

from rca_engine import sanitize as _san

POLICIES = ("KEEP", "MASK", "HASH", "TOKENIZE", "DROP")
_DROP_NAME = re.compile(r"(passw|passwd|pwd|secret|token|wallet|credential|(^|_)key$|private|bind|sql_text|sql_fulltext|"
                        r"^text$|_text$|^source$|^data$|^payload$|^message$|spare\d|verifier)", re.I)
_MASK_NAME = re.compile(r"(owner|schema|user|grantee|grantor|proxy|client|host|machine|terminal|program|module|osuser|"
                        r"instance_name|db_name|db_unique_name|dbname|service|pdb_name|con_name|tablespace|file_name|"
                        r"filename|path|directory|dest|device_name|diskgroup|object_name|segment_name|table_name|"
                        r"index_name|job_name|profile|role$|^name$|asm_instance|cluster_name|network_name|ip_address|"
                        r"address|email|mail)", re.I)
_KEEP_NAME = re.compile(r"(status|state|type|mode|class|event|stat_name|statistic|metric|parameter|name_space|"
                        r"^name$)", re.I)
_NUM = re.compile(r"^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$")
_ENUM = re.compile(r"^[A-Za-z0-9_ .:()#$%+/-]{1,64}$")
_CONNECT = re.compile(r"\S+/\S+@\S+")                         # user/password@db
_PATHLIKE = re.compile(r"(^[/\\+]\S*[/\\]|^[A-Za-z]:\\|\\\\)")
_IPLIKE = re.compile(r"\b\d{1,3}(\.\d{1,3}){3}\b")
_HOSTLIKE = re.compile(r"^(?=[^.]*[A-Za-z])[A-Za-z0-9-]+(\.[A-Za-z0-9-]+){2,}$")   # 19.0.0 is a version, not a host
_EMAIL = re.compile(r"[^@\s]+@[^@\s]+\.[A-Za-z]{2,}")
# A readable Oracle identifier (parameter, statistic, event, view or column name): lowercase or uppercase snake_case,
# optional leading underscores (hidden parameters), letter-led segments of at most 20 chars and few digits. Random
# tokens are mixed-case/digit-heavy, so they still trip the bare-token heuristic.
_IDENT_WORD = re.compile(r"^_{0,2}([a-z][a-z0-9]{0,19}(_[a-z0-9]{1,20})+|[A-Z][A-Z0-9]{0,19}(_[A-Z0-9]{1,20})+)$")
MAX_TEXT = 128


def is_number(v):
    return isinstance(v, str) and bool(_NUM.match(v.strip()))


def _is_identifier_word(w: str) -> bool:
    return bool(_IDENT_WORD.match(w)) and sum(c.isdigit() for c in w) * 4 <= len(w)


def value_is_sensitive(v: str) -> bool:
    """A value that must never leave as-is, whatever the column policy says: structured secrets (key=value, Bearer,
    AKIA, PEM, long hex), URL/`user/pass@db` credentials, e-mails, and bare token-shaped words that are not readable
    Oracle identifiers (so `remote_login_passwordfile` survives, `Xk9...` does not)."""
    if not v:
        return False
    if any(p.search(v) for p in _san._STRUCTURED_PATTERNS) or _san._CONNECTION_STRING_CREDENTIALS.search(v):
        return True
    if _CONNECT.search(v) or _EMAIL.search(v):
        return True
    return any(_bare_secret(w) for w in _san._BARE_TOKEN_WORD.findall(v))


def _bare_secret(w: str) -> bool:
    if w[:1] in "/+" and "/" in w[1:]:          # an absolute path or ASM path: judge each component, not the whole
        return any(_bare_secret(x) for x in w.split("/") if x)
    return _san._looks_like_bare_secret(w) and not _is_identifier_word(w)


def value_is_identifying(v: str) -> bool:
    """Paths, IPs and FQDN-like hosts are masked even inside a KEEP column."""
    return bool(_PATHLIKE.search(v) or _IPLIKE.search(v) or _HOSTLIKE.match(v))


def classify_column(name: str, values: list, override: str = None) -> tuple:
    """(policy, reason) for one column. `values` are raw strings or None."""
    if override and override not in POLICIES:
        raise ValueError("invalid override policy")
    if _DROP_NAME.search(name):                  # no override can bring a sensitive-named column back
        return "DROP", "name:sensitive"
    if override:
        return override, "override"
    present = [v for v in values if v not in (None, "")]
    if present and all(is_number(v) for v in present):
        return "KEEP", "numeric"
    if _MASK_NAME.search(name) and not (name.lower() == "name" and present and all(_ENUM.match(v) and v == v.lower() for v in present)):
        return "MASK", "name:identity"
    if any(len(v) > MAX_TEXT for v in present):
        return "DROP", "long_text"
    if _KEEP_NAME.search(name) or all(_ENUM.match(v) for v in present):
        return "KEEP", "enum_like"
    return "TOKENIZE", "unclassified_text"
