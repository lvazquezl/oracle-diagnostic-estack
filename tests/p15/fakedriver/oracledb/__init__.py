"""
FAKE python-oracledb used ONLY by tests/p15 subprocess checks (put first on PYTHONPATH by the harness).
It never opens a socket: connect() always fails with a DPY-6005-shaped error.
"""


class _Err:
    full_code = "DPY-6005"
    message = "fake driver: no network in tests"


class DatabaseError(Exception):
    pass


FAKE = True


def is_thin_mode():
    return True


def connect(**_kwargs):
    raise DatabaseError(_Err())
